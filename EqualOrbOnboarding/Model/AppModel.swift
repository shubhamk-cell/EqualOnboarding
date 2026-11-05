import SwiftUI
import UserNotifications
import Contacts

/// Every stop on the journey, in order. After the code is confirmed the flow runs the
/// “full setup in one go” steps: name → picks (with sample calls) → permissions →
/// call forwarding → Live Voicemail → welcome → home.
enum Step: Int, Comparable {
    /// `instruct` and `handle` are V2 only: say an instruction out loud, then hear how Equal will
    /// follow it.
    case splash, phone, otp, name, cases, instruct, handle, permq, fwd, access, welcome, home

    static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }

    /// Steps with a Skip button in the top bar.
    var skippable: Bool { [.cases, .instruct, .handle, .permq, .access].contains(self) }
    var hasBack: Bool { self != .phone && self != .welcome }
}

/// Modal surfaces drawn above the flow.
enum Overlay: Equatable {
    case consent
    /// Equal's sheet after the iOS prompts, for whichever permissions were refused.
    case decline([Permission])
    case ussd
}

/// The orb's last flight, from Welcome into Home's Equal button.
struct OrbDock: Equatable {
    var frame: CGRect
    /// 0 = the flow's orb, 1 = Home's Equal button. Rises with the flight, so the orb turns
    /// into the button's artwork on the way down.
    var morph: CGFloat = 0
    /// Critically damped, so it settles exactly on the button without overshooting.
    static let flight = Animation.spring(response: 0.8, dampingFraction: 1)
    /// How long the flight takes to settle after its last retarget.
    static let settle = 1.1
}

/// The languages the orb can speak. Tapping the orb steps through them in this order.
enum Lang: String, CaseIterable, Identifiable {
    case en, hi, ta, bn
    var id: String { rawValue }
    /// Each language's name in its own script.
    var name: String {
        switch self {
        case .en: "English"
        case .hi: "हिन्दी"
        case .ta: "தமிழ்"
        case .bn: "বাংলা"
        }
    }
}

/// Which language the orb's bubbles are in. Shared by every bubble on every screen.
@MainActor
final class Language: ObservableObject {
    static let shared = Language()
    @Published var current: Lang = .en
    /// After the first nudge of the orb, the header also offers a language menu.
    @Published var menuUnlocked = false

    /// The orb was tapped or dragged: the next language, wrapping round to the first.
    func next() {
        let all = Lang.allCases
        current = all[(all.firstIndex(of: current)! + 1) % all.count]
        menuUnlocked = true
    }

    func reset() {
        current = .en
        menuUnlocked = false
    }
}

/// Which onboarding runs. The app always starts with V1; V2 is an experiment started from the
/// profile tab. It swaps the sample calls after the picks for a step where you say an
/// instruction (one Equal drafted from your picks, or your own) and hear a call that follows it.
enum Variant { case v1, v2 }

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
    @Published var variant: Variant = .v1
    /// V2: the instruction the user said or typed, its recording (when spoken), and the pick it
    /// was matched to.
    @Published var instruction: String?
    var instructionNote: VoiceNote?
    var instructionPick: String?
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

    /// The flow's one orb: where it sits and whether it's fading away.
    @Published var orbSpot: OrbSpot?
    /// The orb has settled into the current screen's slot, which now draws it (see `OrbSlot`).
    @Published var orbInSlot = false
    private var settleWork: DispatchWorkItem?
    /// After Welcome the orb flies down into Home's Equal button and becomes it.
    @Published var orbDock: OrbDock?
    private var dockLanding: DispatchWorkItem?
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
            if let v = args.firstIndex(of: "-variant"), v + 1 < args.count, args[v + 1] == "v2" { variant = .v2 }
            let names: [String: Step] = ["phone": .phone, "otp": .otp, "name": .name, "cases": .cases,
                                         "instruct": .instruct, "handle": .handle, "permq": .permq,
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

    /// Moves to `to`. `haptic: false` when the caller marks the moment itself (a verified code).
    func go(_ to: Step, direction dir: CGFloat = 1, haptic: Bool = true) {
        if haptic { Haptics.step() }
        // The outgoing screen must render once with its new exit transition before it leaves.
        let rerender = dir != direction || arrivingFromSplash
        direction = dir
        arrivingFromSplash = false
        if to != .home { OrbFlight.departing() }
        // The stage takes the orb back for the flight to the next screen.
        settleWork?.cancel()
        orbInSlot = false
        if rerender {
            DispatchQueue.main.async { withAnimation(EQ.push()) { self.step = to } }
        } else {
            withAnimation(EQ.push()) { step = to }
        }
    }

    func next() {
        guard var n = Step(rawValue: step.rawValue + 1) else { return }
        if variant == .v1, n == .instruct || n == .handle { n = .permq }
        go(n)
    }

    func back() {
        switch step {
        case .otp: go(.phone, direction: -1)
        case .name: go(.phone, direction: -1)   // past the code, which fills itself in
        case .cases: go(.name, direction: -1)
        case .instruct: go(.cases, direction: -1)
        case .handle: go(.instruct, direction: -1)
        case .permq: go(variant == .v2 ? .handle : .cases, direction: -1)
        case .fwd: go(.permq, direction: -1)
        case .access: go(.fwd, direction: -1)
        default: break
        }
    }

    func skip() { next() }

    func exitToHome() {
        if step != .welcome { Haptics.step() }   // Welcome hands over to the orb's landing instead
        withAnimation(EQ.ease(0.45)) { step = .home }
    }

    /// Starts the whole thing again: V1 from a long-press on the Home logo, V2 from the profile tab.
    func restart(_ v: Variant = .v1) {
        variant = v
        instruction = nil; instructionNote = nil; instructionPick = nil
        phone = ""; name = ""; whatsapp = true; picks = []
        perms = [nil, nil]; consentAsked = false; fwdDone = false; accessDone = false
        overlay = nil; toast = nil
        orbSpot = nil; orbInSlot = false; settleWork?.cancel(); orbDock = nil; dockLanding?.cancel(); dockLanding = nil
        Language.shared.reset()
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
        // Settled in its slot, the orb moves with the screen; just keep the stage's spot current.
        guard !orbInSlot else { orbSpot = spot; return }
        guard orbSpot == nil else {
            withAnimation(OrbFlight.glide) { orbSpot = spot }
            settleIntoSlot(after: 1.0)
            return
        }
        guard let mark = splashMark else { orbSpot = spot; settleIntoSlot(after: 0); return }
        let d = spot.frame.width * 0.68
        var start = spot
        start.frame = CGRect(x: mark.x - flowOrigin.x - d / 2, y: mark.y - flowOrigin.y - d / 2, width: d, height: d)
        orbSpot = start
        DispatchQueue.main.async { withAnimation(EQ.push(1.0)) { self.orbSpot = spot } }
        settleIntoSlot(after: 1.1)
    }

    /// Hands the orb to its slot once the glide has come to rest.
    private func settleIntoSlot(after delay: Double) {
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { self?.orbInSlot = true }
        }
        settleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Welcome is done: lift the orb out of the flow (where it is now, in global coordinates)
    /// so it can fly into Home's Equal button.
    func dockOrb() {
        guard let spot = orbSpot else { return }
        orbDock = OrbDock(frame: spot.frame.offsetBy(dx: flowOrigin.x, dy: flowOrigin.y))
        dockLanding?.cancel()
        dockLanding = nil
    }

    /// Home's Equal button is at `fab` (global): fly there while turning into its artwork, then,
    /// once settled, swap for the real button — the two are drawn the same, so nothing changes.
    func dockTarget(_ fab: CGRect) {
        guard orbDock != nil, fab != .zero else { return }
        withAnimation(OrbDock.flight) {
            orbDock?.frame = fab
            orbDock?.morph = 1
        }
        // Home slides in as it appears, so the button moves for a moment: land only once the
        // flight has settled after the last move.
        dockLanding?.cancel()
        let land = DispatchWorkItem { [weak self] in
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { self?.orbDock = nil }
            Haptics.land()
        }
        dockLanding = land
        DispatchQueue.main.asyncAfter(deadline: .now() + OrbDock.settle, execute: land)
    }

    // MARK: Overlays

    /// Shows an overlay and waits until it is resolved with a result string.
    func present(_ o: Overlay) async -> String {
        await withCheckedContinuation { c in
            overlayContinuation?.resume(returning: "superseded")
            overlayContinuation = c
            if case .decline = o { Haptics.warning() }
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
