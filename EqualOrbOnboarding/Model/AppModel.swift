import SwiftUI
import UserNotifications
import Contacts

/// Every screen the onboardings are built from. Each version (`Variant.route`) strings a
/// selection of them together, always from the number to Home.
enum Step: Int, Comparable {
    /// `instruct` and `handle` are V2 only: say an instruction out loud, then hear how Equal will
    /// follow it. `langVoice` is V4 and V5; `listen` (sample calls, no choices) V3, V5 and V6.
    case splash, phone, otp, name, langVoice, cases, listen, instruct, handle, permq, fwd, access, welcome, home

    static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }

    /// Steps with a Skip button in the top bar. Call forwarding never has one, and neither do the
    /// sample-call pages, whose Continue is always ready.
    var skippable: Bool { [.cases, .langVoice, .instruct, .permq, .access].contains(self) }
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

/// Which onboarding runs. The app opens on Home; each version is started from the profile tab.
/// Every one shares sign-up (number, code, name) and ends on Home; they differ in what comes
/// between and what Home does first.
enum Variant: Int, CaseIterable, Identifiable {
    case v1 = 1, v2, v3, v4, v5, v6, v7, v8, v9, v10
    var id: Int { rawValue }
    var label: String { "V\(rawValue)" }

    var name: String {
        switch self {
        case .v1: "Pick tasks + sample calls"
        case .v2: "Speak your first instruction"
        case .v3: "Hear the most common calls"
        case .v4: "Languages first, then pick calls"
        case .v5: "Languages, then just listen"
        case .v6: "Just listen"
        case .v7: "Value first, set up from Home"
        case .v8: "Set up first, value on Home"
        case .v9: "Set up first, personalise on Home"
        case .v10: "Hybrid · permissions in context"
        }
    }

    var detail: String {
        switch self {
        case .v1: "The current flow. Pick what Equal handles, hear your top 3 as sample calls, then set up."
        case .v2: "After the picks, hold to say an instruction and hear a call that follows it."
        case .v3: "No picking. Straight to sample calls of the kinds Equal handles most, in the call player."
        case .v4: "Choose the languages your callers speak, then pick which calls Equal handles and hear them in those languages."
        case .v5: "Choose the languages your callers speak — nothing else. Then listen to everyday calls in them."
        case .v6: "No choices at all. Tap through four everyday calls with a live transcript."
        case .v7: "Picks and samples, then straight to Home. Setup waits in a checklist."
        case .v8: "Permissions, forwarding and voicemail first. Home greets you with sample calls."
        case .v9: "Set up first. Home opens “Make me yours”: voice, language, calls."
        case .v10: "Forwarding and voicemail in the flow. Notifications and contacts asked on Home, in context."
        }
    }

    /// The building blocks in order, for the chips on the profile tab.
    var blocks: [Block] {
        switch self {
        case .v1, .v2, .v3, .v6, .v10: [.signUp, .value, .setUp, .home]
        case .v4, .v5: [.signUp, .personalise, .value, .setUp, .home]
        case .v7: [.signUp, .value, .home, .setUp]
        case .v8: [.signUp, .setUp, .home, .value]
        case .v9: [.signUp, .setUp, .home, .personalise]
        }
    }

    /// The screens, in order.
    var route: [Step] {
        let signUp: [Step] = [.phone, .otp, .name]
        let setUp: [Step] = [.permq, .fwd, .access]
        let end: [Step] = [.welcome, .home]
        switch self {
        case .v1: return signUp + [.cases] + setUp + end
        case .v2: return signUp + [.cases, .instruct, .handle] + setUp + end
        case .v3: return signUp + [.listen] + setUp + end
        case .v4: return signUp + [.langVoice, .cases] + setUp + end
        case .v5: return signUp + [.langVoice, .listen] + setUp + end
        case .v6: return signUp + [.listen] + setUp + end
        case .v7: return signUp + [.cases] + end
        case .v8, .v9: return signUp + setUp + end
        case .v10: return signUp + [.cases, .fwd, .access] + end
        }
    }

    /// Equal speaks in the languages chosen at the start (V4, V5).
    var personalVoice: Bool { self == .v4 || self == .v5 }

    enum Block {
        case signUp, value, setUp, personalise, home
        var title: String {
            switch self {
            case .signUp: "Sign-up"
            case .value: "Show value"
            case .setUp: "Set up"
            case .personalise: "Personalise"
            case .home: "Home"
            }
        }
    }
}

/// Equal's two voices, female and male (V4, V5, V9). Previews use the system's speech voices
/// with the pitch and pace set per voice.
enum Voice: String, CaseIterable, Identifiable {
    case aanya, kabir
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var gender: String { self == .aanya ? "Female" : "Male" }
    var vibe: String { self == .aanya ? "Warm & calm" : "Deep & steady" }
    var emoji: String { self == .aanya ? "🌸" : "🌊" }
    /// Each voice's own colours: a rose-to-peach wash for Aanya, sky-to-teal for Kabir.
    var tint: UInt32 { self == .aanya ? 0xFFE9EF : 0xE3EEFF }
    var wash: [UInt32] { self == .aanya ? [0xFFE3EC, 0xFFF1E4] : [0xDCEBFF, 0xDDF7F1] }
    var accent: UInt32 { self == .aanya ? 0xE0507A : 0x2F6FE0 }
    var pitch: Float { self == .aanya ? 1.1 : 0.72 }
    var rate: Float { self == .aanya ? 0.48 : 0.45 }
}

/// The languages Equal can take calls in (V4, V5, V9) — more than the orb's own bubble languages.
/// `hinglish` isn't offered as a choice; it's the copy used when Hindi and English are both picked.
enum CallLanguage: String, CaseIterable, Identifiable {
    case english, hindi, hinglish, tamil, telugu, kannada, bengali, marathi
    var id: String { rawValue }
    /// The languages offered, in order.
    static let options: [CallLanguage] = [.english, .hindi, .tamil, .telugu, .kannada, .bengali, .marathi]
    /// How many can be picked at once.
    static let maxPicked = 3

    var name: String {
        switch self {
        case .english: "English"
        case .hindi: "हिन्दी"
        case .hinglish: "Hinglish"
        case .tamil: "தமிழ்"
        case .telugu: "తెలుగు"
        case .kannada: "ಕನ್ನಡ"
        case .bengali: "বাংলা"
        case .marathi: "मराठी"
        }
    }
    /// The language's first letter in its own script, drawn as a watermark on its card.
    var initial: String {
        switch self {
        case .english: "E"
        case .hindi: "ह"
        case .hinglish: "H"
        case .tamil: "த"
        case .telugu: "తె"
        case .kannada: "ಕ"
        case .bengali: "বা"
        case .marathi: "म"
        }
    }
    /// The English name, under the native one.
    var english: String { rawValue.capitalized }
    /// The speech voice used for previews.
    var speechCode: String {
        switch self {
        case .english, .hinglish: "en-IN"
        case .hindi: "hi-IN"
        case .tamil: "ta-IN"
        case .telugu: "te-IN"
        case .kannada: "kn-IN"
        case .bengali: "bn-IN"
        case .marathi: "mr-IN"
        }
    }
}

/// V10: a permission asked on Home, beside the sample call it would have helped with.
enum ContextAsk: Equatable {
    case notifications, contacts
    /// The sample call row it's about.
    var row: String { self == .notifications ? "ctx_rider" : "ctx_unknown" }
    var art: String { self == .notifications ? "PermBell" : "PermContacts" }
    var line: String { self == .notifications ? Catalog.ctxNotifications : Catalog.ctxContacts }
    var cta: String { self == .notifications ? "Turn on notifications" : "Allow contacts" }
}

/// What Home leads with once an onboarding has finished.
enum HomeMode {
    /// The production Home.
    case standard
    /// V7: Equal is off until the setup checklist is done.
    case setupChecklist
    /// V8: “You're live!” with everyday sample calls.
    case liveSamples
    /// V9: “Make me yours” opens on arrival; a card stays if skipped.
    case personalise
    /// V10: notifications and contacts are asked beside the calls they'd have helped with.
    case inContext
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
    /// The app opens on Home; onboardings are started from the profile tab.
    @Published var step: Step = .home
    @Published var variant: Variant = .v1
    /// The version whose onboarding last ran to Home (nil before any has).
    @Published var finished: Variant?
    /// A setup step opened from Home's checklist (V7): finishing it returns to Home.
    @Published var setupTask: Step?
    /// The flow was opened from Home (a setup task), so it rises up over it like a sheet.
    @Published var flowFromHome = false
    /// Setup steps completed from Home's checklist.
    @Published var setupDone: Set<Step> = []
    /// Home's setup hub sheet (V7) is open.
    @Published var hubOpen = false
    /// The step just finished from the hub, to tick off with a flourish.
    @Published var justDone: Step?
    /// V4 / V5 / V9 choices.
    @Published var voice: Voice = .aanya
    /// The languages Equal takes calls in, in the order picked (up to three).
    @Published var callLanguages: [CallLanguage] = [.hindi, .english]
    /// The one language Equal's copy uses: Hinglish when Hindi and English are both picked,
    /// otherwise the first non-English pick. Setting it picks just that language (V9).
    var callLanguage: CallLanguage {
        get {
            if callLanguages.contains(.hindi) && callLanguages.contains(.english) { return .hinglish }
            return callLanguages.first { $0 != .english } ?? .english
        }
        set { callLanguages = [newValue] }
    }
    /// V9: “Make me yours” is done (or skipped, which leaves a card on Home).
    @Published var personalised = false
    @Published var personaliseSkipped = false
    /// V8: the “You're live” card was closed.
    @Published var liveCardDismissed = false
    /// V8: the calls have opened once on arriving Home.
    var liveCallsShown = false
    /// V10: the sample calls added to the chat list, newest first, and the ask in the spotlight.
    @Published var contextRows: [String] = []
    @Published var contextAsk: ContextAsk?
    /// Where each sample call row is on screen (global), for the spotlight.
    @Published var contextFrames: [String: CGRect] = [:]
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
        // Writes the list of recordings to make (see `AudioClips`) into Documents.
        if args.contains("-dumpAudio"), let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? AudioClips.manifest().write(to: docs.appendingPathComponent("audio.json"))
        }
        if let i = args.firstIndex(of: "-startStep"), i + 1 < args.count {
            if let v = args.firstIndex(of: "-variant"), v + 1 < args.count,
               let n = Int(args[v + 1].dropFirst()), let vv = Variant(rawValue: n) { variant = vv; finished = vv }
            let names: [String: Step] = ["phone": .phone, "otp": .otp, "name": .name, "cases": .cases,
                                         "langVoice": .langVoice, "listen": .listen,
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

    /// Where this version goes after the current step.
    func next() {
        // A setup step opened from Home's checklist goes back to Home when it's done.
        if let task = setupTask, task == step { finishSetupTask(done: true); return }
        let route = variant.route
        guard let i = route.firstIndex(of: step), i + 1 < route.count else { return }
        go(route[i + 1])
    }

    func back() {
        let route = variant.route
        guard let i = route.firstIndex(of: step), i > 0 else { return }
        // Name goes back past the code, which fills itself in.
        let prev = route[i - 1] == .otp ? Step.phone : route[i - 1]
        go(prev, direction: -1)
    }

    func skip() {
        if let task = setupTask, task == step { finishSetupTask(done: false); return }
        next()
    }

    /// Progress through this version's screens (number to Welcome), 0…1.
    var progress: CGFloat {
        let route = variant.route.filter { $0 != .home && $0 != .otp }
        guard let i = route.firstIndex(of: step == .otp ? .phone : step) else { return 0 }
        return CGFloat(i + 1) / CGFloat(route.count)
    }

    /// What Home leads with, from the version that last finished.
    var homeMode: HomeMode {
        switch finished {
        case .v7: .setupChecklist
        case .v8: .liveSamples
        case .v9: .personalise
        case .v10: .inContext
        default: .standard
        }
    }

    /// Equal can take calls: always, except V7 before its checklist is done.
    var isLive: Bool { homeMode != .setupChecklist || setupDone.isSuperset(of: [.permq, .fwd, .access]) }

    /// Closes the onboarding (the ✕ on its first screen, or on a setup step from Home).
    func closeFlow() {
        if setupTask != nil { finishSetupTask(done: false); return }
        Haptics.step()
        settleWork?.cancel(); orbInSlot = false; orbSpot = nil
        Language.shared.reset()
        withAnimation(EQ.ease(0.45)) { step = .home }
    }

    // MARK: Asking in context (V10)

    /// Home has opened: a sample call lands in the chat list, then the notifications ask
    /// spotlights it.
    func startContextAsks() {
        guard contextRows.isEmpty else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            await show(.notifications)
        }
    }

    /// Answered (either way): put the spotlight away; after the notifications ask, the contacts
    /// one follows on an unknown caller.
    func answerContextAsk() {
        let was = contextAsk
        withAnimation(.easeInOut(duration: 0.35)) { contextAsk = nil }
        guard was == .notifications else { return }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await show(.contacts)
        }
    }

    private func show(_ ask: ContextAsk) async {
        guard step == .home else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { contextRows.insert(ask.row, at: 0) }
        Haptics.land()
        try? await Task.sleep(for: .seconds(0.9))
        guard step == .home else { return }
        withAnimation(.easeInOut(duration: 0.4)) { contextAsk = ask }
    }

    // MARK: Setup from Home (V6)

    /// Opens one setup step from Home's checklist; it rises over Home like a sheet.
    func startSetup(_ s: Step) {
        Haptics.step()
        setupTask = s
        flowFromHome = true
        settleWork?.cancel(); orbInSlot = false; orbSpot = nil; splashMark = nil
        direction = 1
        arrivingFromSplash = false
        OrbFlight.departing()
        withAnimation(EQ.push(0.6)) { step = s }
    }

    /// Back to Home from a setup step; `done` ticks it off on the checklist.
    private func finishSetupTask(done: Bool) {
        guard let task = setupTask else { return }
        Haptics.step()
        settleWork?.cancel(); orbInSlot = false
        if done { setupDone.insert(task) }
        withAnimation(EQ.push(0.55)) { step = .home }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.orbSpot = nil
            self.setupTask = nil
            self.flowFromHome = false
            if done { self.justDone = task }
            // Back on the hub, unless that was the last one (Home celebrates instead).
            if !self.setupDone.isSuperset(of: [.permq, .fwd, .access]) { self.hubOpen = true }
        }
    }

    func exitToHome() {
        if step != .welcome { Haptics.step() }   // Welcome hands over to the orb's landing instead
        finished = variant
        withAnimation(EQ.ease(0.45)) { step = .home }
    }

    /// Starts a version's onboarding from the splash (the profile tab, or a long-press on the
    /// Home logo to replay the last one).
    func restart(_ v: Variant? = nil) {
        variant = v ?? variant
        instruction = nil; instructionNote = nil; instructionPick = nil
        setupTask = nil; flowFromHome = false; setupDone = []; hubOpen = false; justDone = nil
        voice = .aanya; callLanguages = [.hindi, .english]; personalised = false; personaliseSkipped = false
        liveCardDismissed = false; liveCallsShown = false
        contextRows = []; contextAsk = nil; contextFrames = [:]
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

    /// The screen is moving the orb to a different slot (a new layout on the same screen): the
    /// stage takes it back so it glides there, and bubbles wait for it to land.
    func releaseOrb() {
        settleWork?.cancel()
        OrbFlight.departing()
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { orbInSlot = false }
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
