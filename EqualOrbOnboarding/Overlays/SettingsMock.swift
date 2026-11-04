import SwiftUI

/// A look-alike of iPhone Settings (apps can't deep-link into Phone settings), with a floating
/// checklist at the bottom: Apps → Phone, turn Live Voicemail off, Screen Unknown Callers → Never,
/// then “Return to Equal AI”. Steps strike through as they're done; the return row pulses at the end.
struct SettingsMock: View {
    @EnvironmentObject var model: AppModel
    @State private var path: [Page] = []
    @State private var shown = false

    enum Page: Hashable { case apps, phone, screenUnknown }

    private var step1: Bool { !path.isEmpty }
    private var step2: Bool { !model.liveVoicemailOn }
    private var step3: Bool { model.screenUnknown == "Never" }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    row("gearshape.fill", .gray, "General")
                    row("accessibility", .blue, "Accessibility")
                    row("hand.raised.fill", .indigo, "Privacy & Security")
                }
                Section {
                    NavigationLink(value: Page.apps) { icon("square.grid.2x2.fill", .purple, "Apps") }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .apps: apps
                case .phone: phone
                case .screenUnknown: screenUnknown
                }
            }
        }
        .safeAreaInset(edge: .bottom) { banner }
        .environment(\.colorScheme, .light)
        .opacity(shown ? 1 : 0)
        .onChange(of: path) { _, p in model.settingsVisitedApps = !p.isEmpty }
        .onAppear { withAnimation(.easeOut(duration: 0.25)) { shown = true } }
    }

    // MARK: Pages

    private var apps: some View {
        List {
            Section {
                row("message.fill", .green, "Messages")
                NavigationLink(value: Page.phone) { icon("phone.fill", .green, "Phone") }
                row("camera.fill", .gray, "Camera")
            }
        }
        .navigationTitle("Apps")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var phone: some View {
        List {
            Section {
                row(nil, .clear, "Calls on Other Devices")
                // The whole row flips the switch, like the prototype's mock.
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { model.liveVoicemailOn.toggle() }
                } label: {
                    HStack {
                        Text("Live Voicemail").foregroundStyle(Color(.label))
                        Spacer()
                        SettingsSwitch(on: model.liveVoicemailOn)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: model.liveVoicemailOn)
                .accessibilityValue(model.liveVoicemailOn ? "On" : "Off")
            } footer: {
                Text("View a transcript of an incoming voicemail and answer the call before it ends.")
            }
            Section {
                NavigationLink(value: Page.screenUnknown) {
                    LabeledContent("Screen Unknown Callers", value: model.screenUnknown)
                }
                HStack {
                    Text("Silence Junk Callers")
                    Spacer()
                    SettingsSwitch(on: false)
                }
            }
        }
        .navigationTitle("Phone")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var screenUnknown: some View {
        List {
            Section {
                ForEach(["Never", "Ask Reason for Calling", "Silence"], id: \.self) { option in
                    Button {
                        model.screenUnknown = option
                    } label: {
                        HStack {
                            Text(option).foregroundStyle(Color(.label))
                            Spacer()
                            if model.screenUnknown == option {
                                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Calls from unsaved numbers will ring, and missed calls will be displayed on the Recents list.")
            }
        }
        .navigationTitle("Screen Unknown Callers")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func icon(_ symbol: String, _ color: Color, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
            Text(title)
        }
    }

    /// Inert row (it's only a mock) drawn with a chevron like the real thing.
    private func row(_ symbol: String?, _ color: Color, _ title: String) -> some View {
        HStack {
            if let symbol { icon(symbol, color, title) } else { Text(title) }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(.tertiaryLabel))
        }
    }

    // MARK: Checklist

    private var banner: some View {
        let all = step2 && step3
        return VStack(alignment: .leading, spacing: 10) {
            check(step1) {
                Image(systemName: "phone.fill").font(.system(size: 13)).foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(hex: 0x34C759)))
            } text: { Text("Go to ") + Text("Apps → Phone").bold() }
            check(step2) {
                MiniToggle(on: model.liveVoicemailOn).frame(width: 28, height: 28)
            } text: { Text("Turn ") + Text("OFF").bold().foregroundStyle(Color(hex: 0xFF3B30)) + Text(" Live Voicemail") }
            check(step3) {
                Color.clear.frame(width: 28, height: 28)
            } text: { Text("Set ") + Text("Screen Unknown Callers").bold() + Text(" to ") + Text("Never").bold().foregroundStyle(Color(hex: 0xFF3B30)) }
            Button {
                withAnimation(.easeOut(duration: 0.25)) { shown = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { model.resolve("closed") }
            } label: {
                HStack(spacing: 12) {
                    Image("EqualAvatar").resizable().frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    (Text("Return to ") + Text("Equal AI").bold() + Text(" app"))
                        .foregroundStyle(.black)
                    Spacer()
                }
                .padding(.horizontal, 6)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(all ? EQ.mint : .clear))
                .modifier(Pulse(active: all))
            }
            .buttonStyle(PressStyle())
            .padding(.horizontal, -6)
        }
        .font(.system(size: 15))
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white)
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.black.opacity(0.06), lineWidth: 0.5)))
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 0.2), value: [step1, step2, step3])
    }

    private func check<I: View>(_ done: Bool, @ViewBuilder icon: () -> I, text: () -> Text) -> some View {
        HStack(spacing: 12) {
            icon()
            text()
                .strikethrough(done, color: Color(hex: 0x34C759))
                .foregroundStyle(.black)
        }
        .opacity(done ? 0.45 : 1)
    }
}

/// iOS-style switch (51 × 31) for the mock Settings rows.
private struct SettingsSwitch: View {
    var on: Bool
    var body: some View {
        Capsule()
            .fill(on ? Color(hex: 0x34C759) : Color(hex: 0xE9E9EA))
            .frame(width: 51, height: 31)
            .overlay(alignment: on ? .trailing : .leading) {
                Capsule().fill(.white).frame(width: 27, height: 27).padding(2)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 3)
            }
    }
}

private struct MiniToggle: View {
    var on: Bool
    var body: some View {
        Capsule()
            .fill(on ? Color(hex: 0x34C759) : Color(hex: 0xE9E9EA))
            .frame(width: 28, height: 17)
            .overlay(alignment: on ? .trailing : .leading) {
                Circle().fill(.white).frame(width: 14, height: 14).padding(1.5)
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
            }
            .animation(.easeInOut(duration: 0.2), value: on)
    }
}

private struct Pulse: ViewModifier {
    var active: Bool
    @State private var phase = false
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(EQ.green.opacity(active ? (phase ? 0 : 0.25) : 0), lineWidth: phase ? 12 : 0)
            )
            .onChange(of: active, initial: true) { _, on in
                guard on else { phase = false; return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) { phase = true }
            }
    }
}
