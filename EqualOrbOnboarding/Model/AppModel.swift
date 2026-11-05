import SwiftUI
import UserNotifications
import Contacts

/// Every stop on the journey, in order. After the code is confirmed the flow runs the
/// “full setup in one go” steps: name → picks (with sample calls) → permissions →
/// call forwarding → Live Voicemail → welcome → home.
enum Step: Int, Comparable {
    case splash, phone, otp, name, cases, permq, fwd, access, welcome, home

    static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }

    /// Steps with a Skip button in the top bar.
    var skippable: Bool { [.cases, .permq, .access].contains(self) }
    var hasBack: Bool { self != .phone && self != .welcome }
}

/// Modal surfaces drawn above the flow.
enum Overlay: Equatable {
    case consent
    /// Equal's sheet after the iOS prompts, for whichever permissions were refused.
    case decline([Permission])
    case ussd
}

enum Permission { case notifications, contacts }

extension Array where Element == Permission {
    /// The 3D art for whatever is missing: a bell, a contacts book, or a gear for both.
    var art: String {
        count > 1 ? "PermGear" : first == .notifications ? "PermBell" : "PermContacts"
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var step: Step = .splash
    /// +1 pushes forward (new screen from the right), −1 goes back.
    @Published var direction: CGFloat = 1
    /// True only for the first screen after the splash, which arrives with its own choreography.
    @Published var arrivingFromSplash = false
    /// Where the splash's Equal mark was on screen when it left (global coordinates).
    var splashMark: CGPoint?

    @Published var phone = ""
    @Published var name = ""
    @Published var whatsapp = true
    @Published var picks: [String] = []
    @Published var perms: [Bool?] = [nil, nil]
    @Published var consentAsked = false
    @Published var fwdDone = false
    @Published var accessDone = false

    /// The flow's one orb: where it sits, what tapping it does, and whether it's fading away.
    @Published var orbSpot: OrbSpot?
    @Published var orbLeaving = false
    var orbOnPlay: ((OrbPlay) -> Void)?
    /// Top-left of the flow container in global coordinates (to place the splash mark in it).
    var flowOrigin: CGPoint = .zero

    @Published var overlay: Overlay?
    @Published var toast: String?
    private var toastWork: DispatchWorkItem?
    private var overlayContinuation: CheckedContinuation<String, Never>?

    var displayName: String { name.isEmpty ? "Keshav" : name }

    init() {
        #if DEBUG
        // Jump straight to a screen while developing: launch with `-startStep access`.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-startStep"), i + 1 < args.count {
            let names: [String: Step] = ["phone": .phone, "otp": .otp, "name": .name, "cases": .cases, "permq": .permq,
                                         "fwd": .fwd, "access": .access, "welcome": .welcome, "home": .home]
            if let s = names[args[i + 1]] {
                step = s
                name = "Shubham"
                phone = "9876543210"
                picks = ["task_door", "bank", "task_med"]
            }
        }
        #endif
    }

    // MARK: Navigation

    func go(_ to: Step, direction dir: CGFloat = 1) {
        // The outgoing screen must render once with its new exit transition before it leaves.
        let rerender = dir != direction || arrivingFromSplash
        direction = dir
        arrivingFromSplash = false
        if to != .home { OrbFlight.departing() }
        if rerender {
            DispatchQueue.main.async { withAnimation(EQ.push()) { self.step = to } }
        } else {
            withAnimation(EQ.push()) { step = to }
        }
    }

    func next() {
        guard let n = Step(rawValue: step.rawValue + 1) else { return }
        go(n)
    }

    func back() {
        switch step {
        case .otp: go(.phone, direction: -1)
        case .name: exitToHome()          // first setup question: leaving it goes home, as in the prototype
        case .cases: go(.name, direction: -1)
        case .permq: go(.cases, direction: -1)
        case .fwd: go(.permq, direction: -1)
        case .access: go(.fwd, direction: -1)
        default: break
        }
    }

    func skip() { next() }

    func exitToHome() {
        withAnimation(EQ.ease(0.45)) { step = .home }
    }

    /// Starts the whole thing again (long-press the logo on Home).
    func restart() {
        phone = ""; name = ""; whatsapp = true; picks = []
        perms = [nil, nil]; consentAsked = false; fwdDone = false; accessDone = false
        overlay = nil; toast = nil
        orbSpot = nil; orbLeaving = false
        arrivingFromSplash = false
        direction = 1
        withAnimation(.easeInOut(duration: 0.35)) { step = .splash }
    }

    // MARK: Orb

    /// Moves the orb to a screen's slot: a smooth glide between screens, or, the first time,
    /// a rise out of the splash's mark.
    /// Permissions still off, from `perms` (nil = not asked yet, which counts as off too).
    var missingPermissions: [Permission] {
        (perms[0] == true ? [] : [Permission.notifications]) + (perms[1] == true ? [] : [.contacts])
    }

    /// Reads what iOS actually has granted (it may have changed in Settings).
    func refreshPermissions() async {
        let n = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let c = CNContactStore.authorizationStatus(for: .contacts)
        let notifications = [.authorized, .provisional, .ephemeral].contains(n)
        var contacts = c == .authorized
        if #available(iOS 18, *), c == .limited { contacts = true }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { perms = [notifications, contacts] }
    }

    func place(_ spot: OrbSpot) {
        guard spot != orbSpot else { return }
        guard orbSpot == nil else {
            withAnimation(OrbFlight.glide) { orbSpot = spot }
            return
        }
        guard let mark = splashMark else { orbSpot = spot; return }
        let d = spot.frame.width * 0.68
        var start = spot
        start.frame = CGRect(x: mark.x - flowOrigin.x - d / 2, y: mark.y - flowOrigin.y - d / 2, width: d, height: d)
        orbSpot = start
        DispatchQueue.main.async { withAnimation(EQ.push(1.0)) { self.orbSpot = spot } }
    }

    // MARK: Overlays

    /// Shows an overlay and waits until it is resolved with a result string.
    func present(_ o: Overlay) async -> String {
        await withCheckedContinuation { c in
            overlayContinuation?.resume(returning: "superseded")
            overlayContinuation = c
            withAnimation(EQ.push(0.42)) { overlay = o }
        }
    }

    func resolve(_ result: String) {
        let c = overlayContinuation
        overlayContinuation = nil
        withAnimation(EQ.push(0.38)) { overlay = nil }
        c?.resume(returning: result)
    }

    /// Equal's own consent for processing call data. Asked once.
    func askConsentOnce() async {
        guard !consentAsked else { return }
        consentAsked = true
        let r = await present(.consent)
        if r != "allow" {
            show(toast: "You can turn this on later in Settings — Equal can’t answer calls without it")
        }
    }

    func show(toast text: String) {
        toastWork?.cancel()
        withAnimation(EQ.ease(0.2)) { toast = text }
        let w = DispatchWorkItem { [weak self] in withAnimation(.easeOut(duration: 0.25)) { self?.toast = nil } }
        toastWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: w)
    }
}
