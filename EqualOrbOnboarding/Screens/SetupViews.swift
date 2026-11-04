import SwiftUI
import UIKit
import UserNotifications
import Contacts
import Lottie

// MARK: - Permissions

/// The orb explains each permission in its bubble, then the real iOS prompt opens.
/// A refusal brings up Equal's own sheet. Afterwards Equal asks for call-data consent (once).
struct PermissionsView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()

    private var reserve: String {
        Catalog.notifLine.count > Catalog.contactsLine.count ? Catalog.notifLine : Catalog.contactsLine
    }

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
            OrbBesideBubble(talk: talk, reserve: reserve, rings: true, fontSize: 18, lineHeight: 24,
                            padH: 18, padV: 14, radius: 20, playful: Catalog.playful(.permq))
                .padding(.horizontal, 24)
            Spacer(minLength: 0)
            Color.clear.frame(height: 110)   // the footer is hidden here but keeps its room
        }
        .task { await run() }
    }

    private func run() async {
        talk.full = Catalog.notifLine
        talk.text = ""
        talk.popID += 1
        guard (try? await Task.sleep(for: .seconds(0.45))) != nil else { return }
        await talk.type(Catalog.notifLine, speed: 0.022)
        guard (try? await Task.sleep(for: .seconds(0.5))) != nil else { return }

        var ok = await requestNotifications()
        if !ok, !Task.isCancelled {
            ok = await model.present(.decline(.notifications)) == "settings"
        }
        model.perms[0] = ok
        guard !Task.isCancelled, (try? await Task.sleep(for: .seconds(0.25))) != nil else { return }

        await talk.replace(with: Catalog.contactsLine)
        guard (try? await Task.sleep(for: .seconds(0.5))) != nil else { return }
        ok = await requestContacts()
        if !ok, !Task.isCancelled {
            ok = await model.present(.decline(.contacts)) == "settings"
        }
        model.perms[1] = ok
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

/// One MMI code sends rejected, missed and unreachable calls to Equal. iOS won't let an app
/// dial `*`/`#` codes, so “Open Phone & dial” plays the confirm + carrier reply the prototype shows.
struct ForwardingView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @State private var copied = false
    @State private var confirmCall = false

    private let title = Catalog.title(.fwd, name: "")
    private let code = Catalog.forwardingCode

    var body: some View {
        SetupLayout(lottie: "forwarding", talk: talk, title: title) {
            HStack(spacing: 8) {
                Text(code)
                    .font(.dm(18, .medium))
                    .monospacedDigit()
                    .tracking(0.18)
                    .foregroundStyle(EQ.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIPasteboard.general.string = code
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { copied = true }
                    model.show(toast: "Code copied")
                } label: {
                    Text(copied ? "Copied" : "Copy")
                        .font(.dm(15, .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Capsule().fill(EQ.green))
                        .contentTransition(.opacity)
                }
                .buttonStyle(PressStyle())
                .sensoryFeedback(.success, trigger: copied)
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .frame(height: 54)
            .glass(Capsule(), tint: 0.62, shadow: false)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 6) {
                BulletRow(text: "Copy the code", done: copied || model.fwdDone)
                BulletRow(text: "Dial it in **Phone**", done: model.fwdDone)
                BulletRow(text: "Come back to Equal", done: model.fwdDone)
            }
        } footer: {
            VStack(spacing: 8) {
                Button(model.fwdDone ? "Continue" : "Open Phone & dial") {
                    if model.fwdDone { model.next() } else { confirmCall = true }
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("This code only sets up call forwarding.")
                    .font(.dm(12))
                    .foregroundStyle(EQ.ink.opacity(0.5))
            }
        }
        .onAppear { talk.intro(title) }
        .alert("Call \(code)?", isPresented: $confirmCall) {
            Button("Cancel", role: .cancel) {}
            Button("Call") { Task { await dial() } }
        }
    }

    private func dial() async {
        _ = await model.present(.ussd)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { model.fwdDone = true }
    }
}

// MARK: - Live Voicemail

/// Two iPhone settings so Equal answers instead of voicemail. “Open Settings” opens a
/// look-alike of iPhone Settings with a floating checklist; the steps tick off live.
struct VoicemailView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()

    private let title = Catalog.title(.access, name: "")

    var body: some View {
        let done = model.accessDone
        SetupLayout(lottie: "voicemail", talk: talk, title: title, fillHero: true) {
            VStack(alignment: .leading, spacing: 6) {
                BulletRow(text: "Open **Settings › Apps › Phone**", done: done || model.settingsVisitedApps)
                BulletRow(text: "Turn **Live Voicemail** off", done: done || !model.liveVoicemailOn)
                BulletRow(text: "Set **Screen Unknown Callers** to Never", done: done || model.screenUnknown == "Never")
            }
        } footer: {
            VStack(spacing: 4) {
                Button(done ? "Continue" : "Open Settings") {
                    if done { model.next() } else { Task { await openSettings() } }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("I’ll do this later") { model.next() }
                    .buttonStyle(LinkButtonStyle())
            }
        }
        .onAppear { talk.intro(title) }
        .sensoryFeedback(.success, trigger: done)
    }

    private func openSettings() async {
        model.resetSettingsMock()
        _ = await model.present(.settings)
        if !model.liveVoicemailOn && model.screenUnknown == "Never" {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { model.accessDone = true }
        } else {
            model.show(toast: "One setting is still on")
        }
    }
}

// MARK: - Shared setup layout

/// Walkthrough on top (looping Lottie), small orb + bubble, the step details, footer at the bottom.
struct SetupLayout<Details: View, Footer: View>: View {
    var lottie: String
    @ObservedObject var talk: Talk
    var title: String
    /// Let the walkthrough grow into all the spare height, so the message and steps sit just above the footer.
    var fillHero = false
    @ViewBuilder var details: Details
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            LottieHero(name: lottie)
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
