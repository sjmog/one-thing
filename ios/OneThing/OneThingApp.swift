import SwiftUI
import UIKit

@main
struct OneThingApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sync: SyncEngine
    @StateObject private var store: OneThingStore

    init() {
        let persistence = LocalPersistence()
        let secrets = KeychainStore()
        let sync = SyncEngine(persistence: persistence, secrets: secrets)

        UIApplication.shared.applicationSupportsShakeToEdit = false
        _sync = StateObject(wrappedValue: sync)
        _store = StateObject(wrappedValue: OneThingStore(persistence: persistence, sync: sync))
    }

    var body: some Scene {
        WindowGroup {
            ShakeHostingView {
                NotificationCenter.default.post(name: .shakeUndoRequested, object: nil)
            } content: {
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
}

extension Notification.Name {
    static let shakeUndoRequested = Notification.Name("shakeUndoRequested")
}

private struct ShakeHostingView<Content: View>: UIViewControllerRepresentable {
    let onShake: () -> Void
    let content: Content

    init(onShake: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onShake = onShake
        self.content = content()
    }

    func makeUIViewController(context: Context) -> ShakeHostingController<Content> {
        ShakeHostingController(rootView: content, onShake: onShake)
    }

    func updateUIViewController(_ controller: ShakeHostingController<Content>, context: Context) {
        controller.rootView = content
        controller.onShake = onShake
        controller.refreshFirstResponder()
    }
}

private final class ShakeHostingController<Content: View>: UIHostingController<Content> {
    var onShake: () -> Void

    init(rootView: Content, onShake: @escaping () -> Void) {
        self.onShake = onShake
        super.init(rootView: rootView)
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake()
        } else {
            super.motionEnded(motion, with: event)
        }
    }

    func refreshFirstResponder() {
        DispatchQueue.main.async { [weak self] in
            self?.becomeFirstResponder()
        }
    }
}
