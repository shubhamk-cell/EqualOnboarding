import SwiftUI

/// Welcome moment: confetti falls, the orb glides in and grows big, sparkles twinkle round it and
/// the bubble types the user's name. After 4.8 s the screen (orb too) grows, blurs and fades into Home.
struct WelcomeView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @State private var popped = false
    @State private var bye = false

    var body: some View {
        let title = Catalog.title(.welcome, name: model.displayName)
        ZStack {
            Confetti()
            VStack(spacing: 18) {
                TopBubble(talk: talk, reserve: title)
                    .modifier(OrbHover(diameter: 162))
                    .zIndex(2)
                ZStack {
                    Twinkles()
                        .opacity(popped ? 1 : 0)
                    OrbSlot(diameter: 162) { _ in talk.playful(Catalog.playful(.welcome)) }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(bye ? 1.06 : 1)
        .blur(radius: bye ? 8 : 0)
        .opacity(bye ? 0 : 1)
        .sensoryFeedback(.success, trigger: popped)
        .task {
            talk.intro(title)
            await OrbFlight.untilLanded()
            withAnimation(.easeOut(duration: 0.6)) { popped = true }
            guard (try? await Task.sleep(for: .seconds(4.8))) != nil else { return }
            withAnimation(EQ.push(0.6)) { bye = true; model.orbLeaving = true }
            guard (try? await Task.sleep(for: .seconds(0.65))) != nil else { return }
            model.exitToHome()
        }
    }
}

/// 46 pieces of confetti falling once, each with its own delay, drift and spin.
struct Confetti: View {
    private struct Piece {
        let x: CGFloat, delay: Double, duration: Double, drift: CGFloat, spin: Double
        let color: Color, w: CGFloat, h: CGFloat, round: Bool
    }
    private let colors: [UInt32] = [0xBAFF29, 0x8CEA35, 0x00B140, 0xFFFFFF, 0xFFC59E, 0x5BC8F5, 0xFFE25C]
    @State private var pieces: [Piece] = []
    @State private var start = Date()

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSince(start)
                Canvas { c, size in
                    for p in pieces {
                        let raw = (t - p.delay) / p.duration
                        guard raw > 0, raw < 1 else { continue }
                        let e = bezierEase(raw, 0.25, 0.6, 0.4, 1)
                        let alpha = raw < 0.85 ? 1 : 1 - (raw - 0.85) / 0.15
                        let x = p.x * size.width + p.drift * e
                        let y = -24 + (size.height * 1.05 + 24) * e
                        var ctx2 = c
                        ctx2.opacity = alpha
                        ctx2.translateBy(x: x, y: y)
                        ctx2.rotate(by: .degrees(p.spin * e))
                        let r = CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)
                        let path = p.round ? Path(ellipseIn: r) : Path(roundedRect: r, cornerRadius: 2)
                        ctx2.fill(path, with: .color(p.color))
                    }
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            pieces = (0..<46).map { i in
                let round = i % 3 == 0
                return Piece(x: .random(in: 0...1), delay: .random(in: 0...1.4), duration: .random(in: 2.4...4.2),
                             drift: .random(in: -40...40), spin: .random(in: -360...360),
                             color: Color(hex: colors[i % colors.count]),
                             w: .random(in: 6...12), h: round ? .random(in: 6...10) : .random(in: 10...18), round: round)
            }
        }
    }
}

/// Eight ✦ sparkles around the orb, each scaling, turning and fading on a 2.2 s loop.
struct Twinkles: View {
    private let spots: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = [
        (-96, -66, 20, 0), (100, -52, 15, 0.3), (-112, 34, 13, 0.6), (108, 58, 19, 0.15),
        (-46, -112, 12, 0.45), (52, -114, 16, 0.75), (-70, 104, 14, 0.9), (76, 108, 12, 0.35)
    ]
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            ZStack {
                ForEach(spots.indices, id: \.self) { i in
                    let s = spots[i]
                    let (scale, turn, alpha) = frame(t - s.delay)
                    Text("✦")
                        .font(.system(size: s.size))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.9), radius: 4)
                        .shadow(color: EQ.lime.opacity(0.8), radius: 7)
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(turn))
                        .opacity(alpha)
                        .offset(x: s.x, y: s.y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Keyframes: 0/100% → scale 0, 0°, 0 · 40% → 1.15, 45°, 1 · 70% → 0.8, 90°, 0.7.
    private func frame(_ t: Double) -> (CGFloat, Double, Double) {
        guard t > 0 else { return (0, 0, 0) }
        let p = t.truncatingRemainder(dividingBy: 2.2) / 2.2
        func mix(_ a: Double, _ b: Double, _ f: Double) -> Double { a + (b - a) * (f * f * (3 - 2 * f)) }
        if p < 0.4 { let f = p / 0.4; return (mix(0, 1.15, f), mix(0, 45, f), mix(0, 1, f)) }
        if p < 0.7 { let f = (p - 0.4) / 0.3; return (mix(1.15, 0.8, f), mix(45, 90, f), mix(1, 0.7, f)) }
        let f = (p - 0.7) / 0.3
        return (mix(0.8, 0, f), mix(90, 0, f), mix(0.7, 0, f))
    }
}
