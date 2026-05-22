import SwiftUI

@main
struct OneThingApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sync: SyncEngine
    @StateObject private var store: OneThingStore

    init() {
        let persistence = LocalPersistence()
        let secrets = KeychainStore()
        let sync = SyncEngine(persistence: persistence, secrets: secrets)

        _sync = StateObject(wrappedValue: sync)
        _store = StateObject(wrappedValue: OneThingStore(persistence: persistence, sync: sync))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(sync)
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        sync.start()
                    } else {
                        sync.stop()
                    }
                }
        }
    }
}
