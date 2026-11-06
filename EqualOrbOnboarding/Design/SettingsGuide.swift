import AVKit
import SwiftUI
import UIKit

/// Floats a short walkthrough in Picture in Picture while the user does a step outside Equal:
/// the voicemail settings in iPhone Settings (`settings_guide`, which also opens Settings), or
/// dialling the forwarding code in the Phone app (`forwarding_guide`; iOS doesn't let an app
/// open Phone, so the user goes there themselves and the guide floats along).
/// The videos are rendered by `tools/render_settings_guide.swift` and `render_forwarding_guide.swift`.
@MainActor
final class SettingsGuide: NSObject, ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var pip: AVPictureInPictureController?

    /// True from “Open Settings” until the user is back in Equal.
    @Published private(set) var active = false
    private let opensSettings: Bool

    init(video: String = "settings_guide", opensSettings: Bool = true) {
        self.opensSettings = opensSettings
        super.init()
        if let url = Bundle.main.url(forResource: video, withExtension: "mp4") {
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        }
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    fileprivate func attach(_ layer: AVPlayerLayer) {
        guard pip == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let pip = AVPictureInPictureController(playerLayer: layer)
        pip?.delegate = self
        // If the explicit start below loses the race, PiP still starts as Equal goes to the background.
        pip?.canStartPictureInPictureAutomaticallyFromInline = true
        self.pip = pip
    }

    /// Starts the walkthrough in PiP, then (for the voicemail guide) opens Settings.
    func start() async {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
        try? session.setActive(true)
        await player.seek(to: .zero)
        player.play()
        active = true

        // PiP is possible once the player has a frame on screen.
        for _ in 0..<30 where pip?.isPictureInPicturePossible != true {
            try? await Task.sleep(for: .milliseconds(50))
        }
        pip?.startPictureInPicture()
        guard opensSettings else { return }
        try? await Task.sleep(for: .milliseconds(400))
        openSettings()
    }

    /// Back in Equal: put the walkthrough away.
    func finish() {
        guard active else { return }
        active = false
        pip?.stopPictureInPicture()
        player.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Equal AI's own page in Settings, the only one Apple lets an app open. The walkthrough
    /// starts there: ‹ Apps, then Phone.
    private func openSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}

extension SettingsGuide: AVPictureInPictureControllerDelegate {
    /// The PiP window's “back to app” button: the system brings Equal forward, nothing to rebuild.
    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completion: @escaping (Bool) -> Void
    ) {
        completion(true)
    }
}

/// The inline player PiP lifts the video from. It has to be on screen, so it hides behind an opaque view.
struct SettingsGuideAnchor: UIViewRepresentable {
    let guide: SettingsGuide

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = guide.player
        view.playerLayer.videoGravity = .resizeAspect
        view.isUserInteractionEnabled = false
        guide.attach(view.playerLayer)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
