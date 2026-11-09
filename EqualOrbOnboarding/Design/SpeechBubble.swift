import SwiftUI

import Combine

/// What the orb is saying in its bubble. Like a chat message: a bubble pops in with the typing
/// dots, then a new bubble pops in with the whole line.
/// Every line takes a fresh token, so a newer one silently stops an older one mid-way.
/// Lines are given in English and shown in `Language.shared.current`; when the language changes,
/// the bubble swaps its line for the new language's.
@MainActor
final class Talk: ObservableObject {
    @Published var text = ""
    /// The line the bubble rests on, in English.
    @Published var full = ""
    /// True from the dots until the line is showing; screens wait for it to fall to move on.
    @Published var typing = false
    /// The three typing dots, shown for a beat before a line appears.
    @Published var thinking = false
    /// Mint fill while the bubble switches language.
    @Published var alt = false
    /// Bumps each time the bubble should pop in again.
    @Published var popID = 0
    /// The bubble has shrunk back into its orb, between one message and the next. A message never
    /// leaves sideways: it goes back into the orb, and the next one comes out of it.
    @Published var out = false
    /// The first line has shown. Everything else on the page waits for this (`afterOrb`).
    @Published var said = false

    private var token = 0
    private var languageSub: AnyCancellable?
    private var switchTask: Task<Void, Never>?

    init() {
        languageSub = Language.shared.$current.dropFirst().removeDuplicates().sink { [weak self] _ in
            self?.retype()
        }
    }

    /// How long the typing dots show before a line appears.
    static let thinkingTime = 0.8

    /// Pops the bubble in with the typing dots (once the orb has landed), then shows `line`.
    func intro(_ line: String, delay: Double = 0.42) {
        full = line
        text = ""
        thinking = true
        typing = true
        out = false
        popID += 1
        token += 1
        let my = token
        Task {
            await OrbFlight.untilLanded()
            try? await Task.sleep(for: .seconds(delay + Self.thinkingTime))
            guard my == token else { return }
            await show(line)
        }
    }

    /// Shows the typing dots for a beat, then `line`. Returns false if something newer took over.
    @discardableResult
    func say(_ line: String) async -> Bool {
        guard await think() else { return false }
        let my = token
        try? await Task.sleep(for: .seconds(Self.thinkingTime))
        guard my == token else { return false }
        return await show(line)
    }

    /// Whatever is showing goes back into the orb, and the typing dots come out of it (until a line
    /// follows with `show`). Returns false if something newer took over.
    @discardableResult
    func think() async -> Bool {
        token += 1
        let my = token
        // Already showing the dots (a screen can put them up itself): keep them, rather than send
        // them back into the orb only to bring out another set.
        if thinking, !out {
            typing = true
            return true
        }
        guard await leave(my) else { return false }
        text = ""
        typing = true
        thinking = true
        out = false
        popID += 1
        return true
    }

    /// Shows `line` in full, replacing whatever is there. Returns false if something newer took over.
    /// `leaving: false` swaps the line in place (a language switch) instead of going via the orb.
    @discardableResult
    func show(_ line: String, leaving: Bool = true) async -> Bool {
        token += 1
        let my = token
        // The dots (or the old line) shrink back into the orb, and a fresh bubble comes out of it
        // with the whole line.
        if leaving { guard await leave(my) else { return false } }
        thinking = false
        text = Catalog.translate(line, to: Language.shared.current)
        out = false
        popID += 1
        // Let the bubble settle before anything waiting on the line moves on.
        try? await Task.sleep(for: .seconds(0.4))
        guard my == token else { return false }
        typing = false
        said = true
        return true
    }

    /// Takes the bubble away, back into the orb. Returns false if something newer took over.
    @discardableResult
    func clear() async -> Bool {
        token += 1
        let my = token
        guard await leave(my) else { return false }
        text = ""
        thinking = false
        return my == token
    }

    /// The bubble on show shrinks and fades back into its orb. Returns false if something newer
    /// took over meanwhile.
    private func leave(_ my: Int) async -> Bool {
        guard !out, thinking || !text.isEmpty else { return my == token }
        withAnimation(.easeIn(duration: 0.18)) { out = true }
        try? await Task.sleep(for: .seconds(0.2))
        return my == token
    }

    /// Clear, then say a new resting line (dots first).
    func replace(with line: String) async {
        full = line
        guard await clear() else { return }
        await say(line)
    }

    /// The language changed: swap the resting line for the new language's (mint meanwhile).
    /// A bubble that hasn't started talking yet picks up the language when it does.
    private func retype() {
        guard !full.isEmpty, !text.isEmpty else { return }
        switchTask?.cancel()
        switchTask = Task {
            // Runs after the change has landed, so `show` reads the new language.
            alt = true
            guard await show(full, leaving: false), !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            alt = false
        }
    }
}

// MARK: - Bubble views

/// White speech bubble that rises out of the orb, tail pointing down at it.
/// It hugs its content (dots, then the line); the row reserves room for the full line up front
/// so the line appearing never shifts the page.
struct TopBubble: View {
    @ObservedObject var talk: Talk
    @ObservedObject private var language = Language.shared
    var reserve: String
    var fontSize: CGFloat = 18
    var lineHeight: CGFloat = 23
    var maxWidth: CGFloat = 300

    var body: some View {
        bubble(Text(Catalog.translate(reserve, to: language.current)))
            .hidden()
            .frame(maxWidth: maxWidth)
            .overlay(alignment: .bottom) {
                BubblePop(id: talk.popID, away: talk.out) {
                    bubble(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
    }

    private func bubble(_ text: Text?) -> some View {
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
        bubble(Text(Catalog.translate(reserve, to: language.current)))
            .hidden()
            // A middle tail centres on its orb; stacked messages hang from the top and grow down
            // as they type.
            .overlay(alignment: tail == .left ? .leading : .topLeading) {
                BubblePop(id: talk.popID, away: talk.out, anchor: UnitPoint(x: -0.05, y: tail == .left ? 0.5 : 0.1), from: .leading) {
                    bubble(nil)
                }
            }
    }

    private func bubble(_ text: Text?) -> some View {
        TypedText(talk: talk, fixed: text, fontSize: fontSize)
            .font(.dm(fontSize, .semibold))
            .tracking(-0.02 * fontSize)
            .lineSpacing(lineHeight - fontSize * 1.2)
            .foregroundStyle(EQ.ink)
            .multilineTextAlignment(.leading)
            // While the dots show, the bubble hugs them rather than stretching across.
            .frame(maxWidth: hug || (text == nil && talk.thinking) ? nil : .infinity, minHeight: lineHeight, alignment: .leading)
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

/// Pops a bubble in, out of its orb, whenever `id` changes (once the orb has landed): it scales
/// up from small, slides away from the orb and fades from nothing. `from` is the orb's side —
/// below the bubble for the big orb, to its left for the small one.
/// `away` (or the page about to change) sends it back the same way: it shrinks and fades into the
/// orb. A new `id` then brings the next bubble out fresh.
struct BubblePop<Content: View>: View {
    var id: Int
    var away = false
    var anchor = UnitPoint(x: 0.42, y: 1.2)
    var from: Edge = .bottom
    @ViewBuilder var content: Content
    @State private var shown = false
    /// The id this pop has run for; until onChange catches up with a new id, stay hidden.
    @State private var seen: Int?
    @ObservedObject private var stage = BubbleStage.shared

    var body: some View {
        let on = shown && seen == id && !away && !stage.away
        content
            .scaleEffect(on ? 1 : 0.3, anchor: anchor)
            .offset(x: on || from != .leading ? 0 : -22, y: on || from != .bottom ? 0 : 22)
            .opacity(on ? 1 : 0)
            .onChange(of: id, initial: true) { _, new in
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { shown = false; seen = new }
                let wait = max(0, OrbFlight.landing.timeIntervalSinceNow)
                DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                    guard seen == new else { return }
                    withAnimation(EQ.pop(0.5)) { shown = true }
                }
            }
    }
}

/// Bubbles everywhere step back into their orbs while the page changes, so the outgoing page's
/// message never slides off sideways with it.
@MainActor
final class BubbleStage: ObservableObject {
    static let shared = BubbleStage()
    @Published var away = false
}

/// The bubble's text: either a fixed line (used invisibly to reserve space), the typing dots,
/// or the line itself.
private struct TypedText: View {
    @ObservedObject var talk: Talk
    var fixed: Text?
    var fontSize: CGFloat
    var body: some View {
        if let fixed {
            fixed
        } else if talk.thinking {
            TypingDots(size: fontSize * 0.36)
                .transition(.opacity)
        } else {
            Text(talk.text)
        }
    }
}

/// The standard “someone is typing” dots: three dots rising and brightening in turn.
struct TypingDots: View {
    var size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: size * 0.7) {
                ForEach(0..<3, id: \.self) { i in
                    // Each dot pulses on a 1.2 s loop, a fifth of a loop after the one before.
                    let phase = (t / 1.2 - Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
                    let p = reduceMotion ? 0.5 : max(0, sin(.pi * min(phase < 0 ? phase + 1 : phase, 0.5) * 2))
                    Circle()
                        .fill(EQ.ink.opacity(0.28 + 0.4 * p))
                        .frame(width: size, height: size)
                        .offset(y: -size * 0.45 * p)
                }
            }
            .padding(.vertical, size * 0.5)
        }
        .accessibilityLabel("Typing")
    }
}

/// Rounded bubble with an organic tail: under the middle (orb below) or on the left (orb beside).
struct BubbleShape: Shape {
    enum Tail { case bottom, left, topLeft, topRight, none }
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
        case .topRight:
            // The user's side: `topLeft` mirrored, its tip out to the right near the top.
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.maxX - x, y: r.minY + y) }
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
        // As on the permissions screen: the bubble hangs from the orb's top, its pointer on the
        // top-left corner, and hugs its text (wrapping when it runs long).
        HStack(alignment: .top, spacing: 14) {
            OrbSlot(diameter: 56, rings: rings)
            SideBubble(talk: talk, reserve: reserve, fontSize: fontSize, lineHeight: lineHeight,
                       padH: padH, padV: padV, radius: radius, tail: .topLeft, hug: true)
                .modifier(OrbHover(diameter: 56))
            Spacer(minLength: 0)
        }
    }
}
