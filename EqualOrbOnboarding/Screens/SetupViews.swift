import SwiftUI
import UIKit
import UserNotifications
import Contacts
import Lottie

// MARK: - Permissions

/// The orb explains each permission in its own message (stacked like a chat), then the real
/// iOS prompt opens — both, one after the other. Only then, if either was refused, Equal's own sheet asks once for whatever
/// is missing. Afterwards Equal asks for call-data consent (once).
struct PermissionsView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    /// The second message, about contacts, below the first.
    @StateObject private var talk2 = Talk()
    @State private var secondShown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Image("PermissionArt")
                .resizable()
                .aspectRatio(640 / 872, contentMode: .fit)
                .frame(width: 300)
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 420, alignment: .top)
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.72), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .riseIn(true, delay: 0.2, distance: 18, duration: 0.6)
                .padding(.bottom, 18)
                .accessibilityHidden(true)
            messages
                .padding(.horizontal, 24)
            Spacer(minLength: 0)
            Color.clear.frame(height: 110)   // the footer is hidden here but keeps its room
        }
        .task { await run() }
    }

    /// Orb on the left; the notifications message beside it (tail at the top), the contacts
    /// message under it once it's its turn. Its room is kept from the start so nothing jumps.
    private var messages: some View {
        HStack(alignment: .top, spacing: 18) {
            OrbSlot(diameter: 56) { _ in (secondShown ? talk2 : talk).playful(Catalog.playful(.permq)) }
            VStack(alignment: .leading, spacing: 10) {
                SideBubble(talk: talk, reserve: Catalog.notifLine, fontSize: 18, lineHeight: 24,
                           padH: 18, padV: 14, radius: 20, tail: .topLeft, hug: true)
                    .modifier(OrbHover(diameter: 56))
                SideBubble(talk: talk2, reserve: Catalog.contactsLine, fontSize: 18, lineHeight: 24,
                           padH: 18, padV: 14, radius: 20, tail: .none, hug: true)
                    .modifier(OrbHover(diameter: 56))
                    .opacity(secondShown ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func run() async {
        talk.full = Catalog.notifLine
        talk.text = ""
        talk.popID += 1
        await OrbFlight.untilLanded()
        guard (try? await Task.sleep(for: .seconds(0.45))) != nil else { return }
        await talk.type(Catalog.notifLine, speed: 0.022)
        guard (try? await Task.sleep(for: .seconds(0.5))) != nil else { return }

        let notifications = await requestNotifications()
        guard !Task.isCancelled, (try? await Task.sleep(for: .seconds(0.25))) != nil else { return }

        // The contacts question arrives as a new message under the first.
        talk2.full = Catalog.contactsLine
        talk2.text = ""
        secondShown = true
        talk2.popID += 1
        guard (try? await Task.sleep(for: .seconds(0.45))) != nil else { return }
        await talk2.type(Catalog.contactsLine, speed: 0.022)
        guard (try? await Task.sleep(for: .seconds(0.5))) != nil else { return }
        let contacts = await requestContacts()
        guard !Task.isCancelled else { return }

        let declined = (notifications ? [] : [Permission.notifications]) + (contacts ? [] : [.contacts])
        let fixed = declined.isEmpty ? false : await model.present(.decline(declined)) == "settings"
        model.perms = [notifications || fixed, contacts || fixed]
        guard !Task.isCancelled else { return }

        await model.askConsentOnce()
        guard !Task.isCancelled, model.step == .permq else { return }
        model.next()
    }

    private func requestNotifications() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private func requestContacts() async -> Bool {
        (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
    }
}

// MARK: - Call forwarding

/// One MMI code sends rejected, missed and unreachable calls to Equal. Two ways in:
///
/// - iOS 27+: copy the code, dial it yourself in Phone, come back. Continue stays disabled
///   until you're back and tick “I have activated call forwarding”.
/// - iOS 26 and earlier: a Call button dials the code (the system's call prompt). Once you're
///   back, Continue appears, again waiting for that same confirmation.
///
/// iOS won't tell an app whether forwarding is on, so the user confirms it themselves.
struct ForwardingView: View {
    enum Mode { case copy, call }

    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var talk = Talk()
    /// Copy tapped / call started, and not yet back from Phone.
    @State private var acted = false
    @State private var awayInPhone = false
    /// Back in Equal after dialling: the button settles into its light style and the
    /// confirmation shows.
    @State private var returned = false
    @State private var confirmCall = false

    private let title = Catalog.title(.fwd, name: "")
    private let code = Catalog.forwardingCode
    private let mode = ForwardingView.currentMode

    static var currentMode: Mode {
        #if DEBUG
        // Try either flow on any device: launch with `-fwdMode copy` or `-fwdMode call`.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-fwdMode"), i + 1 < args.count {
            return args[i + 1] == "call" ? .call : .copy
        }
        #endif
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 ? .copy : .call
    }

    var body: some View {
        SetupLayout(lottie: "forwarding", hero: AnyView(ForwardingWalkthrough(mode: mode)), talk: talk, title: title) {
            codeRow
                .padding(.bottom, 12)
            // Plain instructions: they never tick, since Equal can't see what happened in Phone.
            VStack(alignment: .leading, spacing: 6) {
                if mode == .copy {
                    BulletRow(text: "Copy the code", done: false)
                    BulletRow(text: "Dial it in **Phone**", done: false)
                } else {
                    BulletRow(text: "Tap **Call** to dial the code", done: false)
                }
                BulletRow(text: "Come back to Equal", done: false)
            }
        } footer: {
            footer
        }
        .onAppear { talk.intro(title) }
        .onChange(of: scenePhase) { _, phase in
            // Dialling a code never fully backgrounds Equal: iOS's call prompt and the carrier's
            // reply sit on top, so Equal only goes inactive. Copying sends you out to Phone.
            let away = mode == .call ? phase != .active : phase == .background
            if away, acted { awayInPhone = true }
            if phase == .active, awayInPhone { cameBack() }
        }
        .alert("Call \(code)?", isPresented: $confirmCall) {
            Button("Cancel", role: .cancel) {}
            Button("Call") { Task { await carrierReply() } }
        }
    }

    // MARK: Code + action button

    private var codeRow: some View {
        HStack(spacing: 8) {
            Text(code)
                .font(.dm(18, .medium))
                .monospacedDigit()
                .tracking(0.18)
                .foregroundStyle(EQ.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: mode == .copy ? copy : call) {
                // Solid green until used (copied, or back from the call); then very light green
                // with green text.
                let light = mode == .copy ? acted || returned : returned
                Text(buttonLabel)
                    .font(.dm(15, .semibold))
                    .foregroundStyle(light ? EQ.greenDeep : .white)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Capsule().fill(light ? EQ.mint : EQ.green))
                    .overlay(Capsule().strokeBorder(EQ.green.opacity(light ? 0.25 : 0), lineWidth: 1))
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: light)
            }
            .buttonStyle(PressStyle())
            .sensoryFeedback(.success, trigger: acted)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(height: 54)
        .glass(Capsule(), tint: 0.62, shadow: false)
    }

    private var buttonLabel: String {
        switch mode {
        case .copy: acted && !returned ? "Copied" : "Copy"
        case .call: "Call"
        }
    }

    private func copy() {
        UIPasteboard.general.string = code
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { acted = true }
    }

    /// Dials through the system's call prompt. If iOS refuses to dial a */# code from an app,
    /// Equal shows the same prompt and the carrier's reply itself.
    private func call() {
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? code
        guard let url = URL(string: "tel:\(encoded)") else { confirmCall = true; return }
        acted = true
        UIApplication.shared.open(url) { opened in
            if !opened { acted = false; confirmCall = true }
        }
    }

    private func carrierReply() async {
        acted = true
        _ = await model.present(.ussd)
        cameBack()
    }

    private func cameBack() {
        awayInPhone = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            acted = false
            returned = true
        }
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        // Copy flow: Continue is always there (disabled until confirmed).
        // Call flow: nothing until the user is back from the call.
        if mode == .copy || returned {
            VStack(spacing: 12) {
                if returned { confirmation.transition(.move(edge: .bottom).combined(with: .opacity)) }
                Button("Continue") { model.next() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!model.fwdDone)
            }
            .transition(.opacity.combined(with: .offset(y: 16)))
        } else {
            Text("This code only sets up call forwarding.")
                .font(.dm(12))
                .foregroundStyle(EQ.ink.opacity(0.5))
                .frame(height: 60)
        }
    }

    private var confirmation: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { model.fwdDone.toggle() }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(EQ.ink.opacity(model.fwdDone ? 0 : 0.3), lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(model.fwdDone ? EQ.green : .white.opacity(0.7)))
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(model.fwdDone ? 1 : 0.3)
                        .opacity(model.fwdDone ? 1 : 0)
                }
                .frame(width: 24, height: 24)
                Text("I have activated call forwarding")
                    .font(.dm(16, .medium))
                    .foregroundStyle(EQ.ink)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .sensoryFeedback(.selection, trigger: model.fwdDone)
        .accessibilityAddTraits(model.fwdDone ? .isSelected : [])
    }
}

// MARK: - Live Voicemail

/// Two iPhone settings so Equal answers instead of voicemail. “Open Settings” opens the real
/// iPhone Settings with a walkthrough floating in Picture in Picture; coming back turns the
/// button into Continue.
struct VoicemailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var talk = Talk()
    @StateObject private var guide = SettingsGuide()
    @State private var leftForSettings = false

    private let title = Catalog.title(.access, name: "")

    var body: some View {
        let done = model.accessDone
        SetupLayout(lottie: "voicemail", talk: talk, title: title, fillHero: true) {
            VStack(alignment: .leading, spacing: 6) {
                // Plain instructions: they never tick, since Equal can't read these settings.
                BulletRow(text: "In Settings, tap **‹ Apps**, then **Phone**", done: false)
                BulletRow(text: "Turn **Live Voicemail** off", done: false)
                BulletRow(text: "Set **Screen Unknown Callers** to Never", done: false)
            }
        } footer: {
            VStack(spacing: 4) {
                Button(done ? "Continue" : "Open Settings") {
                    if done { model.next() } else { Task { await openSettings() } }
                }
                .buttonStyle(PrimaryButtonStyle())
                .background { SettingsGuideAnchor(guide: guide).frame(width: 36, height: 48) }   // hidden behind the button
                // Back from Settings: a way to go round again, with the walkthrough.
                if done {
                    Button { Task { await openSettings() } } label: {
                        Text("Go to settings")
                            .font(.dm(16, .semibold))
                            .underline()
                            .foregroundStyle(EQ.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(PressStyle())
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
        }
        .onAppear { talk.intro(title) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, guide.active { leftForSettings = true }
            if phase == .active, leftForSettings { cameBack() }
        }
        .onDisappear { guide.finish() }
        .sensoryFeedback(.success, trigger: done)
    }

    private func openSettings() async {
        leftForSettings = false
        await guide.start()
    }

    /// iOS doesn't let apps read these settings, so returning from Settings counts as done.
    private func cameBack() {
        leftForSettings = false
        guide.finish()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { model.accessDone = true }
    }
}

// MARK: - Shared setup layout

/// Walkthrough on top (looping Lottie), small orb + bubble, the step details, footer at the bottom.
struct SetupLayout<Details: View, Footer: View>: View {
    var lottie: String
    /// Drawn walkthrough used instead of the Lottie (call forwarding).
    var hero: AnyView? = nil
    @ObservedObject var talk: Talk
    var title: String
    /// Let the walkthrough grow into all the spare height, so the message and steps sit just above the footer.
    var fillHero = false
    @ViewBuilder var details: Details
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let hero { hero } else { LottieHero(name: lottie) }
            }
                .frame(minHeight: 170, maxHeight: fillHero ? .infinity : 300, alignment: .bottom)
                .layoutPriority(fillHero ? 1 : 0)
                .padding(.top, -12)
            VStack(alignment: .leading, spacing: 0) {
                OrbBesideBubble(talk: talk, reserve: title, playful: Catalog.playful(.fwd))
                    .padding(.bottom, 12)
                    .padding(.top, 20)
                details
                    .padding(.top, 20)
            }
            .padding(.horizontal, 24)
            Spacer(minLength: fillHero ? 36 : 8)
            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }
}

/// Looping walkthrough; rises in once the screen has landed and fades out at the bottom.
struct LottieHero: View {
    let name: String
    @State private var shown = false

    var body: some View {
        LottieView(animation: .named(name))
            .playing(loopMode: .loop)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .shadow(color: Color(hex: 0x00280F).opacity(0.28), radius: 13, y: 14)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 24)
            .scaleEffect(shown ? 1 : 0.96)
            .onAppear { withAnimation(EQ.ease(0.7).delay(0.45)) { shown = true } }
            .accessibilityHidden(true)
    }
}

/// A step in a list: grey dot, or a green tick that pops in once done.
struct BulletRow: View {
    /// `**bold**` runs are set semibold.
    var text: String
    var done: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ZStack {
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(EQ.green))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    Circle()
                        .fill(EQ.ink.opacity(0.45))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 18, height: 18)
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            rich(text, size: 15)
                .foregroundStyle(EQ.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: done)
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "")
    }
}
