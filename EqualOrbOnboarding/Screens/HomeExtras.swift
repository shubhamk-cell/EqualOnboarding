import SwiftUI
import UserNotifications
import Contacts

// What Home leads with after the newer versions, and the profile tab's version picker.

/// The soft mint wash behind Equal's own sheets.
let sheetWash = LinearGradient(colors: [Color(hex: 0xE9F6E6), Color(hex: 0xF6F9F2)], startPoint: .top, endPoint: .center)

// MARK: - Status

/// Whether Equal is taking calls: a green “Live” with a breathing dot, or a muted “Off”.
struct StatusPill: View {
    var live: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if live && !reduceMotion {
                    TimelineView(.animation) { ctx in
                        let p = (ctx.date.timeIntervalSinceReferenceDate / 1.6).truncatingRemainder(dividingBy: 1)
                        Circle().fill(DS.primary.opacity(0.4 * (1 - p))).scaleEffect(1 + p * 1.4)
                    }
                }
                Circle().fill(live ? DS.primary : Color(hex: 0xE06500))
            }
            .frame(width: 8, height: 8)
            Text(live ? "Live" : "Off")
                .font(.dm(14, .semibold))
                .foregroundStyle(live ? EQ.greenText : Color(hex: 0xB45309))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(live ? EQ.mintAlt : Color(hex: 0xFFF1E6)))
        .overlay(Capsule().strokeBorder(live ? DS.primary.opacity(0.35) : Color(hex: 0xE06500).opacity(0.35), lineWidth: 1))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: live)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(live ? "Equal is live" : "Equal is off")
    }
}

// MARK: - V6 · Setup checklist

/// The three setup steps, as they appear on Home's checklist and hub.
struct SetupItem: Identifiable {
    let step: Step
    let emoji: String
    let title: String
    let detail: String
    let time: String
    var id: Step { step }

    static let all: [SetupItem] = [
        SetupItem(step: .permq, emoji: "🔔", title: "Call summaries & names",
                  detail: "Notifications and contacts.", time: "10 sec"),
        SetupItem(step: .fwd, emoji: "📲", title: "Send missed calls to me",
                  detail: "One code with your carrier. Needed to go live.", time: "30 sec"),
        SetupItem(step: .access, emoji: "🎙️", title: "Answer instead of voicemail",
                  detail: "Two switches in iPhone Settings.", time: "20 sec"),
    ]
}

/// “Finish setup” on Home: a ring that fills as steps are done, the three steps with ticks,
/// and a big button into the hub.
struct SetupChecklistCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let done = SetupItem.all.filter { model.setupDone.contains($0.step) }.count
        Button { Haptics.step(); model.hubOpen = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ProgressRing(value: CGFloat(done) / 3, label: "\(done)/3")
                        .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(done == 0 ? "Finish setup to go live" : "\(3 - done) more to go live")
                            .font(.ds(18, .bold))
                            .foregroundStyle(DS.onBackground)
                        Text("I can’t take calls yet. About a minute.")
                            .font(.ds(14))
                            .foregroundStyle(DS.meta)
                    }
                    Spacer(minLength: 0)
                }
                VStack(spacing: 8) {
                    ForEach(SetupItem.all) { item in
                        let on = model.setupDone.contains(item.step)
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().strokeBorder(on ? .clear : DS.meta.opacity(0.35), lineWidth: 1.5)
                                if on {
                                    Circle().fill(DS.primary)
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .frame(width: 20, height: 20)
                            Text(item.title)
                                .font(.ds(15, on ? .regular : .medium))
                                .foregroundStyle(on ? DS.meta : DS.name)
                                .strikethrough(on, color: DS.meta.opacity(0.6))
                            Spacer()
                            if !on { Text(item.time).font(.ds(12.5)).foregroundStyle(DS.meta) }
                        }
                    }
                }
                Text(done == 0 ? "Start setup" : "Continue setup")
                    .font(.ds(16, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Capsule().fill(DS.primary))
                    .shadow(color: Color(hex: 0x00782D).opacity(0.25), radius: 10, y: 6)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFFDF8), .white], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(hex: 0xE06500).opacity(0.25), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: model.setupDone)
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

/// A ring filling green, with a label in the middle.
struct ProgressRing: View {
    var value: CGFloat
    var label: String
    var body: some View {
        ZStack {
            Circle().stroke(DS.primary.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.001, value))
                .stroke(AngularGradient(colors: [EQ.voiceTop, DS.primary], center: .center), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: value)
            Text(label)
                .font(.dm(14, .bold))
                .foregroundStyle(DS.onBackground)
                .contentTransition(.numericText())
        }
    }
}

/// The setup hub: the orb says what's left, and each step opens full screen. Coming back from
/// one, its tick lands with a burst.
struct SetupHubSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var talk = Talk()
    @State private var burst = 0
    @State private var landed: Step?

    private var left: Int { SetupItem.all.filter { !model.setupDone.contains($0.step) }.count }
    private var line: String {
        switch left {
        case 3: "Three quick steps and I’m live, \(model.displayName)"
        case 2: "Nice! Two more and I’m taking your calls"
        default: "Last one — then I’m live!"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Orb(diameter: 56, interactive: false)
                    .modifier(OrbHover(diameter: 56))
                SideBubble(talk: talk, reserve: line, fontSize: 17, lineHeight: 22, tail: .topLeft, hug: true)
                    .modifier(OrbHover(diameter: 56))
                Spacer(minLength: 0)
            }
            .padding(.top, 34)
            .padding(.bottom, 22)
            VStack(spacing: 10) {
                ForEach(Array(SetupItem.all.enumerated()), id: \.element.id) { i, item in
                    row(item, number: i + 1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        
        .onAppear {
            talk.intro(line, delay: 0.2)
            // Back from a step: tick it off with a flourish.
            if let d = model.justDone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    landed = d
                    burst += 1
                    Haptics.success()
                    model.justDone = nil
                }
            }
        }
    }

    private func row(_ item: SetupItem, number: Int) -> some View {
        let on = model.setupDone.contains(item.step)
        return Button {
            guard !on else { return }
            Haptics.step()
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.startSetup(item.step) }
        } label: {
            HStack(spacing: 14) {
                Text(item.emoji)
                    .font(.system(size: 22))
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(on ? EQ.mintAlt : Color(hex: 0xEEF3EA)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.dm(16.5, .semibold))
                            .foregroundStyle(EQ.ink)
                        if item.step == .fwd && !on {
                            Text("Required")
                                .font(.dm(10.5, .bold))
                                .foregroundStyle(Color(hex: 0xB45309))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(hex: 0xFFF1E6)))
                        }
                    }
                    Text(on ? "Done" : "\(item.detail) · \(item.time)")
                        .font(.dm(13))
                        .foregroundStyle(on ? EQ.greenText : EQ.ink.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                ZStack {
                    if on {
                        Circle().fill(EQ.green)
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    } else {
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(EQ.ink.opacity(0.4))
                    }
                }
                .frame(width: 30, height: 30)
                .scaleEffect(landed == item.step ? 1.0 : 1)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: landed == item.step) { c, s in c.scaleEffect(s) } keyframes: { _ in
                    CubicKeyframe(1.35, duration: 0.18)
                    CubicKeyframe(1, duration: 0.25)
                }
                .overlay { if landed == item.step { CelebrationBurst(trigger: burst, spread: 60) .frame(width: 140, height: 140) } }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.9)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(on ? EQ.green.opacity(0.35) : .white, lineWidth: 1.5))
            .shadow(color: Color(hex: 0x003214).opacity(0.07), radius: 10, y: 6)
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .disabled(on)
    }
}

// MARK: - V7 · Ask in context

/// Home dims, with a spotlight on the sample call that just landed in the chat list; below it
/// the orb asks for what that call would have needed, with its art and the real iOS prompt
/// behind the CTA. Notifications and contacts are asked on the same call, one after the other:
/// the contacts message joins under the first, and the art and CTA change with it.
struct ContextAskOverlay: View {
    let ask: ContextAsk
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    /// The contacts message, under the notifications one.
    @StateObject private var next = Talk()
    @State private var stacked = false
    @State private var shown = false

    var body: some View {
        let hole = (model.contextFrames[ask.row] ?? .zero).insetBy(dx: 8, dy: 2)
        ZStack {
            ZStack(alignment: .topLeading) {
                // The dim, with the row cut out of it.
                Spotlight(hole: hole, radius: 22)
                    .fill(Color.black.opacity(0.72), style: FillStyle(eoFill: true))
                    .contentShape(Rectangle())
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                    .shadow(color: .white.opacity(0.5), radius: 10)
                    .frame(width: hole.width, height: hole.height)
                    .offset(x: hole.minX, y: hole.minY)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            // Deeper at the foot, so the tab bar falls away behind the CTAs.
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.85), location: 0.55)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 240)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // The orb's messages, under the row.
                    HStack(alignment: .top, spacing: 14) {
                        Orb(diameter: 56, interactive: false)
                            .modifier(OrbHover(diameter: 56))
                        VStack(alignment: .leading, spacing: 10) {
                            SideBubble(talk: talk, reserve: ContextAsk.notifications.line, fontSize: 17, lineHeight: 22, tail: .topLeft, hug: true)
                                .fixedSize(horizontal: false, vertical: true)
                            if stacked {
                                SideBubble(talk: next, reserve: ContextAsk.contacts.line, fontSize: 17, lineHeight: 22, tail: .none, hug: true)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .modifier(OrbHover(diameter: 56))
                        Spacer(minLength: 0)
                    }
                    .padding(.top, max(0, hole.maxY + 22 - geo.frame(in: .global).minY))
                    Spacer(minLength: 16)
                    // The art and the CTAs, at the foot of the screen as on the flow screens.
                    if let art = ask.art {
                        Image(art)
                            .resizable()
                            .scaledToFit()
                            .frame(minHeight: 56, maxHeight: 120)
                            .opacity(shown ? 1 : 0)
                            .scaleEffect(shown ? 1 : 0.8)
                            .padding(.bottom, 18)
                            .accessibilityHidden(true)
                    }
                    VStack(spacing: 6) {
                        Button(ask.cta) { Task { await allow() } }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Maybe later") { Haptics.step(); model.answerContextAsk(later: true) }
                            .buttonStyle(LinkButtonStyle(color: .white.opacity(0.85), size: 16, weight: .semibold))
                    }
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 16)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            talk.intro(ContextAsk.notifications.line, delay: 0.2)
            if ask == .contacts { stacked = true; next.intro(ask.line, delay: 0.4) }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.9)) { shown = true }
        }
        .onChange(of: ask) { _, now in
            guard now == .contacts else { return }
            // Same caller, next ask: the old art and CTA step aside, the new message joins below.
            withAnimation(.easeOut(duration: 0.2)) { shown = false }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { stacked = true }
            next.intro(now.line, delay: 0.3)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0)) { shown = true }
        }
    }

    private func allow() async {
        Haptics.step()
        let ok: Bool
        switch ask {
        case .notifications:
            ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .contacts:
            ok = (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
        }
        if ok { Haptics.success() }
        await model.refreshPermissions()
        model.answerContextAsk()
    }
}

/// The whole screen, less a rounded hole (fill even-odd).
private struct Spotlight: Shape {
    var hole: CGRect
    var radius: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path(r.insetBy(dx: -50, dy: -50))
        if hole != .zero { p.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous) }
        return p
    }
}

// MARK: - Profile

/// The profile tab: who you are, and every onboarding version, each with its building blocks.
/// Tapping a version runs it from the splash.
struct ProfileScreen: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 28)
                Text("ONBOARDING VERSIONS")
                    .font(.ds(12, .semibold))
                    .tracking(0.6)
                    .foregroundStyle(DS.meta)
                Text("Tap one to run it from the start. Each ends back here on Home.")
                    .font(.ds(14))
                    .foregroundStyle(DS.meta)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                VStack(spacing: 12) {
                    ForEach(Variant.allCases) { v in
                        VersionRow(variant: v, lastRun: model.finished == v) {
                            Haptics.step()
                            model.restart(v)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 130)
        }
        .background(DS.listBackground.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text(String(model.displayName.prefix(1)))
                .font(.ds(26, .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(LinearGradient(colors: [EQ.voiceTop, DS.primary], startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName).font(.ds(22, .bold)).foregroundStyle(DS.onBackground)
                HStack(spacing: 8) {
                    Text(model.phone.isEmpty ? "+91 98765 43210" : "+91 \(model.phone)")
                        .font(.ds(14)).foregroundStyle(DS.meta)
                    StatusPill(live: model.isLive).scaleEffect(0.85)
                }
            }
        }
    }
}

/// One version: its number, name and what it's about, and its blocks in order as coloured chips.
private struct VersionRow: View {
    let variant: Variant
    let lastRun: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Text(variant.label)
                    .font(.dm(15, .bold))
                    .foregroundStyle(lastRun ? .white : DS.primary)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(lastRun ? AnyShapeStyle(LinearGradient(colors: [EQ.voiceTop, DS.primary], startPoint: .topLeading, endPoint: .bottomTrailing))
                                      : AnyShapeStyle(EQ.mintAlt)))
                VStack(alignment: .leading, spacing: 6) {
                    if variant == .v1 || lastRun {
                        HStack(spacing: 6) {
                            if variant == .v1 { tag("Current", DS.meta) }
                            if lastRun { tag("Last run", DS.primary) }
                        }
                    }
                    Text(variant.name)
                        .font(.ds(16.5, .semibold))
                        .foregroundStyle(DS.name)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(variant.detail)
                        .font(.ds(13.5))
                        .foregroundStyle(DS.meta)
                        .fixedSize(horizontal: false, vertical: true)
                    WrapRows(spacing: 3) {
                        ForEach(Array(variant.blocks.enumerated()), id: \.offset) { i, b in
                            HStack(spacing: 3) {
                                if i > 0 {
                                    Image(systemName: "chevron.right").font(.system(size: 7, weight: .heavy)).foregroundStyle(DS.meta.opacity(0.5))
                                }
                                chip(b)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DS.primary, EQ.mintAlt)
                    .symbolRenderingMode(.palette)
                    .padding(.top, 8)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(lastRun ? DS.primary.opacity(0.4) : .clear, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .accessibilityLabel("\(variant.label), \(variant.name). \(variant.detail)")
        .accessibilityHint("Starts this onboarding")
    }

    private func tag(_ s: String, _ c: Color) -> some View {
        Text(s)
            .font(.ds(10.5, .bold))
            .foregroundStyle(c)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(c.opacity(0.1)))
    }

    private func chip(_ b: Variant.Block) -> some View {
        let color: Color = switch b {
        case .signUp: Color(hex: 0x1F1F1F)
        case .value: Color(hex: 0x16A34A)
        case .setUp: Color(hex: 0x2563EB)
        case .personalise: Color(hex: 0xEA7A1A)
        case .home: Color(hex: 0x8A8A8A)
        }
        return Text(b.title)
            .font(.ds(10.5, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6.5)
            .frame(height: 19)
            .background(Capsule().fill(color))
    }
}
