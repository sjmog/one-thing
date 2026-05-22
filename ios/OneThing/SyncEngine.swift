import Foundation

enum SyncStatus: Equatable {
    case off
    case ok
    case syncing
    case error(String)

    var label: String {
        switch self {
        case .off: "Off"
        case .ok: "Connected"
        case .syncing: "Syncing"
        case .error: "Error"
        }
    }
}

protocol HTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPSession {}

@MainActor
final class SyncEngine: ObservableObject {
    private struct PushRequest: Codable {
        var passphrase: String
        var deviceId: String
        var ops: [SyncOp]
    }

    private struct PushResponse: Codable {
        struct Accepted: Codable {
            var opId: String
            var serverSeq: Int64
        }

        struct Rejected: Codable {
            var opId: String
            var current: SyncRecord?
        }

        var accepted: [Accepted]
        var rejected: [Rejected]
    }

    private struct PullRequest: Codable {
        var passphrase: String
        var deviceId: String
        var sinceSeq: Int64
    }

    private struct PullResponse: Codable {
        var records: [SyncRecord]
        var serverSeq: Int64
    }

    private let apiURL: URL
    private let persistence: LocalPersistence
    private let secrets: SecretStore
    private let session: HTTPSession
    private var clock: HLC
    private var outbox: [SyncOp]
    private var recordHLCs: [String: HLC]
    private var pullTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var isApplyingRemote = false
    private var isSyncing = false

    var onRemoteChange: (() -> Void)?

    @Published private(set) var status: SyncStatus

    init(
        apiURL: URL = URL(string: "https://one-thing-sync.s-morgan-896.workers.dev")!,
        persistence: LocalPersistence = LocalPersistence(),
        secrets: SecretStore = KeychainStore(),
        session: HTTPSession = URLSession.shared
    ) {
        self.apiURL = apiURL
        self.persistence = persistence
        self.secrets = secrets
        self.session = session
        self.clock = persistence.loadClock()
        self.outbox = persistence.loadOutbox()
        self.recordHLCs = persistence.loadRecordHLCs()
        self.status = persistence.syncEnabled && secrets.readPassphrase() != nil ? .ok : .off
    }

    var isEnabled: Bool {
        persistence.syncEnabled && secrets.readPassphrase() != nil
    }

    var lastSync: Date? {
        persistence.lastSync
    }

    func start() {
        guard isEnabled, pullTask == nil else { return }

        pullTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.syncNow()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }

    func stop() {
        pullTask?.cancel()
        pullTask = nil
    }

    func connect(passphrase: String) async throws {
        let trimmed = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { throw SyncConnectError.shortPassphrase }

        try secrets.savePassphrase(trimmed)
        persistence.syncEnabled = true
        if !persistence.syncedOnce {
            seedOutboxFromLocal()
        }
        start()
        await syncNow()
    }

    func disconnect() {
        stop()
        debounceTask?.cancel()
        debounceTask = nil
        secrets.deletePassphrase()
        persistence.resetSyncMetadata()
        outbox = []
        recordHLCs = [:]
        status = .off
    }

    func recordTodosChanged(old: [TodoItem], new: [TodoItem]) {
        guard shouldRecordLocalChange else { return }

        let oldById = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        let newById = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })

        for item in new where oldById[item.id] != item {
            enqueue(recordType: "todo", recordId: item.id, fields: item, deleted: false)
        }

        for id in oldById.keys where newById[id] == nil {
            enqueue(recordType: "todo", recordId: id, fields: JSONValue.object([:]), deleted: true)
        }

        queueSync()
    }

    func recordPlan(_ plan: DailyPlan, for date: Date) {
        guard shouldRecordLocalChange else { return }
        enqueue(recordType: "plan", recordId: DateKeys.dayString(date), fields: plan, deleted: false)
        queueSync()
    }

    func recordWeek(_ week: WeekGoal, for date: Date) {
        guard shouldRecordLocalChange else { return }
        enqueue(recordType: "week", recordId: DateKeys.weekStartString(date), fields: week, deleted: false)
        queueSync()
    }

    func syncNow() async {
        guard isEnabled, !isSyncing, let passphrase = secrets.readPassphrase() else { return }

        isSyncing = true
        status = .syncing

        do {
            try await push(passphrase: passphrase)
            let changed = try await pull(passphrase: passphrase)
            persistence.lastSync = Date()
            persistence.syncedOnce = true
            status = .ok
            if changed {
                onRemoteChange?()
            }
        } catch {
            status = .error(error.localizedDescription)
        }

        isSyncing = false
    }

    private var shouldRecordLocalChange: Bool {
        !isApplyingRemote && isEnabled
    }

    private func queueSync() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            await self?.syncNow()
        }
    }

    private func enqueue<T: Encodable>(recordType: String, recordId: String, fields: T, deleted: Bool) {
        guard let value = try? JSONValue.from(fields) else { return }
        enqueue(recordType: recordType, recordId: recordId, fields: value, deleted: deleted)
    }

    private func enqueue(recordType: String, recordId: String, fields: JSONValue, deleted: Bool) {
        let op = SyncOp(
            opId: String(persistence.nextOpId),
            recordType: recordType,
            recordId: recordId,
            fields: fields,
            deleted: deleted,
            hlc: nextClock()
        )

        persistence.nextOpId += 1
        outbox.append(op)
        recordHLCs[recordKey(recordType, recordId)] = op.hlc
        saveSyncState()
    }

    private func push(passphrase: String) async throws {
        guard !outbox.isEmpty else { return }

        let snapshotIds = Set(outbox.map(\.opId))
        let snapshot = outbox.filter { snapshotIds.contains($0.opId) }
        let request = PushRequest(passphrase: passphrase, deviceId: persistence.deviceId, ops: snapshot)
        let response: PushResponse = try await post("v2/push", body: request)
        let handled = Set(response.accepted.map(\.opId) + response.rejected.map(\.opId))

        outbox.removeAll { handled.contains($0.opId) }
        persistence.saveOutbox(outbox)
    }

    private func pull(passphrase: String) async throws -> Bool {
        let request = PullRequest(passphrase: passphrase, deviceId: persistence.deviceId, sinceSeq: persistence.serverSeq)
        let response: PullResponse = try await post("v2/pull", body: request)
        var changed = false

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        for record in response.records {
            if applyRemoteRecord(record) {
                changed = true
            }
        }

        if response.serverSeq > persistence.serverSeq {
            persistence.serverSeq = response.serverSeq
        }
        persistence.saveRecordHLCs(recordHLCs)

        return changed
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(_ path: String, body: RequestBody) async throws -> ResponseBody {
        var request = URLRequest(url: apiURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SyncError.badResponse
        }

        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }

    private func applyRemoteRecord(_ record: SyncRecord) -> Bool {
        let key = recordKey(record.recordType, record.recordId)
        if let local = recordHLCs[key], record.hlc <= local {
            return false
        }

        recordHLCs[key] = record.hlc
        receiveClock(record.hlc)

        switch record.recordType {
        case "todo":
            applyTodo(record)
        case "plan":
            if record.deleted {
                persistence.removePlan(id: record.recordId)
            } else if let plan = try? record.fields.decode(DailyPlan.self) {
                persistence.savePlan(plan, id: record.recordId)
            }
        case "week":
            if record.deleted {
                persistence.removeWeek(id: record.recordId)
            } else if let week = try? record.fields.decode(WeekGoal.self) {
                persistence.saveWeek(week, id: record.recordId)
            }
        case "setting":
            if record.deleted {
                persistence.removeSetting(id: record.recordId)
            } else if let value = record.fields.objectValue?["value"]?.stringValue {
                persistence.saveSetting(id: record.recordId, value: value)
            }
        default:
            break
        }

        return true
    }

    private func applyTodo(_ record: SyncRecord) {
        var todos = persistence.loadTodos()
        let index = todos.firstIndex { $0.id == record.recordId }

        if record.deleted {
            if let index {
                todos.remove(at: index)
                persistence.saveTodos(todos)
            }
            return
        }

        let item = TodoItem(
            id: record.recordId,
            text: record.fields.objectValue?["text"]?.stringValue ?? "",
            done: record.fields.objectValue?["done"]?.boolValue ?? false
        )

        if let index {
            todos[index] = item
        } else {
            todos.append(item)
        }
        persistence.saveTodos(todos)
    }

    private func seedOutboxFromLocal() {
        for item in persistence.loadTodos() {
            enqueue(recordType: "todo", recordId: item.id, fields: item, deleted: false)
        }

        for key in persistence.userDataKeys() {
            if key.hasPrefix(DateKeys.planPrefix) {
                let id = String(key.dropFirst(DateKeys.planPrefix.count))
                let plan = persistence.load(DailyPlan.self, rawKey: key, fallback: DailyPlan())
                enqueue(recordType: "plan", recordId: id, fields: plan, deleted: false)
            } else if key.hasPrefix(DateKeys.weekPrefix) {
                let id = String(key.dropFirst(DateKeys.weekPrefix.count))
                let week = persistence.load(WeekGoal.self, rawKey: key, fallback: WeekGoal())
                enqueue(recordType: "week", recordId: id, fields: week, deleted: false)
            } else if key == "onething-theme" || key == "onething-install-dismissed" {
                let id = String(key.dropFirst("onething-".count))
                enqueue(recordType: "setting", recordId: id, fields: ["value": persistence.defaults.string(forKey: key) ?? ""], deleted: false)
            }
        }
    }

    private func nextClock() -> HLC {
        let wall = Int64(Date().timeIntervalSince1970 * 1000)
        if wall > clock.physical {
            clock.physical = wall
            clock.logical = 0
        } else {
            clock.logical += 1
        }
        clock.device = persistence.deviceId
        persistence.saveClock(clock)
        return clock
    }

    private func receiveClock(_ remote: HLC) {
        let wall = Int64(Date().timeIntervalSince1970 * 1000)
        let newPhysical = max(clock.physical, remote.physical, wall)
        let newLogical: Int

        if newPhysical == clock.physical && newPhysical == remote.physical {
            newLogical = max(clock.logical, remote.logical) + 1
        } else if newPhysical == clock.physical {
            newLogical = clock.logical + 1
        } else if newPhysical == remote.physical {
            newLogical = remote.logical + 1
        } else {
            newLogical = 0
        }

        clock = HLC(physical: newPhysical, logical: newLogical, device: persistence.deviceId)
        persistence.saveClock(clock)
    }

    private func saveSyncState() {
        persistence.saveOutbox(outbox)
        persistence.saveRecordHLCs(recordHLCs)
    }

    private func recordKey(_ type: String, _ id: String) -> String {
        type + ":" + id
    }
}

extension JSONValue {
    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}

enum SyncConnectError: LocalizedError {
    case shortPassphrase

    var errorDescription: String? {
        "Passphrase must be at least 4 characters."
    }
}

enum SyncError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        "The sync server returned an unexpected response."
    }
}

private extension LocalPersistence {
    func load<T: Decodable>(_ type: T.Type, rawKey: String, fallback: T) -> T {
        guard let data = defaults.data(forKey: rawKey) else { return fallback }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? fallback
    }
}
