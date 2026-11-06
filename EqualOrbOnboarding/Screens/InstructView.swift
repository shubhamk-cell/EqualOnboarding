import SwiftUI
import Speech
import AVFoundation

/// V2: after the picks, Equal drafts three instructions from them (a carousel of cards). Hold the
/// voice button and say one, or your own (the keyboard button types one instead). What was said
/// lands as the user's message — the voice note with its transcript — and the flow moves on to
/// `HandleView`, which shows a call of how Equal will follow it.
struct InstructView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @StateObject private var voice = VoiceCapture()

    enum Phase { case drafting, choosing, sent }
    @State private var phase: Phase = .drafting
    @State private var showCards = false
    @State private var page: Int? = 0
    @State private var typing = false
    @State private var typed = ""
    @FocusState private var typeFocused: Bool
    @State private var pressedAt: Date?

    private var ids: [String] {
        let picks = Array(model.picks.prefix(3))
        let fill = Catalog.useCases.map(\.id).filter { !picks.contains($0) }
        return picks + fill.prefix(max(0, 3 - picks.count))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !showCards { Spacer(minLength: 0) }
            OrbWithBubble(talk: talk, reserve: Catalog.instructAsk, spinning: phase == .drafting)
                .padding(.top, 10)
                .padding(.horizontal, 24)

            if showCards {
                carousel
                    .transition(.opacity.combined(with: .offset(y: 40)))
            } else {
                Spacer(minLength: 0)
            }

            footer
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .opacity(showCards ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.25), value: showCards)
        }
        .onAppear {
            // Back from the call page: skip the drafting, straight to the ask.
            if model.instruction != nil {
                phase = .choosing
                talk.intro(Catalog.instructAsk)
            } else {
                talk.intro(Catalog.drafting)
            }
        }
        // The orb talks first, alone in the middle: “Writing instructions…”, a beat, then the ask.
        // Only once the ask is showing do the cards arrive and push it up.
        .onChange(of: talk.typing) { was, isTyping in
            guard was, !isTyping else { return }
            if phase == .drafting {
                Task {
                    try? await Task.sleep(for: .seconds(1.1))
                    guard phase == .drafting else { return }
                    phase = .choosing
                    await talk.replace(with: Catalog.instructAsk)
                }
            } else if phase == .choosing, !showCards {
                Task {
                    try? await Task.sleep(for: .seconds(0.45))
                    Haptics.land()
                    withAnimation(OrbFlight.glide) { showCards = true }
                }
            }
        }
        .onDisappear { Task { _ = await voice.stop() } }
    }

    // MARK: Instruction cards

    private var carousel: some View {
        VStack(spacing: 14) {
            GeometryReader { g in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(ids.enumerated()), id: \.offset) { i, id in
                            InstructionCard(useCase: Catalog.useCase(id), text: Catalog.instructions[id] ?? "",
                                            index: i, total: ids.count, current: (page ?? 0) == i)
                                .frame(width: g.size.width - 48 - 28)
                                .id(i)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $page)
                .contentMargins(.horizontal, 24, for: .scrollContent)
                // Let the cards' shadows spill past the scroll area instead of ending in a hard line.
                .scrollClipDisabled()
            }
            .frame(height: 196)
            HStack(spacing: 6) {
                ForEach(ids.indices, id: \.self) { i in
                    let on = i == (page ?? 0)
                    Capsule().fill(on ? EQ.green : EQ.ink.opacity(0.18))
                        .frame(width: on ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: page)
                }
            }
            // What the user said joins the page below the cards.
            if phase == .sent {
                Spacer(minLength: 12)
                UserMessage(text: model.instruction ?? "", note: model.instructionNote)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 24)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 36)
        .onChange(of: page) { Haptics.select() }
    }

    private var currentInstruction: String {
        Catalog.instructions[ids[min(page ?? 0, ids.count - 1)]] ?? ""
    }

    // MARK: Sent: the user's message, then on to the call

    private func save(_ said: String, note: VoiceNote? = nil) {
        let text = said.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        typeFocused = false
        model.instruction = text
        model.instructionNote = note
        model.instructionPick = Catalog.useCase(for: text, among: ids)?.id
        Haptics.success()
        withAnimation(EQ.push(0.5)) { phase = .sent; typing = false }
        typed = ""
        Task {
            await talk.replace(with: Catalog.instructHeard)
            // A moment to see the message land, then the call it leads to.
            try? await Task.sleep(for: .seconds(1.4))
            guard model.step == .instruct, phase == .sent else { return }
            model.next()
        }
    }

    // MARK: Footer: hold to speak, or type

    @ViewBuilder private var footer: some View {
        if phase == .sent {
            Color.clear.frame(height: 0)
        } else if typing {
            HStack(spacing: 10) {
                circleButton("mic.fill", label: "Speak instead") {
                    withAnimation(EQ.push(0.35)) { typing = false }
                    typeFocused = false
                }
                HStack(spacing: 8) {
                    TextField("", text: $typed, prompt: Text("Type an instruction").foregroundStyle(EQ.ink.opacity(0.55)),
                              axis: .vertical)
                        .font(.dm(16))
                        .lineLimit(1...3)
                        .focused($typeFocused)
                        .submitLabel(.send)
                        .onSubmit { save(typed) }
                    Button { save(typed) } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(typed.isEmpty ? EQ.green.opacity(0.35) : EQ.green))
                    }
                    .disabled(typed.isEmpty)
                    .accessibilityLabel("Send")
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .frame(minHeight: 56)
                .background(Capsule().fill(.white))
                .overlay(Capsule().strokeBorder(EQ.green.opacity(0.5), lineWidth: 1.5))
            }
            .transition(.opacity)
        } else {
            HStack(spacing: 10) {
                circleButton("keyboard", label: "Type instead") {
                    withAnimation(EQ.push(0.35)) { typing = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { typeFocused = true }
                }
                holdButton
            }
            .transition(.opacity)
        }
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.select(); action() } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(EQ.ink.opacity(0.55))
                .frame(width: 56, height: 56)
                .background(Circle().fill(.white))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .accessibilityLabel(label)
    }

    /// Green “Send voice note” pill: press and hold to talk, release to send.
    private var holdButton: some View {
        let on = voice.recording
        return ZStack {
            Capsule()
                .fill(LinearGradient(colors: [EQ.voiceTop, EQ.green], startPoint: .top, endPoint: .bottom))
                .shadow(color: EQ.green.opacity(on ? 0.45 : 0.25), radius: on ? 16 : 10, y: 6)
            if on {
                HStack(spacing: 10) {
                    LevelBars(level: voice.level)
                    Text("Release to send").font(.dm(17, .semibold)).foregroundStyle(.white)
                }
                .transition(.opacity)
            } else {
                Label("Send voice note", systemImage: "mic.fill")
                    .font(.dm(18, .semibold))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            }
        }
        .frame(height: 56)
        .scaleEffect(on ? 1.04 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: on)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if pressedAt == nil { pressBegan() } }
                .onEnded { _ in pressEnded() }
        )
        .accessibilityLabel("Send voice note")
        .accessibilityHint("Hold to speak, release to send. Sends the instruction on screen if nothing is heard.")
        .accessibilityAction { save(currentInstruction) }
    }

    private func pressBegan() {
        pressedAt = Date()
        if voice.needsPermission {
            // The system prompts interrupt this press; once answered, the next hold records.
            Task { await voice.askPermission() }
            pressedAt = .distantFuture
            return
        }
        Haptics.select()
        voice.start()
        // Equal says it's listening while the button is held.
        talk.full = Catalog.listening
        Task { await talk.show(Catalog.listening) }
    }

    private func pressEnded() {
        defer { pressedAt = nil }
        guard let start = pressedAt, start != .distantFuture else { return }
        let held = Date().timeIntervalSince(start)
        Task {
            let (heard, note) = await voice.stop()
            guard held > 0.35 else {
                model.show(toast: "Hold to speak, then release to send")
                talk.full = Catalog.instructAsk
                await talk.show(Catalog.instructAsk)
                return
            }
            // Nothing heard (no permission, or no speech, e.g. in the simulator): send the card on screen.
            save(heard.isEmpty ? currentInstruction : heard, note: note ?? VoiceNote(url: nil, duration: held, levels: []))
        }
    }
}

/// One drafted instruction: the pick it came from, then the instruction in Equal's words.
private struct InstructionCard: View {
    var useCase: UseCase?
    var text: String
    var index: Int
    var total: Int
    var current: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(useCase?.emoji ?? "✨")
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: Catalog.cardTints[index % 3])))
                Text(useCase?.label ?? "")
                    .font(.dm(13, .medium))
                    .foregroundStyle(EQ.ink.opacity(0.62))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(index + 1)/\(total)")
                    .font(.dm(12, .semibold))
                    .foregroundStyle(EQ.ink.opacity(0.45))
            }
            Text("“\(text)”")
                .font(.dm(18, .semibold))
                .tracking(-0.3)
                .foregroundStyle(EQ.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(current ? EQ.green.opacity(0.45) : .white, lineWidth: 1.5))
        .shadow(color: Color(hex: 0x003214).opacity(current ? 0.12 : 0.06), radius: current ? 14 : 8, y: 8)
        .animation(.easeInOut(duration: 0.25), value: current)
    }
}

/// Five bars that jump with the microphone level while recording.
private struct LevelBars: View {
    var level: CGFloat
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    // A gentle idle ripple, lifted by the voice.
                    let idle = 0.25 + 0.15 * (1 + sin(t * 6 + Double(i) * 1.1)) / 2
                    let h = 22 * max(idle, min(1, level * (0.6 + 0.4 * Double((i * 7) % 5) / 4)))
                    Capsule().fill(.white).frame(width: 3.5, height: max(5, h))
                }
            }
            .frame(height: 22)
        }
    }
}

/// Fades and rises a view in once, after `delay`.
private struct PopIn: ViewModifier {
    var delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .scaleEffect(shown ? 1 : 0.96)
            .onAppear { withAnimation(EQ.pop(0.5).delay(delay)) { shown = true } }
    }
}

// MARK: - Voice capture

/// Records while the button is held and transcribes on the fly (on-device where available).
/// Without microphone or speech permission it still “records”, so the flow works; the screen then
/// sends the instruction card that's showing.
@MainActor
final class VoiceCapture: ObservableObject {
    @Published var recording = false
    @Published var transcript = ""
    @Published var level: CGFloat = 0

    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var fileURL: URL?
    private var startedAt = Date()
    /// Sound levels sampled through the recording, for the voice note's waveform.
    private var levels: [CGFloat] = []
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN")) ?? SFSpeechRecognizer()

    var needsPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .notDetermined
            || AVAudioApplication.shared.recordPermission == .undetermined
    }

    private var permitted: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
    }

    func askPermission() async {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            _ = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
            }
        }
        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
    }

    func start() {
        transcript = ""
        level = 0
        levels = []
        startedAt = Date()
        file = nil
        fileURL = nil
        recording = true
        guard permitted, let recognizer, recognizer.isAvailable else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            request = req
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("instruction-\(UUID().uuidString).caf")
            let out = try AVAudioFile(forWriting: url, settings: format.settings)
            file = out
            fileURL = url
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format,
                             block: Self.tap(req, file: out) { [weak self] l in
                                 Task { @MainActor in
                                     self?.level = l
                                     self?.levels.append(l)
                                 }
                             })
            engine.prepare()
            try engine.start()
            task = recognizer.recognitionTask(with: req, resultHandler: Self.results { [weak self] text in
                Task { @MainActor in self?.transcript = text }
            })
        } catch {
            stopEngine()
        }
    }

    /// Stops recording and returns what was heard and the recording (nil when nothing was recorded).
    func stop() async -> (String, VoiceNote?) {
        guard recording else { return (transcript, nil) }
        recording = false
        let duration = Date().timeIntervalSince(startedAt)
        guard engine.isRunning else { return (transcript, nil) }
        request?.endAudio()
        stopEngine()
        file = nil   // closes it
        // Give the last words a moment to come back.
        try? await Task.sleep(for: .seconds(0.6))
        task?.cancel()
        task = nil
        request = nil
        return (transcript, VoiceNote(url: fileURL, duration: duration, levels: levels))
    }

    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // Built outside the main actor: these run on audio and recognition threads.
    nonisolated private static func tap(_ req: SFSpeechAudioBufferRecognitionRequest, file: AVAudioFile,
                                        level: @escaping @Sendable (CGFloat) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            req.append(buffer)
            try? file.write(from: buffer)
            guard let ch = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<n { sum += ch[i] * ch[i] }
            level(CGFloat(min(1, sqrt(sum / Float(max(n, 1))) * 14)))
        }
    }

    nonisolated private static func results(_ text: @escaping @Sendable (String) -> Void)
        -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, _ in
            if let s = result?.bestTranscription.formattedString { text(s) }
        }
    }
}

// MARK: - The user's message

/// A recorded instruction: the audio (nil if nothing could be recorded), how long it ran and its
/// sound levels.
struct VoiceNote {
    var url: URL?
    var duration: Double
    var levels: [CGFloat]

    /// `count` bars for the waveform: the recording's levels when there are some, otherwise a
    /// natural-looking pattern.
    func bars(_ count: Int) -> [CGFloat] {
        guard levels.count >= count else {
            return (0..<count).map { j -> CGFloat in
                let x = Double(j)
                let a: Double = abs(sin(x * 1.3 + 0.5))
                let b: Double = 0.6 + 0.4 * abs(cos(x * 0.7))
                return CGFloat(0.3 + 0.7 * a * b)
            }
        }
        let chunk = levels.count / count
        let raw: [CGFloat] = (0..<count).map { i -> CGFloat in
            levels[(i * chunk)..<((i + 1) * chunk)].max() ?? 0
        }
        let top: CGFloat = max(raw.max() ?? 1, 0.05)
        return raw.map { max(0.18, $0 / top) }
    }
}

/// The user's message, on the right like a chat: a voice note (play, waveform, length) with its
/// transcript underneath, or just the text when it was typed.
struct UserMessage: View {
    var text: String
    var note: VoiceNote?
    @StateObject private var player = NotePlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let note {
                // The recording sits in its own grey strip above the transcript.
                HStack(spacing: 10) {
                    Button { Haptics.select(); player.toggle(note) } label: {
                        Image(systemName: player.playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(EQ.greenPress)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.white))
                            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(PressStyle(scale: 0.92))
                    .disabled(note.url == nil)
                    .accessibilityLabel(player.playing ? "Pause" : "Play your voice note")
                    TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !player.playing)) { _ in
                        let p = player.progress
                        let bars = note.bars(28)
                        HStack(spacing: 2.5) {
                            ForEach(bars.indices, id: \.self) { j in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Double(j) / Double(bars.count) < p ? EQ.greenPress : EQ.greenPress.opacity(0.35))
                                    .frame(maxWidth: 3, minHeight: 4 + 20 * bars[j], maxHeight: 4 + 20 * bars[j])
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                    }
                    Text(String(format: "0:%02d", Int(note.duration.rounded())))
                        .font(.dm(12.5, .medium))
                        .monospacedDigit()
                        .foregroundStyle(EQ.ink.opacity(0.55))
                }
                .padding(.leading, 6)
                .padding(.trailing, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                // Concentric with the bubble: its 20 pt corner less the 8 pt inset.
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: 0xF1F2F0)))
            }
            Text(text)
                .font(.dm(15, note == nil ? .medium : .regular))
                .foregroundStyle(EQ.ink.opacity(note == nil ? 1 : 0.8))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, note == nil ? 6 : 6)
        }
        .padding(8)
        .padding(.bottom, 4)
        .frame(maxWidth: note == nil ? nil : 290, alignment: .leading)
        // The user's pointer: like the orb's, from the top-right corner, pointing right.
        .background(BubbleShape(tail: .topRight, radius: 20).fill(.white))
        .shadow(color: Color(hex: 0x001E0A).opacity(0.08), radius: 1, y: 0.5)
        .shadow(color: Color(hex: 0x00280F).opacity(0.10), radius: 10, y: 6)
        .frame(maxWidth: 290, alignment: .trailing)
        // Pops in from the right edge, where the user's messages come from.
        .modifier(PopFromRight())
        .onDisappear { player.stop() }
    }
}

private struct PopFromRight: ViewModifier {
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.4, anchor: .bottomTrailing)
            .offset(x: shown ? 0 : 24)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(EQ.pop(0.5)) { shown = true } }
    }
}

/// Plays a recorded voice note.
@MainActor
final class NotePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playing = false
    private var player: AVAudioPlayer?

    var progress: Double {
        guard let player, player.duration > 0 else { return 0 }
        return playing ? player.currentTime / player.duration : 0
    }

    func toggle(_ note: VoiceNote) {
        if playing { stop(); return }
        guard let url = note.url else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        playing = player?.play() ?? false
    }

    func stop() {
        player?.stop()
        playing = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playing = false }
    }
}

// MARK: - V2: how Equal will handle it

/// The page after the instruction: Equal confirms it and plays a sample call of it following it.
struct HandleView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    /// The orb speaks first, alone in the middle; then the content arrives and pushes it up.
    @State private var showContent = false

    private var pick: UseCase? {
        model.instructionPick.flatMap(Catalog.useCase)
            ?? Catalog.useCase(model.picks.first ?? Catalog.useCases[0].id)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !showContent { Spacer(minLength: 0) }
            // Orb beside its bubble, as on every call-player page.
            OrbBesideBubble(talk: talk, reserve: Catalog.instructSaved)
                .padding(.top, 14)
                .padding(.horizontal, 24)
            if showContent { content.transition(.opacity.combined(with: .offset(y: 40))) } else { Spacer(minLength: 0) }
            footer
                .opacity(showContent ? 1 : 0)
                .allowsHitTesting(showContent)
                .animation(.easeOut(duration: 0.4).delay(0.25), value: showContent)
        }
        .onAppear { talk.intro(Catalog.instructSaved) }
        .onChange(of: talk.typing) { was, isTyping in
            guard was, !isTyping, !showContent else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.45))
                Haptics.land()
                withAnimation(OrbFlight.glide) { showContent = true }
            }
        }
    }

    private var content: some View {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    // What the user said, or (skipped ahead) the instruction Equal drafted for this pick.
                    if let instruction = model.instruction ?? pick.flatMap({ Catalog.instructions[$0.id] }) {
                        Text("Your instruction")
                            .font(.dm(12, .semibold)).tracking(0.4)
                            .foregroundStyle(EQ.ink.opacity(0.5))
                        Text("“\(instruction)”")
                            .font(.dm(16, .medium))
                            .foregroundStyle(EQ.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                // The sample call, in the call player, in whatever room is left: no scrolling.
                if let u = pick {
                    CallDeck(calls: [u], art: 170)
                        .padding(.top, 12)
                        .frame(maxHeight: .infinity)
                }
            }
    }

    private var footer: some View {
            VStack(spacing: 4) {
                Button("Continue") { model.next() }
                    .buttonStyle(PrimaryButtonStyle())
                Button {
                    Haptics.step()
                    model.back()
                } label: {
                    Text("Try another instruction")
                        .font(.dm(16, .semibold)).underline().foregroundStyle(EQ.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(PressStyle())
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }
}
