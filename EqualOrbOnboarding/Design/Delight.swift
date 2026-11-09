import SwiftUI
import AVFoundation

// Shared pieces for the newer onboarding versions (V3–V6): pulse rings, voice
// previews, a breathing waveform, the pick pill and a celebration burst.

// MARK: - Pulse

/// Soft rings spreading out from an avatar while a call is live.
struct PulseRings: View {
    var color: Color
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<2, id: \.self) { i in
                    let p = ((t / 1.8) + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(color.opacity(0.35 * (1 - p)), lineWidth: 2)
                        .scaleEffect(1 + p * 0.6)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Waveform

// MARK: - Voice previews

/// Plays a voice's hello, one at a time and only on tap: the natural recording where there is
/// one (English, Hindi; see `AudioClips`), otherwise the system voices with the pitch and pace
/// set per voice.
@MainActor
final class VoicePreview: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    @Published var speaking: Voice?
    /// The language card playing, when a preview was started from one (not from a voice card).
    @Published var cardLanguage: CallLanguage?
    /// How far through the hello it is, 0…1, for the little waveform.
    @Published var progress: Double = 0
    /// How much of the line has been said, for the caption under the playing card.
    @Published var spoken = ""
    private let synth = AVSpeechSynthesizer()
    private var line = ""
    private var recording: AVAudioPlayer?

    override init() {
        super.init()
        synth.delegate = self
    }

    func toggle(_ v: Voice, language: CallLanguage, name: String) {
        if speaking == v && cardLanguage == nil { stop(); return }
        play(v, language: language, name: name)
    }

    /// From a language card: that language, in the voice picked below. Tapping the playing card stops it.
    func toggleCard(_ l: CallLanguage, voice: Voice, name: String) {
        if cardLanguage == l && speaking != nil { stop(); return }
        play(voice, language: l, name: name)
        cardLanguage = l
    }

    func play(_ v: Voice, language: CallLanguage, name: String) {
        cardLanguage = nil
        synth.stopSpeaking(at: .immediate)
        recording?.stop(); recording = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        line = Catalog.voiceHello(v, language, name: name)
        if let url = AudioClips.hello(v, language), let p = try? AVAudioPlayer(contentsOf: url) {
            p.delegate = self
            recording = p
            speaking = v
            spoken = line
            progress = 0
            p.play()
            Task {
                while self.recording === p, p.isPlaying {
                    self.progress = p.duration > 0 ? p.currentTime / p.duration : 0
                    try? await Task.sleep(for: .seconds(0.05))
                }
            }
            return
        }
        let u = AVSpeechUtterance(string: line)
        u.voice = AVSpeechSynthesisVoice(language: language.speechCode) ?? AVSpeechSynthesisVoice(language: "en-IN")
        u.pitchMultiplier = v.pitch
        u.rate = v.rate
        speaking = v
        spoken = ""
        progress = 0
        synth.speak(u)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        recording?.stop(); recording = nil
        speaking = nil
        cardLanguage = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard p === self.recording else { return }
            self.recording = nil
            self.speaking = nil
            self.cardLanguage = nil
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString r: NSRange, utterance: AVSpeechUtterance) {
        let text = utterance.speechString
        Task { @MainActor in
            guard let range = Range(r, in: text) else { return }
            self.spoken = String(text[..<range.upperBound])
            self.progress = Double(r.location + r.length) / Double(max(1, (text as NSString).length))
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let text = utterance.speechString
        Task { @MainActor in
            guard text == self.line else { return }
            self.spoken = text
            self.speaking = nil
            self.cardLanguage = nil
        }
    }
}

/// The green tick on a chosen card or pill.
struct CheckBadge: View {
    var on: Bool
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 9.5, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(Circle().fill(EQ.green))
            .overlay(Circle().stroke(EQ.page, lineWidth: 2))
            .scaleEffect(on ? 1 : 0.4)
            .opacity(on ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: on)
            .accessibilityHidden(true)
    }
}

// MARK: - Pick pill

/// One job on a picks grid, drawn like V1's pills: white glass, green when picked, a tick
/// popping in the corner. `index` staggers its arrival when `revealed` turns on.
struct PickPill: View {
    let useCase: UseCase
    let on: Bool
    var index = 0
    var revealed = true
    /// Shows a small play glyph, for grids where tapping also plays the sample.
    var playable = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(useCase.emoji).font(.system(size: 18))
                Text(useCase.label)
                    .font(.dm(14.5, .medium))
                    .tracking(-0.22)
                    .foregroundStyle(on ? EQ.greenText : EQ.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? EQ.mintAlt : .white.opacity(0.7)))
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).inset(by: -3).fill(EQ.green.opacity(on ? 0.12 : 0)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(on ? EQ.green : EQ.edge, lineWidth: on ? 1.5 : 1))
            .shadow(color: Color(hex: on ? 0x00782D : 0x003214).opacity(on ? 0.12 : 0.06), radius: on ? 7 : 6, y: on ? 6 : 4)
            .overlay(alignment: .topTrailing) { CheckBadge(on: on).offset(x: 4, y: -6) }
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 18)
        .scaleEffect(revealed ? 1 : 0.94)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(min(index, 12)) * 0.1), value: revealed)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityHint(playable ? "Plays a sample call" : "")
    }
}

/// A grid of picks two to a row, widths following their text, as on V1.
struct PickGrid: View {
    let cases: [UseCase]
    let picked: [String]
    var revealed = true
    var playable = false
    var onTap: (UseCase) -> Void

    private var rows: [[UseCase]] {
        stride(from: 0, to: cases.count, by: 2).map { Array(cases[$0..<min($0 + 2, cases.count)]) }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { r in
                BrickRow(weights: rows[r].map { CGFloat($0.label.count * $0.label.count) }) {
                    ForEach(Array(rows[r].enumerated()), id: \.element.id) { j, u in
                        PickPill(useCase: u, on: picked.contains(u.id), index: r * 2 + j, revealed: revealed,
                                 playable: playable) { onTap(u) }
                    }
                }
            }
        }
    }
}

// MARK: - Celebration

/// A one-shot burst of confetti dots and sparkles from the middle of the view, each time
/// `trigger` changes. Reduce Motion skips it.
struct CelebrationBurst: View {
    var trigger: Int
    var spread: CGFloat = 120
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?

    private static let colors: [UInt32] = [0xBAFF29, 0x8CEA35, 0x00B140, 0xFFE25C, 0x5BC8F5, 0xFFC59E]

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { ctx in
            Canvas { c, size in
                guard let start else { return }
                let t = ctx.date.timeIntervalSince(start)
                guard t < 1.2 else { return }
                let e = 1 - pow(1 - min(1, t / 0.9), 3)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<22 {
                    let a = Double(i) / 22 * 2 * .pi + Double(trigger)
                    let dist = spread * (0.55 + 0.45 * abs(sin(Double(i) * 2.3))) * e
                    let p = CGPoint(x: center.x + cos(a) * dist, y: center.y + sin(a) * dist + 30 * t * t)
                    let r: CGFloat = i % 3 == 0 ? 4 : 3
                    var cc = c
                    cc.opacity = max(0, 1 - t / 1.2)
                    cc.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                            with: .color(Color(hex: Self.colors[i % Self.colors.count])))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            start = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { start = nil }
        }
    }
}

// MARK: - Language cards

/// A language as a card: its name (native, with English underneath), and its first letter in
/// its own script as a large, faint watermark tucked into the top-right corner. Picked, it
/// takes the option-card style: mint fill, green border, and the tick overflowing the corner.
struct LanguageCard: View {
    let language: CallLanguage
    let on: Bool
    /// Bumps to shake the card (a fourth pick, refused).
    var refused = 0
    /// Picked cards can be heard: in their language, in the voice picked below.
    var playing = false
    var accent: Color = EQ.green
    var onPlay: (() -> Void)? = nil
    var action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                Spacer(minLength: 0)
                Text(language.name)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(on ? EQ.greenText : EQ.ink)
                if language != .english {
                    Text(language.english)
                        .font(.dm(12.5, .medium))
                        .foregroundStyle(on ? EQ.greenText.opacity(0.7) : EQ.ink.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .frame(height: 76)
            .background {
                // The watermark hangs off the card's own size and is clipped to it.
                shape.fill(on ? EQ.mintAlt : .white.opacity(0.75))
                    .overlay(alignment: .topTrailing) {
                        Text(language.initial)
                            .font(.system(size: 70, weight: .bold))
                            .foregroundStyle(on ? EQ.green.opacity(0.11) : EQ.ink.opacity(0.045))
                            .fixedSize()
                            .offset(x: -4, y: -14)
                            .accessibilityHidden(true)
                    }
                    .clipShape(shape)
            }
            .background(shape.inset(by: -3).fill(EQ.green.opacity(on ? 0.12 : 0)))
            .overlay(shape.strokeBorder(on ? EQ.green : EQ.edge, lineWidth: on ? 1.5 : 1))
            .shadow(color: Color(hex: on ? 0x00782D : 0x003214).opacity(on ? 0.12 : 0.06), radius: on ? 7 : 6, y: on ? 6 : 4)
            .overlay(alignment: .topTrailing) { CheckBadge(on: on).offset(x: 4, y: -6) }
            .overlay(alignment: .bottomTrailing) {
                if on, let onPlay {
                    Button(action: onPlay) {
                        // Secondary: a solid green icon in an outlined circle, no fill; pause while playing.
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accent)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(accent, lineWidth: 1.5))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(PressStyle(scale: 0.9))
                    .padding(9)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .accessibilityLabel(playing ? "Stop" : "Hear \(language.english)")
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: on)
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .keyframeAnimator(initialValue: CGFloat(0), trigger: refused) { c, x in c.offset(x: x) } keyframes: { _ in
            CubicKeyframe(-7, duration: 0.06)
            CubicKeyframe(6, duration: 0.08)
            CubicKeyframe(-4, duration: 0.08)
            CubicKeyframe(2, duration: 0.07)
            CubicKeyframe(0, duration: 0.07)
        }
        .accessibilityLabel(language.english)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
