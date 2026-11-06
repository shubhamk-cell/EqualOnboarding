import SwiftUI
import AVFoundation

// The call player every version uses for its sample calls: one call per card in a swipeable
// carousel, then a podcast-style player — time, speed, a filling waveform, previous / play /
// next.

// MARK: - Deck

/// Calls in a carousel (neighbours peeking, scaled back, page dots below), and the player for
/// the call in front. Swiping while one plays carries on with the next; a finished call moves
/// the carousel on, ready to play.
/// It fits whatever height it's given, so no page needs to scroll: the cards take what's left
/// once the title and player have their room (up to `art`), and on short screens the player
/// tightens too. Give it a bounded height (e.g. `.frame(maxHeight: .infinity)`).
struct CallDeck: View {
    let calls: [UseCase]
    /// The everyday calls use their longer scripts.
    var everyday = false
    /// The largest the cards grow.
    var art: CGFloat = 196
    /// The call to start on.
    var start: String? = nil
    /// Cascades the parts in when this turns true.
    var revealed = true
    var onFinish: (String) -> Void = { _ in }

    @EnvironmentObject var model: AppModel
    @StateObject private var player = CallPlayer()
    @State private var current: String?
    /// The title and player's height, measured, so the cards get the rest.
    @State private var chrome: CGFloat = 0
    /// A short screen: smaller type and controls.
    @State private var compact = false
    private var index: Int { calls.firstIndex { $0.id == current } ?? 0 }
    private var call: UseCase { calls[min(index, calls.count - 1)] }

    var body: some View {
        GeometryReader { g in
            let size = max(88, min(art, g.size.height - chrome))
            VStack(spacing: 0) {
                carousel(size: size, width: g.size.width).reveal(revealed, index: 0)
                VStack(spacing: 0) {
                    details.reveal(revealed, index: 1)
                    playerPanel.reveal(revealed, index: 2)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chrome = $0 }
            }
            // Sits up under the orb; any spare room goes below the player, not above the card.
            .frame(width: g.size.width, height: g.size.height, alignment: .top)
        }
        .onGeometryChange(for: Bool.self) { $0.size.height < 460 } action: { compact = $0 }
        .onAppear {
            current = start ?? calls.first?.id
            load(play: false)
        }
        .onChange(of: current) { _, id in
            guard let id, id != player.id else { return }
            Haptics.select()
            load(play: player.playing)
        }
        .onChange(of: player.finished) { _, done in
            guard done, let id = player.id else { return }
            Haptics.success()
            onFinish(id)
            if index + 1 < calls.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    guard !player.playing, index + 1 < calls.count else { return }
                    withAnimation(EQ.push(0.55)) { current = calls[index + 1].id }
                }
            }
        }
        .onChange(of: model.voice) { load(play: false) }
        .onDisappear { player.stop() }
    }

    private func load(play: Bool) {
        guard !calls.isEmpty else { return }
        player.load(.make(call, everyday: everyday, voice: model.voice, name: model.displayName), id: call.id)
        if play { player.play() }
    }

    // MARK: Carousel

    private func carousel(size art: CGFloat, width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: compact ? 12 : 16) {
                ForEach(Array(calls.enumerated()), id: \.element.id) { i, u in
                    CallArt(useCase: u, index: i, size: art, live: player.playing && u.id == player.id)
                        .scrollTransition(.interactive, axis: .horizontal) { c, phase in
                            c.scaleEffect(phase.isIdentity ? 1 : 0.84)
                                .opacity(phase.isIdentity ? 1 : 0.55)
                                .rotation3DEffect(.degrees(phase.value * -14), axis: (x: 0, y: 1, z: 0))
                        }
                        .onTapGesture { withAnimation(EQ.push(0.5)) { current = u.id } }
                        .id(u.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $current, anchor: .center)
        // The card in front sits dead centre, its neighbours peeking either side.
        .contentMargins(.horizontal, (width - art) / 2, for: .scrollContent)
        .scrollClipDisabled()
        .scrollDisabled(calls.count < 2)
        .frame(height: art)
    }

    /// The call in front: what Equal did, who called, which of how many.
    private var details: some View {
        VStack(spacing: 4) {
            Text(call.label)
                .font(.dm(compact ? 18 : 21, .bold))
                .foregroundStyle(EQ.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            HStack(spacing: 6) {
                Text(call.caller == "You" ? "A call to you" : call.caller)
                if calls.count > 1 {
                    Text("·")
                    Text("\(index + 1) of \(calls.count)").monospacedDigit()
                }
            }
            .font(.dm(compact ? 13 : 14, .medium))
            .foregroundStyle(EQ.ink.opacity(0.5))
            if calls.count > 1 {
                PageDots(count: calls.count, index: index) { i in withAnimation(EQ.push(0.5)) { current = calls[i].id } }
                    .padding(.top, compact ? 6 : 10)
            }
        }
        .animation(EQ.ease(0.3), value: index)
        .padding(.horizontal, 32)
        .padding(.top, compact ? 14 : 20)
    }

    // MARK: Player

    private var playerPanel: some View {
        VStack(spacing: compact ? 8 : 10) {
            HStack {
                Text(player.timeLabel(player.elapsed)).foregroundStyle(EQ.ink)
                Spacer()
                SpeedChip(player: player)
                Spacer()
                Text(player.timeLabel(player.duration)).foregroundStyle(EQ.ink.opacity(0.45))
            }
            .font(.dm(compact ? 14 : 15, .semibold))
            .monospacedDigit()

            Waveform(progress: player.progress, seed: Double(index) * 2.1, live: player.playing)
                .frame(height: compact ? 34 : 40)
                .accessibilityLabel("Progress")
                .accessibilityValue("\(Int(player.progress * 100)) percent")

            HStack(spacing: 0) {
                skip(back: true)
                Spacer()
                PlayButton(player: player, size: compact ? 60 : 70)
                Spacer()
                skip(back: false)
            }
            .padding(.horizontal, 28)
            .padding(.top, compact ? 2 : 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, compact ? 14 : 22)
        .padding(.bottom, 12)
    }

    /// Previous / next call, in place of the usual 10-second skips.
    private func skip(back: Bool) -> some View {
        let target = index + (back ? -1 : 1)
        let enabled = calls.indices.contains(target)
        return Button {
            guard enabled else { return }
            withAnimation(EQ.push(0.55)) { current = calls[target].id }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: back ? "backward.end.fill" : "forward.end.fill")
                    .font(.system(size: compact ? 19 : 22, weight: .semibold))
                Text(back ? "Previous" : "Next")
                    .font(.dm(compact ? 12.5 : 13.5, .medium))
            }
            .foregroundStyle(EQ.ink.opacity(enabled ? 0.75 : 0.22))
            .frame(width: 76, height: compact ? 48 : 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .disabled(!enabled)
        .opacity(calls.count < 2 ? 0 : 1)
        .accessibilityLabel(back ? "Previous call" : "Next call")
    }
}

// MARK: - Shared pieces

/// Big green play / pause (replay once finished).
private struct PlayButton: View {
    @ObservedObject var player: CallPlayer
    var size: CGFloat

    var body: some View {
        Button {
            Haptics.step()
            player.playing ? player.pause() : player.play()
        } label: {
            Image(systemName: player.playing ? "pause.fill" : player.finished ? "arrow.counterclockwise" : "play.fill")
                .font(.system(size: size * 0.37, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(LinearGradient(colors: [Color(hex: 0x23C063), EQ.green], startPoint: .top, endPoint: .bottom)))
                .shadow(color: Color(hex: 0x00782D).opacity(0.3), radius: size * 0.2, y: size * 0.11)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressStyle(scale: 0.93))
        .accessibilityLabel(player.playing ? "Pause" : "Play call")
    }
}

/// 1x → 1.5x → 2x.
private struct SpeedChip: View {
    @ObservedObject var player: CallPlayer
    var body: some View {
        Button {
            Haptics.select()
            player.cycleSpeed()
        } label: {
            Text(player.speedLabel)
                .font(.dm(14, .bold))
                .foregroundStyle(EQ.ink)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(.white.opacity(0.9)))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                .contentTransition(.numericText())
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .accessibilityLabel("Speed \(player.speedLabel)")
    }
}

/// Carousel dots: the current one stretched into a green pill. Tap one to jump to it.
struct PageDots: View {
    var count: Int
    var index: Int
    var small = false
    var onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: small ? 5 : 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? EQ.green : EQ.ink.opacity(0.15))
                    .frame(width: i == index ? (small ? 16 : 20) : (small ? 6 : 7), height: small ? 6 : 7)
                    .contentShape(Rectangle().inset(by: -6))
                    .onTapGesture { onTap(i) }
            }
        }
        .animation(EQ.ease(0.3), value: index)
        .accessibilityElement()
        .accessibilityLabel("Call \(index + 1) of \(count)")
    }
}

// MARK: - Card art

/// A call's cover: a soft gradient tile with its emoji large in the middle, and gentle rings
/// while it plays.
struct CallArt: View {
    let useCase: UseCase
    let index: Int
    var size: CGFloat = 196
    let live: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Apricot, rose, lavender, mint, sky, butter: in turn along a deck.
    private static let washes: [[UInt32]] = [
        [0xFFD8BC, 0xFFB98F], [0xFFD3DA, 0xF59AAE], [0xDCD4FF, 0xAFA2F5],
        [0xC8F0D2, 0x7FD39A], [0xCFE6FF, 0x8DBDF5], [0xFFF0B8, 0xF5CF5C],
    ]

    var body: some View {
        let wash = Self.washes[index % Self.washes.count]
        let shape = RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: wash.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
            // A soft highlight, like light on a glossy tile.
            Circle()
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.6, height: size * 0.6)
                .blur(radius: size * 0.17)
                .offset(x: -size * 0.25, y: -size * 0.3)
            if live && !reduceMotion {
                PulseRings(color: .white)
                    .frame(width: size * 0.56, height: size * 0.56)
            }
            Text(useCase.emoji)
                .font(.system(size: size * 0.33))
                .shadow(color: .black.opacity(0.12), radius: size * 0.04, y: size * 0.03)
                .scaleEffect(live ? 1.06 : 1)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: live)
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.6), lineWidth: size > 100 ? 1.5 : 1))
        .shadow(color: Color(hex: wash[1]).opacity(0.45), radius: size * 0.09, y: size * 0.06)
        .accessibilityElement()
        .accessibilityLabel("\(useCase.label), \(useCase.caller)")
    }
}

// MARK: - Waveform

/// A long voice-note waveform, like a recording's: the bars stay still and turn green from the
/// left as the call plays.
struct Waveform: View {
    var progress: Double
    var seed: Double
    var live: Bool
    var count = 46
    var tint: Color = EQ.green
    var spacing: CGFloat = 3

    var body: some View {
        GeometryReader { g in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<count, id: \.self) { j in
                    let base = 0.22 + 0.78 * abs(sin(Double(j) * 1.37 + seed) * cos(Double(j) * 0.41 + seed * 0.5))
                    Capsule()
                        .fill(Double(j) / Double(count) < progress ? tint : EQ.ink.opacity(0.12))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(4, g.size.height * base))
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.easeOut(duration: 0.15), value: progress)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Engine

/// Plays one call at a time, line by line: the bundled recording of each line (`AudioClips`),
/// or, where there isn't one, the system voice. Progress and the clock follow the recordings'
/// own lengths. Pausing restarts the current line on resume.
@MainActor
final class CallPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    struct Script {
        var lines: [(speaker: String, line: String)]
        /// A recording per line, where there is one.
        var audio: [URL?]
        var voice: Voice

        /// A sample call in `voice`: the everyday calls use their longer scripts.
        static func make(_ u: UseCase, everyday: Bool, voice: Voice, name: String) -> Script {
            let lines = everyday ? Catalog.liveScript(u, name: name) : Catalog.script(u, name: name)
            let audio = lines.enumerated().map { i, l in
                AudioClips.url(call: u.id, line: i, equal: l.speaker == "Equal AI", voice: voice)
            }
            return Script(lines: lines, audio: audio, voice: voice)
        }
    }

    @Published private(set) var id: String?
    @Published private(set) var playing = false
    @Published private(set) var finished = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var lineIndex = 0
    @Published private(set) var speed: Double = 1

    private var script = Script(lines: [], audio: [], voice: .aanya)
    /// Each line's length in seconds (the recording's, or an estimate).
    private var lengths: [Double] = []
    private var task: Task<Void, Never>?
    private var clock: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private let synth = AVSpeechSynthesizer()
    private var lineDone: CheckedContinuation<Void, Never>?
    private var utterance: AVSpeechUtterance?
    private static let gap = 0.35

    override init() {
        super.init()
        synth.delegate = self
    }

    private var total: Double { max(0.1, lengths.reduce(0, +)) }
    var duration: Double { (total + Double(lengths.count) * Self.gap) / speed }
    var speedLabel: String { speed == 1 ? "1x" : speed == 1.5 ? "1.5x" : "2x" }

    func timeLabel(_ s: Double) -> String {
        let secs = Int(s.rounded())
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    func load(_ s: Script, id newID: String) {
        stop()
        script = s
        id = newID
        lengths = s.lines.enumerated().map { i, l in
            if let url = s.audio[i], let p = try? AVAudioPlayer(contentsOf: url) { return p.duration }
            return Double(l.line.count) * 0.065 + 0.3
        }
        finished = false
        progress = 0; elapsed = 0; lineIndex = 0
    }

    func play() {
        guard !script.lines.isEmpty else { return }
        if finished { finished = false; progress = 0; elapsed = 0; lineIndex = 0 }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        playing = true
        let from = lineIndex
        task = Task { await run(from: from) }
        clock = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.1))
                guard !Task.isCancelled else { return }
                elapsed = min(duration, elapsed + 0.1)
            }
        }
    }

    func pause() { playing = false; halt() }
    func stop() { playing = false; halt() }

    func cycleSpeed() {
        speed = speed == 1 ? 1.5 : speed == 1.5 ? 2 : 1
        // Pick the new pace up from the current line.
        if playing { halt(); play() }
    }

    private func halt() {
        task?.cancel(); task = nil
        clock?.cancel(); clock = nil
        audioPlayer?.stop(); audioPlayer = nil
        synth.stopSpeaking(at: .immediate)
        resumeLine()
    }

    private func run(from start: Int) async {
        for i in start..<script.lines.count {
            guard !Task.isCancelled else { return }
            lineIndex = i
            let before = lengths.prefix(i).reduce(0, +)
            if let url = script.audio[i] {
                await playFile(url, before: before, length: lengths[i])
            } else {
                await speak(script.lines[i], before: before, length: lengths[i])
            }
            guard !Task.isCancelled else { return }
            progress = min(1, (before + lengths[i]) / total)
            try? await Task.sleep(for: .seconds(Self.gap / speed))
        }
        guard !Task.isCancelled else { return }
        playing = false
        clock?.cancel()
        elapsed = duration
        progress = 1
        finished = true
    }

    private func playFile(_ url: URL, before: Double, length: Double) async {
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.enableRate = true
        p.rate = Float(speed)
        audioPlayer = p
        p.play()
        while p.isPlaying, !Task.isCancelled {
            progress = min(1, (before + p.currentTime) / total)
            try? await Task.sleep(for: .seconds(0.05))
        }
    }

    // MARK: System voice (fallback)

    private var speakingBase = 0.0
    private var speakingLength = 1.0

    private func speak(_ l: (speaker: String, line: String), before: Double, length: Double) async {
        let isEqual = l.speaker == "Equal AI"
        let u = AVSpeechUtterance(string: AudioClips.spoken(l.line))
        u.voice = AVSpeechSynthesisVoice(language: "en-IN")
        u.pitchMultiplier = isEqual ? script.voice.pitch : (script.voice.pitch < 1 ? 1.15 : 0.85)
        let rate = (isEqual ? script.voice.rate : 0.5) * Float(speed == 1 ? 1 : speed == 1.5 ? 1.2 : 1.38)
        u.rate = min(AVSpeechUtteranceMaximumSpeechRate * 0.75, rate)
        speakingBase = before
        speakingLength = length
        await withCheckedContinuation { c in
            lineDone = c
            utterance = u
            synth.speak(u)
        }
    }

    private func resumeLine() {
        utterance = nil
        let c = lineDone
        lineDone = nil
        c?.resume()
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString r: NSRange, utterance u: AVSpeechUtterance) {
        let n = Double((u.speechString as NSString).length)
        Task { @MainActor in
            guard self.playing, u === self.utterance, n > 0 else { return }
            let f = Double(r.location + r.length) / n
            self.progress = min(1, (self.speakingBase + f * self.speakingLength) / self.total)
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in if u === self.utterance { self.resumeLine() } }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in if u === self.utterance { self.resumeLine() } }
    }
}
