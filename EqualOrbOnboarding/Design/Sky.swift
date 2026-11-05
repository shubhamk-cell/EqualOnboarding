import SwiftUI
import UIKit

/// The calm sky behind every onboarding screen: a pale mint-to-ivory wash with soft green
/// waves flowing in from the corners — a ribbon curling down from the top-right and layered
/// swells rising low along the bottom — while the middle stays quiet so text and buttons keep their
/// contrast. The wave edges breathe slowly and never in step, so they read as liquid.
///
/// Accessibility: Reduce Motion holds the waves still; Reduce Transparency or Increase Contrast
/// swaps the whole thing for a flat, plain background.
struct Sky: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if reduceTransparency || contrast == .increased {
                Color(hex: 0xF5F7F3)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    GeometryReader { g in
                        ZStack {
                            base
                            ForEach(Array(Self.waves.enumerated()), id: \.offset) { _, w in
                                FluidWave(wave: w, t: t)
                                    .fill(LinearGradient(colors: w.colors.map { Color(hex: $0.hex).opacity($0.a) },
                                                         startPoint: w.from, endPoint: w.to))
                                    .blur(radius: w.soft)
                            }
                        }
                        .frame(width: g.size.width, height: g.size.height)
                        .clipped()
                        .drawingGroup()
                    }
                }
                .overlay(Grain().opacity(0.05).blendMode(.overlay))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Pale mint at the top settling into a warm ivory in the middle.
    private var base: some View {
        LinearGradient(stops: [
            .init(color: Color(hex: 0xEEF7EC), location: 0),
            .init(color: Color(hex: 0xF6F9F2), location: 0.45),
            .init(color: Color(hex: 0xF4F8F1), location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    /// Back to front. Edges are given as points (fractions of the screen) that each sway along
    /// their own axis; `closing` points finish the shape along the screen edge.
    static let waves: [FluidWave.Wave] = [
        // Top-right ribbon: a pale band hugging the corner, a lighter one inside it.
        .init(edge: [(0.52, -0.02), (0.70, 0.04), (0.84, 0.11), (0.96, 0.18), (1.04, 0.22)],
              sway: [(0, 10), (-8, 12), (-10, 10), (-8, 12), (0, 10)],
              closing: [(1.04, -0.02)],
              colors: [(0xDDF5C8, 0.35), (0xB4E6A2, 0.32)], from: .topLeading, to: .bottomTrailing,
              period: 14, soft: 2),
        .init(edge: [(0.78, -0.02), (0.88, 0.05), (0.96, 0.10), (1.04, 0.13)],
              sway: [(0, 8), (-8, 10), (-8, 8), (0, 8)],
              closing: [(1.04, -0.02)],
              colors: [(0xC8EEB4, 0.32), (0x86D98A, 0.26)], from: .topLeading, to: .bottomTrailing,
              period: 18, soft: 1.5),
        // Bottom swells: low and pale, staying under the footer.
        .init(edge: [(-0.04, 0.80), (0.24, 0.84), (0.50, 0.90), (0.78, 0.91), (1.04, 0.87)],
              sway: [(0, 12), (0, 14), (0, 10), (0, 14), (0, 12)],
              closing: [(1.04, 1.02), (-0.04, 1.02)],
              colors: [(0xE6F7D6, 0.40), (0xC6EDB4, 0.36)], from: .top, to: .bottom,
              period: 16, soft: 2),
        .init(edge: [(-0.04, 0.88), (0.28, 0.90), (0.58, 0.94), (0.84, 0.95), (1.04, 0.92)],
              sway: [(0, 10), (0, 12), (0, 9), (0, 12), (0, 10)],
              closing: [(1.04, 1.02), (-0.04, 1.02)],
              colors: [(0xBDEAA6, 0.30), (0x86D98A, 0.28)], from: .top, to: .bottom,
              period: 20, soft: 1.5),
    ]
}

/// One fluid band: a smooth curve through swaying points, closed along the screen edge.
struct FluidWave: Shape {
    struct Wave {
        var edge: [(CGFloat, CGFloat)]
        var sway: [(CGFloat, CGFloat)]
        var closing: [(CGFloat, CGFloat)]
        var colors: [(hex: UInt32, a: Double)]
        var from: UnitPoint, to: UnitPoint
        var period: Double
        var soft: CGFloat
    }

    var wave: Wave
    var t: Double

    func path(in r: CGRect) -> Path {
        // Each point drifts on its own phase, so the edge ripples instead of sliding.
        let pts: [CGPoint] = wave.edge.enumerated().map { i, p in
            let phase = 2 * .pi * (t / wave.period) + Double(i) * 1.7
            let k = CGFloat(sin(phase))
            return CGPoint(x: r.width * p.0 + wave.sway[i].0 * k,
                           y: r.height * p.1 + wave.sway[i].1 * CGFloat(sin(phase * 0.8 + 0.6)))
        }
        var path = Path()
        path.move(to: pts[0])
        // Catmull-Rom through the points, as cubic Béziers, for a smooth liquid edge.
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        for c in wave.closing { path.addLine(to: CGPoint(x: r.width * c.0, y: r.height * c.1)) }
        path.closeSubpath()
        return path
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
