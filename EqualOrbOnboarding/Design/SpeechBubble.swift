import SwiftUI

import Combine

/// What the orb is saying in its bubble. Text is typed in and erased character by character.
/// Every type/erase takes a fresh token, so a newer one silently stops an older one mid-way.
/// Lines are given in English and shown in `Language.shared.current`; when the language changes,
/// the bubble erases and retypes its line in the new one.
@MainActor
final class Talk: ObservableObject {
    @Published var text = ""
    /// The line the bubble rests on, in English.
    @Published var full = ""
    @Published var typing = false
    /// Mint fill while the bubble switches language.
    @Published var alt = false
    /// Bumps each time the bubble should pop in again.
    @Published var popID = 0

    private var token = 0
    private var languageSub: AnyCancellable?
    private var switchTask: Task<Void, Never>?

    init() {
        languageSub = Language.shared.$current.dropFirst().removeDuplicates().sink { [weak self] _ in
            self?.retype()
        }
    }

    /// Pops the bubble in empty (once the orb has landed), then types `line` after a short beat.
    func intro(_ line: String, delay: Double = 0.42, speed: Double = 0.024) {
        full = line
        text = ""
        popID += 1
        token += 1
        let my = token
        Task {
            await OrbFlight.untilLanded()
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
        for ch in Catalog.translate(line, to: Language.shared.current) {
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

    /// The language changed: erase and retype the resting line in the new one (mint meanwhile).
    /// A bubble that hasn't started talking yet picks up the language when it does.
    private func retype() {
        guard !full.isEmpty, !text.isEmpty else { return }
        switchTask?.cancel()
        switchTask = Task {
            // Runs after the change has landed, so `type` reads the new language.
            alt = true
            guard await erase(speed: 0.006) else { return }
            guard await type(full, speed: 0.018), !Task.isCancelled else { return }
            alt = false
        }
    }
}

// MARK: - Bubble views

/// White speech bubble that rises out of the orb, tail pointing down at it.
/// It hugs the text as it types; the row reserves room for the full line up front so typing
/// (or the orb's chatter) never shifts the page.
struct TopBubble: View {
    @ObservedObject var talk: Talk
    @ObservedObject private var language = Language.shared
    var reserve: String
    var fontSize: CGFloat = 18
    var lineHeight: CGFloat = 23
    var maxWidth: CGFloat = 300

    var body: some View {
        bubble(Text(Catalog.translate(reserve, to: language.current)), caret: false)
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
            .accessibilityLabel(Catalog.translate(talk.full, to: language.current))
    }
}

/// The compact bubble beside a small orb (permissions and setup screens). The tail points left
/// from the middle, from the top corner (first of a stack of messages), or not at all (the
/// messages after it). `hug` sizes it to its text instead of filling the width.
struct SideBubble: View {
    @ObservedObject var talk: Talk
    @ObservedObject private var language = Language.shared
    var reserve: String
    var fontSize: CGFloat = 17
    var lineHeight: CGFloat = 22
    var padH: CGFloat = 16
    var padV: CGFloat = 12
    var radius: CGFloat = 18
    var tail: BubbleShape.Tail = .left
    var hug = false

    var body: some View {
        bubble(Text(Catalog.translate(reserve, to: language.current)), caret: false)
            .hidden()
            // A middle tail centres on its orb; stacked messages hang from the top and grow down
            // as they type.
            .overlay(alignment: tail == .left ? .leading : .topLeading) {
                BubblePop(id: talk.popID, anchor: UnitPoint(x: -0.05, y: tail == .left ? 0.5 : 0.1)) {
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
            .frame(maxWidth: hug ? nil : .infinity, minHeight: lineHeight, alignment: .leading)
            .padding(.horizontal, padH)
            .padding(.vertical, padV)
            .background(BubbleShape(tail: tail, radius: radius).fill(talk.alt ? EQ.mintAlt : .white))
            .compositingGroup()
            .shadow(color: Color(hex: 0x001E0A).opacity(0.10), radius: 1, y: 0.5)
            .shadow(color: Color(hex: 0x00280F).opacity(0.13), radius: 11, y: 8)
            .animation(.easeInOut(duration: 0.25), value: talk.alt)
            .accessibilityLabel(Catalog.translate(talk.full, to: language.current))
    }
}

/// Re-runs the bubble's pop-in (scale .4 → 1, rising 24 pt, with overshoot) whenever `id` changes,
/// once the orb has landed on this screen.
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
                let wait = max(0, OrbFlight.landing.timeIntervalSinceNow)
                DispatchQueue.main.asyncAfter(deadline: .now() + wait) { withAnimation(EQ.pop(0.55)) { shown = true } }
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
    enum Tail { case bottom, left, topLeft, none }
    var tail: Tail
    var radius: CGFloat = 22

    func path(in r: CGRect) -> Path {
        // Tail and body are unioned so their overlap never cancels out into a seam.
        var p = Path(roundedRect: r, cornerRadius: min(radius, r.height / 2), style: .continuous)
        switch tail {
        // Comic-book pointers: a narrow base, sides curving slightly inward, a sharp tip.
        case .bottom:
            // 24 wide at the bubble, tip 15 below it, pointing straight down at the orb.
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.midX + x, y: r.maxY + y) }
            var t = Path()
            t.move(to: pt(-12, -2))
            t.addQuadCurve(to: pt(0, 15), control: pt(-3, 3))
            t.addQuadCurve(to: pt(12, -2), control: pt(3, 3))
            t.closeSubpath()
            p = p.union(t)
        case .left:
            // 18 tall at the bubble, tip 12 out to the left, pointing at the orb beside it.
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x, y: r.midY + y) }
            var t = Path()
            t.move(to: pt(2, -9))
            t.addQuadCurve(to: pt(-12, 1), control: pt(-3, -2))
            t.addQuadCurve(to: pt(2, 9), control: pt(-3, 3))
            t.closeSubpath()
            p = p.union(t)
        case .topLeft:
            // Off the top-left corner, its sharp tip out to the left near the top.
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x, y: r.minY + y) }
            var t = Path()
            t.move(to: pt(8, 8))
            t.addQuadCurve(to: pt(-14, 4), control: pt(-2, 10))
            t.addQuadCurve(to: pt(6, 26), control: pt(-4, 13))
            t.closeSubpath()
            p = p.union(t)
        case .none:
            break
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

    var body: some View {
        VStack(spacing: 18) {
            TopBubble(talk: talk, reserve: reserve, fontSize: fontSize, lineHeight: lineHeight)
                .modifier(OrbHover(diameter: orbDiameter))
                .zIndex(2)
            OrbSlot(diameter: orbDiameter, spinning: spinning)
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

    var body: some View {
        HStack(spacing: 14) {
            OrbSlot(diameter: 56, rings: rings)
            SideBubble(talk: talk, reserve: reserve, fontSize: fontSize, lineHeight: lineHeight,
                       padH: padH, padV: padV, radius: radius)
                .modifier(OrbHover(diameter: 56))
        }
    }
}
