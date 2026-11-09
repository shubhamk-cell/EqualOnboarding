import SwiftUI

/// V8, after the sample calls: “Now that you’ve seen me in action, how would you like me to
/// sound?” Four voices in a 2×2 grid, two female and two male, each card tinted and marked ♀ / ♂ like the gender cards.
/// Tapping a card picks that voice and plays its hello; the way on appears once one is picked.
struct AssistantView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @StateObject private var preview = VoicePreview()
    @State private var chosen: Voice?
    @State private var showGrid = false
    @State private var revealed = false

    private let title = Catalog.assistantAsk
    /// Female and male voices on the diagonals.
    private let rows: [[Voice]] = [[.aanya, .kabir], [.arjun, .meera]]

    var body: some View {
        VStack(spacing: 0) {
            if !showGrid { Spacer(minLength: 0) }
            OrbWithBubble(talk: talk, reserve: title)
                .padding(.top, 10)
                .padding(.horizontal, 24)

            if showGrid {
                VStack(spacing: 14) {
                    ForEach(rows.indices, id: \.self) { r in
                        HStack(spacing: 14) {
                            ForEach(Array(rows[r].enumerated()), id: \.element) { c, v in
                                card(v).reveal(revealed, index: r * 2 + c)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .transition(.opacity.combined(with: .offset(y: 40)))
                Spacer(minLength: 0)
            } else {
                // As on the picks page: lifted so the orb sits in the middle while it asks.
                Spacer(minLength: 0)
                Color.clear.frame(height: 150)
            }

            Button(model.nextCTA) {
                preview.stop()
                model.next()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(chosen == nil)
            .opacity(revealed ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.4), value: revealed)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .onAppear {
            // Always opens with nothing picked, even coming back: the way on waits for a tap.
            chosen = nil
            model.voiceChosen = false
            talk.intro(title)
        }
        .onChange(of: talk.typing) { was, isTyping in
            guard was, !isTyping, !showGrid else { return }
            Task {
                guard (try? await Task.sleep(for: .seconds(0.35))) != nil else { return }
                withAnimation(OrbFlight.glide) { showGrid = true }
                guard (try? await Task.sleep(for: .seconds(0.12))) != nil else { return }
                revealed = true
            }
        }
        .onDisappear { preview.stop() }
    }

    private func card(_ v: Voice) -> some View {
        let on = chosen == v
        let speaking = preview.speaking == v
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let gender: Gender = v.isFemale ? .female : .male
        return Button { pick(v) } label: {
            // Styled like the gender cards: a pale tint, a soft top sheen and a faint ♀ / ♂ behind.
            ZStack {
                shape.fill(Color(hex: gender.fill))
                // In the lower-right corner, whole enough to read as ♀ (ring and cross) or ♂
                // (ring and arrow), just cut by the edge.
                GenderMark(gender: gender)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: v.isFemale ? 38 : 30, y: v.isFemale ? -32 : 22)
                LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                content(v, on: on, speaking: speaking)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 148)
            .clipShape(shape)
            .background(shape.inset(by: -4).fill(EQ.green.opacity(on ? 0.14 : 0)))
            .overlay(shape.strokeBorder(on ? EQ.green : EQ.edge, lineWidth: on ? 2 : 1))
            .shadow(color: Color(hex: 0x1E2A6B).opacity(on ? 0.12 : 0.07), radius: 10, y: 5)
            .overlay(alignment: .topTrailing) {
                CheckBadge(on: on).offset(x: 6, y: -6)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: on)
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .accessibilityLabel("\(v.name), \(v.gender) voice, \(v.vibe)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func content(_ v: Voice, on: Bool, speaking: Bool) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Spacer(minLength: 0)
                    // Plays its hello: bars while it speaks, a play glyph otherwise.
                    ZStack {
                        Circle().fill(EQ.green.opacity(speaking ? 0.2 : 0.13))
                        if speaking {
                            SpeakingBars().frame(width: 14, height: 12)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(EQ.green)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                Spacer(minLength: 10)
                Text(v.name)
                    .font(.dm(21, .semibold))
                    .foregroundStyle(on ? EQ.greenText : EQ.ink)
                Text(v.vibe)
                    .font(.dm(13))
                    .foregroundStyle(EQ.ink.opacity(0.55))
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func pick(_ v: Voice) {
        Haptics.select()
        withAnimation(.easeInOut(duration: 0.2)) { chosen = v }
        model.voice = v
        model.voiceChosen = true
        preview.toggle(v, language: .english, name: model.addressName)
    }
}

/// Three little bars bouncing while a voice speaks.
private struct SpeakingBars: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(EQ.green)
                        .frame(width: 3, height: 4 + 8 * abs(sin(t * 7 + Double(i) * 1.1)))
                }
            }
        }
    }
}
