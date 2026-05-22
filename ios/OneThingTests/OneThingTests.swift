import XCTest
@testable import OneThing

@MainActor
final class OneThingTests: XCTestCase {
    func testDateAndWeekKeysUseExistingWebShape() {
        let components = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 5, day: 21)
        let date = components.date!

        XCTAssertEqual(DateKeys.dayString(date), "2026-05-21")
        XCTAssertEqual(DateKeys.planKey(date), "onething-plan-2026-05-21")
        XCTAssertEqual(DateKeys.weekKey(date), "onething-week-2026-05-18")
    }

    func testNiceItemsDecodeLegacyStringValues() throws {
        let data = #"{"goal":"Ship","niceToDo":["Email",{"text":"Walk","done":true}],"hygieneLeft":[],"hygieneRight":[]}"#.data(using: .utf8)!
        let plan = try JSONDecoder().decode(DailyPlan.self, from: data)

        XCTAssertEqual(plan.niceToDo, [
            NiceItem(text: "Email", done: false),
            NiceItem(text: "Walk", done: true)
        ])
    }

    func testHLCComparisonUsesPhysicalLogicalDeviceOrder() {
        let a = HLC(physical: 1, logical: 0, device: "b")
        let b = HLC(physical: 1, logical: 1, device: "a")
        let c = HLC(physical: 1, logical: 1, device: "b")

        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
    }

    func testPersistenceRoundTripsPlansAndTodos() {
        let persistence = testPersistence()
        let date = Date(timeIntervalSince1970: 1_779_321_600)
        let plan = DailyPlan(goal: "One thing", goalCompleted: true, niceToDo: [NiceItem(text: "Small thing")])
        let todos = [TodoItem(id: "todo-1", text: "Backlog", done: false)]

        persistence.savePlan(plan, for: date)
        persistence.saveTodos(todos)

        XCTAssertEqual(persistence.loadPlan(for: date), plan)
        XCTAssertEqual(persistence.loadTodos(), todos)
    }

    func testVisibleTodosMatchesHtmlCompletedFirstOrdering() {
        let persistence = testPersistence()
        let sync = SyncEngine(
            apiURL: URL(string: "https://example.test")!,
            persistence: persistence,
            secrets: MemorySecretStore(),
            session: StubSession(responses: [])
        )
        persistence.saveTodos([
            TodoItem(id: "done", text: "Done", done: true),
            TodoItem(id: "open", text: "Open", done: false)
        ])

        let store = OneThingStore(persistence: persistence, sync: sync)

        XCTAssertEqual(store.visibleTodos.map(\.id), ["done", "open"])
    }

    func testSyncPushClearsHandledOutboxAndPullAppliesRemotePlan() async throws {
        let persistence = testPersistence()
        let secrets = MemorySecretStore()
        try secrets.savePassphrase("secret")
        persistence.syncEnabled = true

        let remotePlan = DailyPlan(goal: "Remote", niceToDo: [NiceItem(text: "Synced")])
        let remoteHLC = HLC(physical: Int64(Date().timeIntervalSince1970 * 1000) + 1_000, logical: 0, device: "web")
        let record = SyncRecord(
            recordType: "plan",
            recordId: "2026-05-21",
            fields: try JSONValue.from(remotePlan),
            deleted: false,
            hlc: remoteHLC,
            serverSeq: 7
        )

        let pullBody = try pullResponseBody(records: [record], serverSeq: 7)
        let session = StubSession(responses: [
            StubSession.Response(status: 200, body: #"{"accepted":[{"opId":"1","serverSeq":6}],"rejected":[]}"#),
            StubSession.Response(status: 200, body: pullBody)
        ])

        let sync = SyncEngine(
            apiURL: URL(string: "https://example.test")!,
            persistence: persistence,
            secrets: secrets,
            session: session
        )

        sync.recordPlan(DailyPlan(goal: "Local"), for: date(2026, 5, 21))
        await sync.syncNow()

        XCTAssertEqual(persistence.loadOutbox(), [])
        XCTAssertEqual(persistence.serverSeq, 7)
        XCTAssertEqual(persistence.loadPlan(for: date(2026, 5, 21)), remotePlan)
    }

    func testTombstoneDeletesTodo() async throws {
        let persistence = testPersistence()
        let secrets = MemorySecretStore()
        try secrets.savePassphrase("secret")
        persistence.syncEnabled = true
        persistence.saveTodos([TodoItem(id: "a", text: "Delete me")])

        let tombstone = SyncRecord(
            recordType: "todo",
            recordId: "a",
            fields: .object([:]),
            deleted: true,
            hlc: HLC(physical: 10, logical: 0, device: "web"),
            serverSeq: 1
        )

        let body = try pullResponseBody(records: [tombstone], serverSeq: 1)
        let session = StubSession(responses: [
            StubSession.Response(status: 200, body: body)
        ])
        let sync = SyncEngine(apiURL: URL(string: "https://example.test")!, persistence: persistence, secrets: secrets, session: session)

        await sync.syncNow()

        XCTAssertEqual(persistence.loadTodos(), [])
    }

    func testRemoteSettingAdvancesClockAndUpdatesCursor() async throws {
        let persistence = testPersistence()
        let secrets = MemorySecretStore()
        try secrets.savePassphrase("secret")
        persistence.syncEnabled = true

        let remoteHLC = HLC(
            physical: Int64(Date().addingTimeInterval(60).timeIntervalSince1970 * 1000),
            logical: 3,
            device: "web"
        )
        let setting = SyncRecord(
            recordType: "setting",
            recordId: "theme",
            fields: .object(["value": .string("dark")]),
            deleted: false,
            hlc: remoteHLC,
            serverSeq: 9
        )
        let session = StubSession(responses: [
            StubSession.Response(status: 200, body: try pullResponseBody(records: [setting], serverSeq: 9))
        ])
        let sync = SyncEngine(apiURL: URL(string: "https://example.test")!, persistence: persistence, secrets: secrets, session: session)

        await sync.syncNow()

        XCTAssertEqual(persistence.defaults.string(forKey: "onething-theme"), "dark")
        XCTAssertEqual(persistence.serverSeq, 9)
        XCTAssertEqual(persistence.loadClock().physical, remoteHLC.physical)
        XCTAssertEqual(persistence.loadClock().logical, remoteHLC.logical + 1)
    }

    private func testPersistence() -> LocalPersistence {
        let suiteName = "OneThingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return LocalPersistence(defaults: defaults)
    }

    private func pullResponseBody(records: [SyncRecord], serverSeq: Int64) throws -> String {
        let recordsJSON = try records
            .map { try String(data: JSONEncoder().encode($0), encoding: .utf8)! }
            .joined(separator: ",")
        return #"{"records":[\#(recordsJSON)],"serverSeq":\#(serverSeq)}"#
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: Calendar(identifier: .gregorian), year: year, month: month, day: day).date!
    }
}

final class MemorySecretStore: SecretStore {
    private var passphrase: String?

    func readPassphrase() -> String? {
        passphrase
    }

    func savePassphrase(_ passphrase: String) throws {
        self.passphrase = passphrase
    }

    func deletePassphrase() {
        passphrase = nil
    }
}

final class StubSession: HTTPSession {
    struct Response {
        var status: Int
        var body: String
    }

    private var responses: [Response]

    init(responses: [Response]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        let response = responses.removeFirst()
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: nil, headerFields: nil)!
        return (Data(response.body.utf8), http)
    }
}
