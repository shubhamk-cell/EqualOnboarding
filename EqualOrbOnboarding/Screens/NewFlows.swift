import SwiftUI

// The value screens of the newer versions. Each follows V1's choreography: the orb and its
// bubble arrive alone in the middle, and once the line is showing the content rises in
// underneath and pushes them up.

// MARK: - V4, V5 · Languages first

/// Which languages Equal speaks on calls (up to three; Hindi and English to start), as
/// watermark cards, under a small female / male voice switch. A picked card can be heard, in
/// the voice switched to; the picks carry into the rest of the flow.
struct LangVoiceView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @StateObject private var preview = VoicePreview()
    @State private var showContent = false
    @State private var revealed = false

    private let title = Catalog.langVoiceTitle

    var body: some View {
        VStack(spacing: 0) {
            if !showContent { Spacer(minLength: 0) }
            OrbWithBubble(talk: talk, reserve: title, orbDiameter: showContent ? 88 : 128)
                .padding(.top, 10)
                .padding(.horizontal, 24)
            if showContent {
                // The voice switch sits right under the orb, centred.
                VoiceSwitch(preview: preview)
                    .padding(.top, 16)
                    .reveal(revealed, index: 0)
                LanguagePicker(preview: preview, revealed: revealed)
                    .transition(.opacity.combined(with: .offset(y: 40)))
            } else {
                Spacer(minLength: 0)
            }
            Button("Continue") {
                preview.stop()
                model.next()
            }
            .buttonStyle(PrimaryButtonStyle())
            .opacity(revealed ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: revealed)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .onAppear { talk.intro(title) }
        .onChange(of: talk.typing) { was, isTyping in
            guard was, !isTyping, !showContent else { return }
            Task {
                guard (try? await Task.sleep(for: .seconds(0.45))) != nil else { return }
                withAnimation(OrbFlight.glide) { showContent = true }
                guard (try? await Task.sleep(for: .seconds(0.12))) != nil else { return }
                revealed = true
            }
        }
        .onDisappear { preview.stop() }
    }
}

// MARK: - Language picker (V4, V5, V9)

/// The languages Equal speaks on calls as watermark cards, up to three, with a counter that
/// flags the limit. Picked cards can be heard in the chosen voice. Scrolls when it must.
struct LanguagePicker: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var preview: VoicePreview
    var revealed = true
    /// A fourth pick was refused: the card shakes and the counter flags the limit.
    @State private var refused: [CallLanguage: Int] = [:]
    @State private var limitHit = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("LANGUAGES YOUR CALLERS SPEAK")
                        .font(.dm(12, .semibold))
                        .tracking(0.6)
                        .foregroundStyle(EQ.ink.opacity(0.5))
                    Spacer()
                    Text(limitHit ? "Up to 3" : "\(model.callLanguages.count) of 3")
                        .font(.dm(12, .semibold))
                        .foregroundStyle(limitHit ? Color(hex: 0xC2410C) : EQ.greenText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(limitHit ? Color(hex: 0xFFEDD5) : EQ.mintAlt))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: limitHit)
                }
                .reveal(revealed, index: 1)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(CallLanguage.options.enumerated()), id: \.element) { i, l in
                        LanguageCard(language: l, on: model.callLanguages.contains(l), refused: refused[l] ?? 0,
                                     playing: preview.cardLanguage == l && preview.speaking != nil,
                                     progress: preview.progress,
                                     accent: Color(hex: model.voice.accent),
                                     onPlay: {
                                         Haptics.select()
                                         preview.toggleCard(l, voice: model.voice, name: model.displayName)
                                     }) { toggle(l) }
                            .reveal(revealed, index: 2 + i)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 18)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 24)
            }
        }
    }

    private func toggle(_ l: CallLanguage) {
        if let i = model.callLanguages.firstIndex(of: l) {
            // Always keep one.
            guard model.callLanguages.count > 1 else { Haptics.warning(); refused[l, default: 0] += 1; return }
            Haptics.select()
            if preview.cardLanguage == l { preview.stop() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { _ = model.callLanguages.remove(at: i) }
        } else if model.callLanguages.count >= CallLanguage.maxPicked {
            // A fourth: a gentle no.
            Haptics.warning()
            refused[l, default: 0] += 1
            limitHit = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { limitHit = false }
        } else {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { model.callLanguages.append(l) }
        }
    }
}

/// Equal's voice: a compact two-way switch, female or male, each with its own colour. A language
/// card that's playing carries on in the new voice.
struct VoiceSwitch: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var preview: VoicePreview
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Voice.allCases) { v in
                let on = model.voice == v
                let accent = Color(hex: v.accent)
                Button { pick(v) } label: {
                    HStack(spacing: 6) {
                        Text(v == .aanya ? "♀" : "♂")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(on ? .white : accent.opacity(0.7))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(on ? accent : accent.opacity(0.12)))
                        Text(v.gender)
                            .font(.dm(13.5, .semibold))
                            .foregroundStyle(on ? EQ.ink : EQ.ink.opacity(0.5))
                    }
                    .padding(.leading, 5)
                    .padding(.trailing, 12)
                    .frame(height: 34)
                    .background {
                        if on {
                            Capsule().fill(.white)
                                .shadow(color: accent.opacity(0.25), radius: 6, y: 3)
                                .matchedGeometryEffect(id: "voice", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(PressStyle(scale: 0.95))
                .accessibilityLabel("\(v.gender) voice")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(EQ.ink.opacity(0.05)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1))
    }

    private func pick(_ v: Voice) {
        guard model.voice != v else { return }
        Haptics.select()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { model.voice = v }
        if let l = preview.cardLanguage, preview.speaking != nil { preview.toggleCard(l, voice: v, name: model.displayName) }
    }
}

extension View {
    /// Cascades content in, one item after another, when `on` turns true (V1's rhythm).
    func reveal(_ on: Bool, index: Int) -> some View {
        opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 18)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1), value: on)
    }
}
