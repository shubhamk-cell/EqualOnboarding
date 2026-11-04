import SwiftUI
import Lottie

@main
struct EqualOrbApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Parse the two walkthrough animations off the main thread so they're cached
        // (and instant) by the time their screens slide in.
        Task.detached(priority: .utility) {
            _ = LottieAnimation.named("forwarding")
            _ = LottieAnimation.named("voicemail")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}
