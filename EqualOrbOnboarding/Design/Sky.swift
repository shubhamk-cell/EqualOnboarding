import SwiftUI
import UIKit

/// The soft, slowly moving sky behind every onboarding screen: an off-white base, six pastel
/// blobs drifting on long alternating loops, a rotating layer of tinted glows, and fine grain.
struct Sky: View {
    /// One drifting blob. Offsets follow the prototype's `fxd` keyframes:
    /// 0% → (0,0)·1, 50% → (50,−40)·1.15, 100% → (−30,50)·0.95, alternating, ease-in-out.
    private struct Blob {
        let color: UInt32, opacity: Double, w: CGFloat, h: CGFloat
        let anchor: (CGSize) -> CGPoint      // top-left from the screen size
        let period: Double
        let reversed: Bool
    }

    private let blobs: [Blob] = [
        Blob(color: 0x3FC46E, opacity: 0.28, w: 340, h: 300, anchor: { _ in CGPoint(x: -90, y: -60) }, period: 22, reversed: false),
        Blob(color: 0x8FD8F7, opacity: 0.26, w: 300, h: 260, anchor: { s in CGPoint(x: s.width + 110 - 300, y: 60) }, period: 27, reversed: true),
        Blob(color: 0xD4FF7A, opacity: 0.34, w: 280, h: 240, anchor: { _ in CGPoint(x: 30, y: 250) }, period: 19, reversed: false),
        Blob(color: 0x7FDCCF, opacity: 0.20, w: 360, h: 260, anchor: { s in CGPoint(x: s.width + 120 - 360, y: 420) }, period: 31, reversed: false),
        Blob(color: 0xFFD6B8, opacity: 0.42, w: 320, h: 260, anchor: { s in CGPoint(x: -100, y: s.height + 60 - 260) }, period: 24, reversed: true),
        Blob(color: 0xC9B8FF, opacity: 0.26, w: 240, h: 200, anchor: { s in CGPoint(x: s.width + 40 - 240, y: s.height - 40 - 200) }, period: 29, reversed: false)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            GeometryReader { g in
                let size = g.size
                ZStack {
                    EQ.page

                    // Rotating glow layer (inset −30%, one turn every 28 s).
                    ZStack {
                        glow(0xBAFF29, 0.28, x: 0.30, y: 0.30, r: 0.40, size: size)
                        glow(0x5BC8F5, 0.22, x: 0.75, y: 0.65, r: 0.35, size: size)
                        glow(0xFFC59E, 0.30, x: 0.40, y: 0.85, r: 0.30, size: size)
                    }
                    .frame(width: size.width * 1.6, height: size.height * 1.6)
                    .rotationEffect(.degrees(t.truncatingRemainder(dividingBy: 28) / 28 * 360))
                    .position(x: size.width / 2, y: size.height / 2)

                    ForEach(blobs.indices, id: \.self) { i in
                        blob(blobs[i], t: t, size: size)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
                .drawingGroup()
            }
        }
        .overlay(Grain().opacity(0.12).blendMode(.overlay))
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func glow(_ hex: UInt32, _ a: Double, x: CGFloat, y: CGFloat, r: CGFloat, size: CGSize) -> some View {
        RadialGradient(colors: [Color(hex: hex).opacity(a), Color(hex: hex).opacity(0)],
                       center: UnitPoint(x: x, y: y), startRadius: 0, endRadius: size.width * 1.6 * r * 0.7)
    }

    private func blob(_ b: Blob, t: Double, size: CGSize) -> some View {
        let (dx, dy, s) = drift(t: t, period: b.period, reversed: b.reversed)
        let o = b.anchor(size)
        // A soft-edged ellipse: equivalent to a 46pt blur, without blurring every frame.
        return Ellipse()
            .fill(EllipticalGradient(stops: [
                .init(color: Color(hex: b.color).opacity(b.opacity), location: 0),
                .init(color: Color(hex: b.color).opacity(b.opacity * 0.85), location: 0.45),
                .init(color: Color(hex: b.color).opacity(0), location: 1)
            ]))
            .frame(width: b.w + 92, height: b.h + 92)
            .scaleEffect(s)
            .position(x: o.x + b.w / 2 + dx, y: o.y + b.h / 2 + dy)
    }

    private func drift(t: Double, period: Double, reversed: Bool) -> (CGFloat, CGFloat, CGFloat) {
        let cycle = t / period
        var f = cycle - floor(cycle)
        let odd = Int(floor(cycle)) % 2 == 1
        if odd != reversed { f = 1 - f }
        func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
        let k0 = (0.0, 0.0, 1.0), k1 = (50.0, -40.0, 1.15), k2 = (-30.0, 50.0, 0.95)
        let (a, b, p) = f < 0.5 ? (k0, k1, ease(f / 0.5)) : (k1, k2, ease((f - 0.5) / 0.5))
        return (CGFloat(a.0 + (b.0 - a.0) * p), CGFloat(a.1 + (b.1 - a.1) * p), CGFloat(a.2 + (b.2 - a.2) * p))
    }
}

/// Fine film grain: a 160pt noise tile generated once and repeated.
struct Grain: View {
    private static let tile: UIImage = {
        let n = 160
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: n, height: n))
        return renderer.image { ctx in
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<(n * n / 3) {
                let x = Int.random(in: 0..<n, using: &rng), y = Int.random(in: 0..<n, using: &rng)
                let v = CGFloat.random(in: 0...1, using: &rng)
                ctx.cgContext.setFillColor(UIColor(white: v, alpha: 1).cgColor)
                ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }()

    var body: some View {
        Image(uiImage: Grain.tile)
            .resizable(resizingMode: .tile)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
