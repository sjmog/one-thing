import Foundation

final class LocalPersistence {
    private enum Key {
        static let deviceId = "onething-sync-v2-device-id"
        static let enabled = "onething-sync-v2-enabled"
        static let syncedOnce = "onething-sync-v2-synced-once"
        static let serverSeq = "onething-sync-v2-server-seq"
        static let hlc = "onething-sync-v2-hlc"
        static let outbox = "onething-sync-v2-outbox"
        static let nextOpId = "onething-sync-v2-next-op-id"
        static let recordHLCs = "onething-sync-v2-hlcs"
        static let lastSync = "onething-sync-v2-last"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var deviceId: String {
        if let value = defaults.string(forKey: Key.deviceId), !value.isEmpty {
            return value
        }

        let value = UUID().uuidString
        defaults.set(value, forKey: Key.deviceId)
        return value
    }

    var syncEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var syncedOnce: Bool {
        get { defaults.bool(forKey: Key.syncedOnce) }
        set { defaults.set(newValue, forKey: Key.syncedOnce) }
    }

    var serverSeq: Int64 {
        get { Int64(defaults.integer(forKey: Key.serverSeq)) }
        set { defaults.set(Int(newValue), forKey: Key.serverSeq) }
    }

    var nextOpId: Int {
        get {
            let value = defaults.integer(forKey: Key.nextOpId)
            return value == 0 ? 1 : value
        }
        set { defaults.set(newValue, forKey: Key.nextOpId) }
    }

    var lastSync: Date? {
        get {
            let value = defaults.double(forKey: Key.lastSync)
            return value == 0 ? nil : Date(timeIntervalSince1970: value / 1000)
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970 * 1000, forKey: Key.lastSync)
            } else {
                defaults.removeObject(forKey: Key.lastSync)
            }
        }
    }

    func loadTodos() -> [TodoItem] {
        load([TodoItem].self, key: DateKeys.listKey, fallback: [])
    }

    func saveTodos(_ todos: [TodoItem]) {
        save(todos, key: DateKeys.listKey)
    }

    func loadPlan(for date: Date) -> DailyPlan {
        load(DailyPlan.self, key: DateKeys.planKey(date), fallback: DailyPlan())
    }

    func savePlan(_ plan: DailyPlan, for date: Date) {
        save(plan, key: DateKeys.planKey(date))
    }

    func loadWeek(for date: Date) -> WeekGoal {
        load(WeekGoal.self, key: DateKeys.weekKey(date), fallback: WeekGoal())
    }

    func saveWeek(_ week: WeekGoal, for date: Date) {
        save(week, key: DateKeys.weekKey(date))
    }

    func removePlan(id: String) {
        defaults.removeObject(forKey: DateKeys.planPrefix + id)
    }

    func savePlan(_ plan: DailyPlan, id: String) {
        save(plan, key: DateKeys.planPrefix + id)
    }

    func removeWeek(id: String) {
        defaults.removeObject(forKey: DateKeys.weekPrefix + id)
    }

    func saveWeek(_ week: WeekGoal, id: String) {
        save(week, key: DateKeys.weekPrefix + id)
    }

    func saveSetting(id: String, value: String) {
        defaults.set(value, forKey: "onething-" + id)
    }

    func removeSetting(id: String) {
        defaults.removeObject(forKey: "onething-" + id)
    }

    func loadOutbox() -> [SyncOp] {
        load([SyncOp].self, key: Key.outbox, fallback: [])
    }

    func saveOutbox(_ ops: [SyncOp]) {
        save(ops, key: Key.outbox)
    }

    func loadClock() -> HLC {
        load(HLC.self, key: Key.hlc, fallback: HLC(physical: 0, logical: 0, device: deviceId))
    }

    func saveClock(_ clock: HLC) {
        save(clock, key: Key.hlc)
    }

    func loadRecordHLCs() -> [String: HLC] {
        load([String: HLC].self, key: Key.recordHLCs, fallback: [:])
    }

    func saveRecordHLCs(_ recordHLCs: [String: HLC]) {
        save(recordHLCs, key: Key.recordHLCs)
    }

    func userDataKeys() -> [String] {
        defaults.dictionaryRepresentation().keys.filter(isSyncableKey).sorted()
    }

    func resetSyncMetadata() {
        defaults.removeObject(forKey: Key.enabled)
        defaults.removeObject(forKey: Key.syncedOnce)
        defaults.removeObject(forKey: Key.serverSeq)
        defaults.removeObject(forKey: Key.outbox)
        defaults.removeObject(forKey: Key.recordHLCs)
        defaults.removeObject(forKey: Key.lastSync)
    }

    func isSyncableKey(_ key: String) -> Bool {
        key == DateKeys.listKey
            || key.hasPrefix(DateKeys.planPrefix)
            || key.hasPrefix(DateKeys.weekPrefix)
            || key == "onething-theme"
            || key == "onething-install-dismissed"
    }

    private func load<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
        guard let data = defaults.data(forKey: key) else { return fallback }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? fallback
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
