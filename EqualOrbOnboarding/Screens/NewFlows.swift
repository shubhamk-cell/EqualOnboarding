import SwiftUI

// The value screens of the newer versions. Each follows V1's choreography: the orb and its
// bubble arrive alone in the middle, and once the line is showing the content rises in
// underneath and pushes them up.

// MARK: - V4, V5 · Languages first

/// Which languages Equal speaks on calls (up to three; Hindi and English to start), as
/// watermark cards scrolling under the orb. A picked card can be heard; the picks carry into
/// the rest of the flow. The orb's question gives the limit, and it says so again on a fourth.
struct LangVoiceView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @StateObject private var preview = VoicePreview()
    @State private var showContent = false
    @State private var revealed = false
    @State private var sayingLimit = false

    private let title = Catalog.langVoiceTitle

    var body: some View {
        VStack(spacing: 0) {
            if !showContent { Spacer(minLength: 0) }
            OrbWithBubble(talk: talk, reserve: title)
                .padding(.top, 10)
                .padding(.horizontal, 24)
            if showContent {
                LanguagePicker(preview: preview, revealed: revealed, onLimit: sayLimit)
                    .transition(.opacity.combined(with: .offset(y: 40)))
            } else {
                Spacer(minLength: 0)
            }
            Button(model.nextCTA) {
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

    /// A fourth pick: the orb explains the limit, then asks its question again.
    private func sayLimit() {
        guard !sayingLimit else { return }
        sayingLimit = true
        Task {
            await talk.replace(with: Catalog.langLimit)
            try? await Task.sleep(for: .seconds(2.6))
            await talk.replace(with: title)
            sayingLimit = false
        }
    }
}

// MARK: - Language picker (V4, V5)

/// The languages Equal speaks on calls as watermark cards, up to three; a fourth shakes and
/// calls `onLimit`. Picked cards can be heard in the chosen voice. Scrolls when it must.
struct LanguagePicker: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var preview: VoicePreview
    var revealed = true
    var onLimit: () -> Void = {}
    /// A fourth pick was refused: the card shakes.
    @State private var refused: [CallLanguage: Int] = [:]

    private var full: Bool { model.callLanguages.count >= CallLanguage.maxPicked }

    /// Two to a row, as on the call picks: small then large, and the other way round on the next.
    private var rows: [[CallLanguage]] {
        let all = CallLanguage.options
        return stride(from: 0, to: all.count, by: 2).map { Array(all[$0..<min($0 + 2, all.count)]) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(rows.indices, id: \.self) { r in
                    BrickRow(weights: r.isMultiple(of: 2) ? [2, 3] : [3, 2], spacing: 12, height: 76) {
                        ForEach(Array(rows[r].enumerated()), id: \.element) { j, l in
                            LanguageCard(language: l, on: model.callLanguages.contains(l), refused: refused[l] ?? 0,
                                         playing: preview.cardLanguage == l && preview.speaking != nil,
                                         onPlay: {
                                             Haptics.select()
                                             preview.toggleCard(l, voice: model.voice, name: model.displayName)
                                         }) { toggle(l) }
                                // Three picked: the rest step back (still tappable, to explain the limit).
                                .opacity(full && !model.callLanguages.contains(l) ? 0.45 : 1)
                                .animation(.easeOut(duration: 0.25), value: full)
                                .reveal(revealed, index: 1 + r * 2 + j)
                        }
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
            onLimit()
        } else {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { model.callLanguages.append(l) }
        }
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
