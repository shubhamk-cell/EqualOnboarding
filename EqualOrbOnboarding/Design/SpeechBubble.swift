import SwiftUI

/// What the orb is saying in its bubble. Text is typed in and erased character by character.
/// Every type/erase takes a fresh token, so a newer one silently stops an older one mid-way
/// (the playful lines can interrupt a scripted line and then hand back to it).
@MainActor
final class Talk: ObservableObject {
    @Published var text = ""
    /// The line the bubble rests on; playful lines always come back to it.
    @Published var full = ""
    @Published var typing = false
    /// Mint fill while Equal is being playful.
    @Published var alt = false
    /// Bumps each time the bubble should pop in again.
    @Published var popID = 0

    private var token = 0
    private var lastPlayful = ""
    private var playTask: Task<Void, Never>?

    /// Pops the bubble in empty, then types `line` after a short beat.
    func intro(_ line: String, delay: Double = 0.42, speed: Double = 0.024) {
        full = line
        text = ""
        popID += 1
        token += 1
        let my = token
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard my == token else { return }
            await type(line, speed: speed)
        }
    }

    /// Types `line`, replacing whatever is shown. Returns false if something newer took over.
    @discardableResult
    func type(_ line: String, speed: Double = 0.022) async -> Bool {
        token += 1
        let my = token
        typing = true
        text = ""
        for ch in line {
            guard my == token else { return false }
            text.append(ch)
            let pause = ",.—?!".contains(ch) ? 0.09 : 0
            try? await Task.sleep(for: .seconds(speed + pause))
        }
        guard my == token else { return false }
        typing = false
        return true
    }

    @discardableResult
    func erase(speed: Double = 0.008) async -> Bool {
        token += 1
        let my = token
        typing = true
        while !text.isEmpty {
            guard my == token else { return false }
            text.removeLast()
            try? await Task.sleep(for: .seconds(speed))
        }
        return my == token
    }

    /// Erase, then type a new resting line.
    func replace(with line: String, speed: Double = 0.022) async {
        full = line
        await erase()
        await type(line, speed: speed)
    }

    /// Someone poked the orb: nod to it with a playful line, then steer back to the question.
    func playful(_ pool: [String]) {
        let options = pool.filter { $0 != lastPlayful }
        guard let line = options.randomElement() else { return }
        lastPlayful = line
        playTask?.cancel()
        playTask = Task {
            alt = true
            await erase(speed: 0.008)
            guard await type(line, speed: 0.02), !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled, await erase(speed: 0.01) else { return }
            alt = false
            await type(full, speed: 0.022)
        }
    }
}

// MARK: - Bubble views

/// White speech bubble that rises out of the orb, tail pointing down at it.
/// It hugs the text as it types; the row reserves room for the full line up front so typing
/// (or the orb's chatter) never shifts the page.
struct TopBubble: View {
    @ObservedObject var talk: Talk
    var reserve: String
    var fontSize: CGFloat = 18
    var lineHeight: CGFloat = 23
    var maxWidth: CGFloat = 300

    var body: some View {
        bubble(Text(reserve), caret: false)
            .hidden()
            .frame(maxWidth: maxWidth)
            .overlay(alignment: .bottom) {
                BubblePop(id: talk.popID) {
                    bubble(nil, caret: true)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
    }

    private func bubble(_ text: Text?, caret: Bool) -> some View {
        TypedText(talk: talk, fixed: text, fontSize: fontSize)
            .font(.dm(fontSize, .semibold))
            .tracking(-0.02 * fontSize)
            .lineSpacing(lineHeight - fontSize * 1.2)
            .foregroundStyle(EQ.ink)
            .multilineTextAlignment(.center)
            .frame(minHeight: lineHeight)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 15)
            .background(BubbleShape(tail: .bottom).fill(talk.alt ? EQ.mintAlt : .white))
            .compositingGroup()
            .shadow(color: Color(hex: 0x001E0A).opacity(0.10), radius: 1, y: 0.5)
            .shadow(color: Color(hex: 0x00280F).opacity(0.13), radius: 11, y: 8)
            .animation(.easeInOut(duration: 0.25), value: talk.alt)
            .accessibilityLabel(talk.full)
    }
}

/// The compact bubble beside a small orb (permissions and setup screens): tail points left.
struct SideBubble: View {
    @ObservedObject var talk: Talk
    var reserve: String
    var fontSize: CGFloat = 17
    var lineHeight: CGFloat = 22
    var padH: CGFloat = 16
    var padV: CGFloat = 12
    var radius: CGFloat = 18

    var body: some View {
        bubble(Text(reserve), caret: false)
            .hidden()
            .overlay(alignment: .leading) {
                BubblePop(id: talk.popID, anchor: UnitPoint(x: -0.05, y: 0.5)) {
                    bubble(nil, caret: true)
                }
            }
    }

    private func bubble(_ text: Text?, caret: Bool) -> some View {
        TypedText(talk: talk, fixed: text, fontSize: fontSize)
            .font(.dm(fontSize, .semibold))
            .tracking(-0.02 * fontSize)
            .lineSpacing(lineHeight - fontSize * 1.2)
            .foregroundStyle(EQ.ink)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: lineHeight, alignment: .leading)
            .padding(.horizontal, padH)
            .padding(.vertical, padV)
            .background(BubbleShape(tail: .left, radius: radius).fill(talk.alt ? EQ.mintAlt : .white))
            .compositingGroup()
            .shadow(color: Color(hex: 0x001E0A).opacity(0.10), radius: 1, y: 0.5)
            .shadow(color: Color(hex: 0x00280F).opacity(0.13), radius: 11, y: 8)
            .animation(.easeInOut(duration: 0.25), value: talk.alt)
            .accessibilityLabel(talk.full)
    }
}

/// Re-runs the bubble's pop-in (scale .4 → 1, rising 24 pt, with overshoot) whenever `id` changes.
struct BubblePop<Content: View>: View {
    var id: Int
    var anchor = UnitPoint(x: 0.42, y: 1.2)
    @ViewBuilder var content: Content
    @State private var shown = false

    var body: some View {
        content
            .scaleEffect(shown ? 1 : 0.4, anchor: anchor)
            .offset(y: shown ? 0 : 24)
            .opacity(shown ? 1 : 0)
            .onChange(of: id, initial: true) { _, _ in
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { shown = false }
                DispatchQueue.main.async { withAnimation(EQ.pop(0.55)) { shown = true } }
            }
    }
}

/// The bubble's text: either a fixed line (used invisibly to reserve space) or the live typed
/// text followed by a blinking green caret while typing.
private struct TypedText: View {
    @ObservedObject var talk: Talk
    var fixed: Text?
    var fontSize: CGFloat
    var body: some View {
        if let fixed {
            fixed
        } else {
            TimelineView(.periodic(from: .now, by: 0.4)) { ctx in
                let blink = Int(ctx.date.timeIntervalSinceReferenceDate / 0.4) % 2 == 0
                Text(talk.text)
                    + Text(talk.typing ? "|" : "")
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundStyle(blink ? EQ.green : Color.clear)
            }
        }
    }
}

/// Rounded bubble with an organic tail: under the middle (orb below) or on the left (orb beside).
struct BubbleShape: Shape {
    enum Tail { case bottom, left }
    var tail: Tail
    var radius: CGFloat = 22

    func path(in r: CGRect) -> Path {
        // Tail and body are unioned so their overlap never cancels out into a seam.
        var p = Path(roundedRect: r, cornerRadius: min(radius, r.height / 2), style: .continuous)
        switch tail {
        case .bottom:
            // 46 × 14: M0 0 C9 0 15 11 21 13 C22.3 13.4 23.7 13.4 25 13 C31 11 37 0 46 0 Z
            let o = CGPoint(x: r.midX - 23, y: r.maxY - 1)
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x, y: o.y + y) }
            var t = Path()
            t.move(to: pt(0, 0))
            t.addCurve(to: pt(21, 13), control1: pt(9, 0), control2: pt(15, 11))
            t.addCurve(to: pt(25, 13), control1: pt(22.3, 13.4), control2: pt(23.7, 13.4))
            t.addCurve(to: pt(46, 0), control1: pt(31, 11), control2: pt(37, 0))
            t.closeSubpath()
            p = p.union(t)
        case .left:
            // 12 × 22 at left −10: M12 0 C12 6 5 9 0 11 C5 13 12 16 12 22 Z
            let o = CGPoint(x: r.minX - 10, y: r.midY - 11)
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x, y: o.y + y) }
            var t = Path()
            t.move(to: pt(12, 0))
            t.addCurve(to: pt(0, 11), control1: pt(12, 6), control2: pt(5, 9))
            t.addCurve(to: pt(12, 22), control1: pt(5, 13), control2: pt(12, 16))
            t.closeSubpath()
            p = p.union(t)
        }
        return p
    }
}

// MARK: - Orb + bubble rows

/// Big orb with the bubble above it (number, code, name, picks, welcome).
struct OrbWithBubble: View {
    @ObservedObject var talk: Talk
    var reserve: String
    var orbDiameter: CGFloat = 128
    var fontSize: CGFloat = 18
    var lineHeight: CGFloat = 23
    var spinning = false
    var playful: [String]
    /// Global point the orb flies in from (the splash mark), first screen only.
    var flyFrom: CGPoint? = nil

    var body: some View {
        VStack(spacing: 18) {
            TopBubble(talk: talk, reserve: reserve, fontSize: fontSize, lineHeight: lineHeight)
                .zIndex(2)
            Orb(diameter: orbDiameter, spinning: spinning) { _ in talk.playful(playful) }
                .modifier(FlyIn(from: flyFrom))
        }
    }
}

/// Small orb (56 pt) with the bubble beside it (permissions, forwarding, voicemail).
struct OrbBesideBubble: View {
    @ObservedObject var talk: Talk
    var reserve: String
    var rings = false
    var fontSize: CGFloat = 17
    var lineHeight: CGFloat = 22
    var padH: CGFloat = 16
    var padV: CGFloat = 12
    var radius: CGFloat = 18
    var playful: [String]

    var body: some View {
        HStack(spacing: 14) {
            Orb(diameter: 56, rings: rings) { _ in talk.playful(playful) }
            SideBubble(talk: talk, reserve: reserve, fontSize: fontSize, lineHeight: lineHeight,
                       padH: padH, padV: padV, radius: radius)
        }
    }
}
