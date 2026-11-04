import SwiftUI

/// “What can I handle for you? Pick any” — ten everyday jobs as two-per-row pills.
/// Continue curates on the same screen: the unpicked pills fade away, the orb's dots gather
/// into a spinning ring while the bubble says it's curating, then the top three picks come
/// back as sample-call cards and the first one starts playing.
struct CasesView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @StateObject private var player = SamplePlayer()
    @State private var phase: Phase = .picking
    @State private var gridGone = false
    @State private var top: [String] = []
    @State private var open: String?

    enum Phase { case picking, curating, curated }

    private let title = Catalog.title(.cases, name: "")

    private var rows: [[UseCase]] {
        stride(from: 0, to: Catalog.useCases.count, by: 2).map {
            Array(Catalog.useCases[$0..<min($0 + 2, Catalog.useCases.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OrbWithBubble(talk: talk, reserve: title, spinning: phase == .curating, playful: Catalog.playful(.cases))
                .padding(.top, 10)
                .padding(.horizontal, 24)

            ScrollView(showsIndicators: false) {
                Group {
                    if phase == .curated { cardStack } else { pillGrid }
                }
                .padding(.horizontal, 24)
                .padding(.top, phase == .curated ? 34 : 14)   // the sample-call cards sit lower, clear of the orb's glow
                .padding(.bottom, 44)
            }
            .scrollBounceBehavior(.basedOnSize)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 14)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 40)
                }
            }

            Button("Continue", action: proceed)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.picks.isEmpty)
                .opacity(phase == .curating ? 0 : 1)
                .allowsHitTesting(phase != .curating)
                .animation(.easeInOut(duration: 0.3), value: phase)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .onAppear { talk.intro(title) }
        .onDisappear { player.stop() }
    }

    // MARK: Picking

    private var pillGrid: some View {
        VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { r in
                BrickRow(weights: rows[r].map { CGFloat($0.label.count * $0.label.count) }) {
                    ForEach(rows[r]) { u in
                        pill(u, index: r * 2 + (rows[r].firstIndex(of: u) ?? 0))
                    }
                }
            }
        }
        .opacity(gridGone ? 0 : 1)
        .offset(y: gridGone ? -8 : 0)
    }

    private func pill(_ u: UseCase, index: Int) -> some View {
        let on = model.picks.contains(u.id)
        let kept = top.contains(u.id)
        let fading = phase != .picking && !kept
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if on { model.picks.removeAll { $0 == u.id } } else { model.picks.append(u.id) }
            }
        } label: {
            HStack(spacing: 7) {
                Text(u.emoji).font(.system(size: 18))
                Text(u.label)
                    .font(.dm(14.5, .medium))
                    .tracking(-0.22)
                    .lineSpacing(0.6)
                    .foregroundStyle(on ? EQ.greenText : EQ.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)   // narrower phones: shrink a touch rather than truncate
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? EQ.mintAlt : .white.opacity(0.7)))
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).inset(by: -3).fill(EQ.green.opacity(on ? 0.12 : 0)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(on ? EQ.green : .white.opacity(0.95), lineWidth: 1.5))
            .shadow(color: Color(hex: on ? 0x00782D : 0x003214).opacity(on ? 0.12 : 0.06), radius: on ? 7 : 6, y: on ? 6 : 4)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(EQ.green))
                    .overlay(Circle().stroke(EQ.page, lineWidth: 2))
                    .scaleEffect(on ? 1 : 0.4)
                    .opacity(on ? 1 : 0)
                    .offset(x: 4, y: -6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: on)
            }
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .disabled(phase != .picking)
        .sensoryFeedback(.selection, trigger: on)
        .scaleEffect(kept && phase != .picking ? 1.03 : fading ? 0.9 : 1)
        .opacity(fading ? 0 : 1)
        .blur(radius: fading ? 2 : 0)
        .animation(kept ? .timingCurve(0.34, 1.56, 0.64, 1, duration: 0.4)
                        : EQ.push(0.45).delay(Double(index) * 0.035), value: phase)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Curating

    private func proceed() {
        switch phase {
        case .picking:
            Task { await curate() }
        case .curated:
            player.stop()
            model.next()
        case .curating:
            break
        }
    }

    private func curate() async {
        top = Array(model.picks.prefix(3))
        phase = .curating
        await talk.erase()
        talk.full = Catalog.curating
        Task { await talk.type(Catalog.curating, speed: 0.022) }
        guard (try? await Task.sleep(for: .seconds(2.6))) != nil, model.step == .cases else { return }
        withAnimation(.easeInOut(duration: 0.35)) { gridGone = true }
        guard (try? await Task.sleep(for: .seconds(0.38))) != nil, model.step == .cases else { return }
        open = top.first
        withAnimation(EQ.push(0.5)) { phase = .curated }
        Task { await talk.replace(with: Catalog.curated) }
        guard (try? await Task.sleep(for: .seconds(0.7))) != nil, model.step == .cases,
              let first = top.first.flatMap(Catalog.useCase) else { return }
        player.play(first, name: model.displayName)
    }

    // MARK: Curated

    private var cardStack: some View {
        VStack(spacing: 10) {
            ForEach(Array(top.enumerated()), id: \.element) { i, id in
                if let u = Catalog.useCase(id) {
                    SampleCallCard(useCase: u, index: i, isOpen: open == id, player: player,
                                   onOpen: { openCard(u) },
                                   onPlay: { toggle(u) })
                        .modifier(CardIn(delay: Double(i) * 0.12))
                }
            }
        }
        .padding(.bottom, 12)
    }

    private func openCard(_ u: UseCase) {
        guard open != u.id else { return }
        player.stop()
        withAnimation(EQ.push(0.45)) { open = u.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard open == u.id, model.step == .cases else { return }
            player.play(u, name: model.displayName)
        }
    }

    private func toggle(_ u: UseCase) {
        if player.playing == u.id { player.stop() } else { player.play(u, name: model.displayName) }
    }
}

/// Lays out two pills per row with widths that follow their text (weight = length²),
/// never letting either drop below 40 % of the row.
struct BrickRow: Layout {
    var weights: [CGFloat]
    var spacing: CGFloat = 10
    var height: CGFloat = 64

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 345, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = Self.widths(total: bounds.width, weights: weights, spacing: spacing)
        var x = bounds.minX
        for (i, s) in subviews.enumerated() where i < widths.count {
            s.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: widths[i], height: height))
            x += widths[i] + spacing
        }
    }

    static func widths(total: CGFloat, weights: [CGFloat], spacing: CGFloat) -> [CGFloat] {
        guard weights.count == 2 else { return weights.map { _ in total } }
        let avail = total - spacing, minW = total * 0.4
        let w1 = min(max(avail * weights[0] / (weights[0] + weights[1]), minW), avail - minW)
        return [w1, avail - w1]
    }
}

private struct CardIn: ViewModifier {
    var delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .scaleEffect(shown ? 1 : 0.97)
            .onAppear { withAnimation(EQ.push(0.5).delay(delay)) { shown = true } }
    }
}

// MARK: - Sample call card

/// One curated pick: header with the job and who calls; when open, a player bar whose
/// waveform fills as the pretend call plays, with a live timer and a “Playing” pill.
struct SampleCallCard: View {
    let useCase: UseCase
    let index: Int
    let isOpen: Bool
    @ObservedObject var player: SamplePlayer
    var onOpen: () -> Void
    var onPlay: () -> Void

    private var playing: Bool { player.playing == useCase.id }
    private var done: Bool { player.done.contains(useCase.id) }
    private let bars: [CGFloat]

    init(useCase: UseCase, index: Int, isOpen: Bool, player: SamplePlayer, onOpen: @escaping () -> Void, onPlay: @escaping () -> Void) {
        self.useCase = useCase; self.index = index; self.isOpen = isOpen; self.player = player
        self.onOpen = onOpen; self.onPlay = onPlay
        bars = (0..<34).map { j in 6 + (abs(sin(Double(j) * 1.7 + Double(index))) * 18).rounded() }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) { header }
                .buttonStyle(.plain)
            playerBar
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .frame(height: isOpen ? nil : 0, alignment: .top)
                .opacity(isOpen ? 1 : 0)
                .clipped()
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isOpen ? AnyShapeStyle(LinearGradient(stops: [.init(color: Color(hex: 0xF0FCEE), location: 0), .init(color: .white, location: 0.7)],
                                                            startPoint: .top, endPoint: .bottom))
                             : AnyShapeStyle(Color.white))
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(isOpen ? EQ.green.opacity(0.35) : .white, lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: isOpen ? 0x00782D : 0x003214).opacity(isOpen ? 0.14 : 0.07), radius: isOpen ? 17 : 11, y: isOpen ? 14 : 8)
        .animation(EQ.push(0.45), value: isOpen)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(useCase.emoji)
                .font(.system(size: 21))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: Catalog.cardTints[index % 3])))
            VStack(alignment: .leading, spacing: 2) {
                Text(useCase.label)
                    .font(.dm(15.5, .semibold))
                    .foregroundStyle(EQ.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Sample call with \(useCase.caller)")
                    .font(.dm(12.5))
                    .foregroundStyle(EQ.ink.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isOpen {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(EQ.greenPress)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(EQ.mintAlt))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else if playing {
                HStack(spacing: 6) {
                    PulsingDot()
                    Text("Playing").font(.dm(12, .semibold))
                }
                .foregroundStyle(EQ.greenDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(hex: 0xE3F9E7)))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.25), value: playing)
    }

    private var playerBar: some View {
        let p = player.progress[useCase.id] ?? 0
        return HStack(spacing: 12) {
            Button(action: onPlay) {
                Image(systemName: playing ? "pause.fill" : done ? "arrow.counterclockwise" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(LinearGradient(colors: [Color(hex: 0x5BDB6A), EQ.greenPress], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: EQ.greenPress.opacity(0.3), radius: 5, y: 4)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressStyle(scale: 0.92))
            .accessibilityLabel(playing ? "Pause" : "Play sample call")

            HStack(spacing: 2.5) {
                ForEach(bars.indices, id: \.self) { j in
                    let lit = done || Double(j) / Double(bars.count) < p
                    RoundedRectangle(cornerRadius: 2)
                        .fill(lit ? EQ.green : EQ.ink.opacity(0.15))
                        .frame(maxWidth: .infinity, minHeight: bars[j], maxHeight: bars[j])
                        .animation(.easeOut(duration: 0.2), value: lit)
                }
            }
            .frame(height: 30)

            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                Text(player.timeLabel(useCase.id))
                    .font(.dm(12.5))
                    .monospacedDigit()
                    .foregroundStyle(EQ.ink.opacity(0.5))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(Capsule().fill(.white.opacity(0.9)))
        .overlay(Capsule().strokeBorder(EQ.green.opacity(0.12), lineWidth: 1))
    }
}

private struct PulsingDot: View {
    @State private var dim = false
    var body: some View {
        Circle()
            .fill(EQ.green)
            .frame(width: 6, height: 6)
            .opacity(dim ? 0.3 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { dim = true } }
    }
}

/// Plays the pretend calls: words land every 170 ms with a 380 ms beat between lines;
/// progress is the share of characters spoken. One call at a time.
@MainActor
final class SamplePlayer: ObservableObject {
    @Published var playing: String?
    @Published var progress: [String: Double] = [:]
    @Published var done: Set<String> = []
    private var started: [String: Date] = [:]
    private var frozen: [String: Int] = [:]
    private var token = 0

    func play(_ u: UseCase, name: String) {
        token += 1
        let my = token
        playing = u.id
        done.remove(u.id)
        progress[u.id] = 0
        started[u.id] = Date()
        frozen[u.id] = nil
        let lines = Catalog.script(u, name: name)
        let total = Double(lines.reduce(0) { $0 + $1.line.count })
        Task {
            var spoken = 0.0
            for l in lines {
                for w in l.line.split(separator: " ") {
                    guard my == token else { return }
                    spoken += Double(w.count + 1)
                    progress[u.id] = min(1, spoken / total)
                    try? await Task.sleep(for: .seconds(0.17))
                }
                try? await Task.sleep(for: .seconds(0.38))
            }
            guard my == token else { return }
            freeze(u.id)
            playing = nil
            done.insert(u.id)
            progress[u.id] = 1
        }
    }

    func stop() {
        token += 1
        if let id = playing { freeze(id) }
        playing = nil
    }

    private func freeze(_ id: String) {
        if let s = started[id] { frozen[id] = Int(Date().timeIntervalSince(s)) }
    }

    func timeLabel(_ id: String) -> String {
        let secs: Int
        if playing == id, let s = started[id] { secs = Int(Date().timeIntervalSince(s)) } else { secs = frozen[id] ?? 0 }
        return String(format: "0:%02d", secs)
    }
}
