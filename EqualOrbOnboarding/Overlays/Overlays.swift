import SwiftUI
import UIKit

/// Draws whichever modal surface the model is presenting. Each one animates itself in and,
/// when closed, animates out before handing its result back to the flow.
struct OverlayHost: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            switch model.overlay {
            case .consent: ConsentDialog()
            case .decline(let p): DeclineSheet(kind: p)
            case .ussd: CarrierReply()
            case .settings: SettingsMock()
            case .permissionSheet: SetupSheet()
            case nil: EmptyView()
            }
        }
        .transition(.identity)
    }
}

/// Shared in/out choreography for overlays.
private struct OverlayPresence {
    @Binding var shown: Bool
    var model: AppModel
    func close(_ result: String, after delay: Double = 0.32) {
        withAnimation(EQ.push(0.36)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { model.resolve(result) }
    }
}

// MARK: - Call-data consent

struct ConsentDialog: View {
    @EnvironmentObject var model: AppModel
    @State private var shown = false

    var body: some View {
        let presence = OverlayPresence(shown: $shown, model: model)
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.35))
                .background(Color(hex: 0x0A140C).opacity(0.32))
                .ignoresSafeArea()
                .opacity(shown ? 1 : 0)
            VStack(alignment: .leading, spacing: 0) {
                Text("Allow Equal to process your call data?")
                    .font(.dm(21, .bold)).tracking(-0.42)
                    .foregroundStyle(EQ.ink)
                    .padding(.bottom, 14)
                Text("To identify callers, detect spam, and respond on your behalf, Equal shares limited call data — including caller ID, audio transcripts, and contact context — with our AI partners.")
                    .font(.dm(14.5)).lineSpacing(2).foregroundStyle(Color(hex: 0x2B2B2B))
                    .padding(.bottom, 14)
                Text("Your data is used only to power your assistant. It is never sold or used for advertising.")
                    .font(.dm(14.5)).lineSpacing(2).foregroundStyle(Color(hex: 0x2B2B2B))
                HStack(spacing: 10) {
                    Button { presence.close("deny") } label: {
                        Text("Don’t allow").font(.dm(16, .semibold)).foregroundStyle(Color(hex: 0x111111))
                            .frame(maxWidth: .infinity, minHeight: 50).background(Capsule().fill(Color(hex: 0xE3E3E3)))
                    }
                    Button { presence.close("allow") } label: {
                        Text("Allow").font(.dm(16, .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50).background(Capsule().fill(EQ.green))
                    }
                }
                .buttonStyle(PressStyle())
                .padding(.top, 20)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(EdgeInsets(top: 26, leading: 20, bottom: 20, trailing: 20))
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white))
            .shadow(color: .black.opacity(0.28), radius: 30, y: 24)
            .padding(.horizontal, 22)
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.96)
            .offset(y: shown ? 0 : 20)
        }
        .onAppear { withAnimation(.timingCurve(0.32, 1.2, 0.5, 1, duration: 0.38)) { shown = true } }
    }
}

// MARK: - Permission declined

struct DeclineSheet: View {
    @EnvironmentObject var model: AppModel
    var kind: Permission
    @State private var shown = false

    private var notif: Bool { kind == .notifications }

    var body: some View {
        let presence = OverlayPresence(shown: $shown, model: model)
        ZStack(alignment: .bottom) {
            Color.black.opacity(shown ? 0.38 : 0)
                .ignoresSafeArea()
                .onTapGesture { presence.close("dismiss", after: 0.38) }
            VStack(spacing: 0) {
                Text(notif ? "🔔" : "📒")
                    .font(.system(size: 76))
                    .frame(height: 96)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 8)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                Text(notif ? "Notification permission required" : "Contact permission required")
                    .font(.dm(22, .bold)).tracking(-0.44)
                    .foregroundStyle(EQ.ink)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                Text(notif ? "Allow Equal AI to send you notifications to avoid missing important updates"
                           : "Allow Equal AI to access your contacts so I can recognise the people you know when they call")
                    .font(.dm(16)).lineSpacing(4)
                    .foregroundStyle(EQ.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .padding(.bottom, 24)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    model.show(toast: "Allowed in Settings")
                    presence.close("settings", after: 0.38)
                } label: {
                    Label("Open settings", systemImage: "gearshape")
                        .font(.dm(17, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Capsule().fill(EQ.green))
                        .shadow(color: EQ.green.opacity(0.28), radius: 10, y: 8)
                }
                .buttonStyle(PressStyle())
                Button { presence.close("skip", after: 0.38) } label: {
                    Text("Continue anyway").font(.dm(16, .semibold)).underline().foregroundStyle(EQ.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                }
                .buttonStyle(PressStyle())
                .padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36, style: .continuous)
                .fill(EQ.page).ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .topTrailing) {
                Button { presence.close("dismiss", after: 0.38) } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(EQ.ink)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(.white).shadow(color: .black.opacity(0.08), radius: 5, y: 2))
                }
                .buttonStyle(PressStyle())
                .padding(22)
                .accessibilityLabel("Close")
            }
            .offset(y: shown ? 0 : 700)
        }
        .onAppear { withAnimation(EQ.push(0.42)) { shown = true } }
    }
}

// MARK: - Carrier reply (USSD)

/// What the carrier shows after dialling the forwarding code: “Calling…”, then the
/// registrations land one by one. Dismiss, or it closes itself after 6 s.
struct CarrierReply: View {
    @EnvironmentObject var model: AppModel
    @State private var shown = false
    @State private var lines = 0
    @State private var ready = false
    @State private var closed = false

    private let kinds = ["Voice", "Data", "Fax", "SMS"]

    var body: some View {
        VStack(spacing: 0) {
            Text("Calling…").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6)).padding(.bottom, 22)
            VStack(spacing: 14) {
                ForEach(kinds.indices, id: \.self) { i in
                    VStack(spacing: 0) {
                        Text("Setting Registration Succeeded").font(.system(size: 14, weight: .bold))
                        Text("\(kinds[i]) Call Forwarding").font(.system(size: 14))
                        Text("Call forwarding").font(.system(size: 14))
                    }
                    .foregroundStyle(i == 0 ? .white : .white.opacity(0.55))
                    .opacity(i < lines ? 1 : 0)
                    .offset(y: i < lines ? 0 : 6)
                    .animation(.easeOut(duration: 0.35), value: lines)
                }
            }
            .multilineTextAlignment(.center)
            Button(action: close) {
                Text("Dismiss").font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 44).frame(height: 44).background(Capsule().fill(.white))
            }
            .buttonStyle(PressStyle())
            .opacity(ready ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: ready)
            .padding(.top, 34)
            Spacer()
        }
        .padding(.top, 52)              // 110 pt from the top of the screen, below the status bar
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .opacity(shown ? 1 : 0)
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.success, trigger: lines == kinds.count)
        .task {
            withAnimation(.easeOut(duration: 0.25)) { shown = true }
            try? await Task.sleep(for: .seconds(0.7))
            ready = true
            for i in 0..<kinds.count {
                lines = i + 1
                try? await Task.sleep(for: .seconds(0.26))
            }
            try? await Task.sleep(for: .seconds(6 - 0.7 - 0.26 * Double(kinds.count)))
            close()
        }
    }

    private func close() {
        guard !closed else { return }
        closed = true
        withAnimation(.easeOut(duration: 0.2)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { model.resolve("done") }
    }
}

// MARK: - Home: finish setup

struct SetupSheet: View {
    @EnvironmentObject var model: AppModel
    @State private var shown = false

    var body: some View {
        let presence = OverlayPresence(shown: $shown, model: model)
        ZStack(alignment: .bottom) {
            Color.black.opacity(shown ? 0.25 : 0)
                .ignoresSafeArea()
                .onTapGesture { presence.close("dismiss") }
            VStack(spacing: 0) {
                Text("📞").font(.system(size: 64)).shadow(color: .black.opacity(0.18), radius: 6, y: 8)
                    .padding(.top, 16).padding(.bottom, 14)
                Text("Live Voicemail required").font(.dm(20, .semibold)).tracking(-0.4)
                Text("Lets Equal AI pick up the calls you miss")
                    .font(.dm(14)).foregroundStyle(EQ.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: 280).padding(.top, 6).padding(.bottom, 18)
                Button { presence.close("settings") } label: {
                    Label("Open settings", systemImage: "gearshape")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(EQ.page).ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .topTrailing) {
                Button { presence.close("dismiss") } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(EQ.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white).shadow(color: .black.opacity(0.18), radius: 2))
                }
                .buttonStyle(PressStyle())
                .padding(16)
                .accessibilityLabel("Close")
            }
            .offset(y: shown ? 0 : 40)
            .opacity(shown ? 1 : 0)
        }
        .onAppear { withAnimation(EQ.ease(0.32)) { shown = true } }
    }
}
