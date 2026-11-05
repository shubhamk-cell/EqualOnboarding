import SwiftUI

enum OrbPlay { case tap, drag }

/// The green orb with the Equal mark: a matte top-lit green ball (matched to the design),
/// a lime halo and a soft ground shadow.
///
/// Idle: floats gently up and down on a 5 s loop, drifting a touch sideways, with ripples spreading
/// out every 1.4 s.
/// Tap: jelly squish, a ripple ring, nine lime sparkles and a wave through the dots.
/// Drag: stretches on a rubber band (with a little 3D tilt) and springs back on release.
/// `spinning`: the six dots gather into a ring and revolve while Equal “thinks”.
///
/// Laid out as a `diameter`-sized square; glow and shadow spill outside it.
struct Orb: View {
    var diameter: CGFloat = 112
    var spinning = false
    var rings = true
    var interactive = true
    var onPlay: (OrbPlay) -> Void = { _ in }

    @State private var drag: CGSize = .zero
    @State private var raw: CGSize = .zero
    @State private var dragging = false
    @State private var taps = 0
    @State private var releases = 0
    @State private var bursts: [Burst] = []

    private var k: CGFloat { diameter / 112 }

    struct Burst: Identifiable {
        let id = UUID()
        let start = Date()
        let angles = (0..<9).map { Double($0) / 9 * .pi * 2 + .random(in: 0...0.4) }
        let distances = (0..<9).map { _ in Double.random(in: 70...100) }
        let sizes = (0..<9).map { _ in Double.random(in: 0.6...1.5) }
        let durations = (0..<9).map { _ in Double.random(in: 0.7...1.0) }
    }

    struct Jelly { var sx: CGFloat = 1; var sy: CGFloat = 1 }

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let hover = (1 - cos(2 * .pi * t / 5)) / 2          // 0 → 1 → 0 every 5 s
            let sway = sin(2 * .pi * t / 10)                    // slow side-to-side drift
            ZStack {
                glow
                    .position(x: diameter / 2, y: diameter / 2)
                ground(hover, sway)
                    .position(x: diameter / 2, y: 121 * k)
                if rings { ripples(t).position(x: diameter / 2, y: diameter / 2) }
                glassBody(t)
                    .position(x: diameter / 2, y: diameter / 2)
                sparks(ctx.date)
                    .position(x: diameter / 2, y: diameter / 2)
            }
            .frame(width: diameter, height: diameter)
            .offset(x: 1 * k * sway, y: -4 * k * hover)
            .offset(drag)
        }
        .contentShape(Circle())
        .gesture(gesture, including: interactive ? .all : .none)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.75), trigger: taps)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.5), trigger: releases)
        .accessibilityElement()
        .accessibilityLabel("Equal AI")
        .accessibilityHint(interactive ? "Tap or drag to play" : "")
        .accessibilityAction { tap() }
    }

    // MARK: Layers

    /// Lime halo behind the glass.
    private var glow: some View {
        Circle()
            .fill(RadialGradient(stops: [
                .init(color: Color(hex: 0x7AFF5B).opacity(0.5), location: 0),
                .init(color: Color(hex: 0x23EF68).opacity(0.32), location: 0.43),
                .init(color: Color(hex: 0x11E15A).opacity(0), location: 0.74)
            ], center: .center, startRadius: 0, endRadius: 88 * k))
            .frame(width: 176 * k, height: 176 * k)
            .blur(radius: 12 * k)
            .opacity(0.85)
            .allowsHitTesting(false)
    }

    /// Soft green shadow on the “ground”, shrinking as the orb rises.
    private func ground(_ hover: Double, _ sway: Double) -> some View {
        Ellipse()
            .fill(Color(hex: 0x09B643).opacity(0.18))
            .frame(width: 70 * k, height: 10 * k)
            .blur(radius: 6 * k)
            .scaleEffect(1 - 0.28 * hover)
            .opacity(1 - 0.4 * hover)
            .offset(x: -1 * k * sway, y: 4 * k * hover)   // stays on the ground while the orb floats
            .allowsHitTesting(false)
    }

    /// Three ripples, 4.2 s each, staggered by 1.4 s.
    private func ripples(_ t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let raw = (t - Double(i) * 1.4).truncatingRemainder(dividingBy: 4.2) / 4.2
                let p = raw < 0 ? raw + 1 : raw
                let e = bezierEase(p, 0.2, 0.6, 0.3, 1)
                let a = p < 0.12 ? 0.42 * (p / 0.12) : 0.42 * (1 - (p - 0.12) / 0.88)
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(1 + 0.42 * e)
                    .opacity(a)
            }
        }
        .allowsHitTesting(false)
    }

    private func glassBody(_ t: Double) -> some View {
        let stretch = min(0.14, hypot(raw.width, raw.height) / 900)
        let angle = Angle(radians: atan2(raw.height, raw.width))
        return ZStack {
            // Matte green, lit from the top left: yellow-green → green → deep green
            // (sampled from the design's orb).
            Circle().fill(LinearGradient(stops: [
                .init(color: Color(hex: 0x7BE040), location: 0),
                .init(color: Color(hex: 0x5AD646), location: 0.3),
                .init(color: Color(hex: 0x3ACC49), location: 0.55),
                .init(color: Color(hex: 0x00BD4F), location: 1)
            ], startPoint: UnitPoint(x: 0.35, y: 0), endPoint: UnitPoint(x: 0.62, y: 1)))

            MarkDots(spinning: spinning, hop: taps)
                .frame(width: 48 * k, height: 39 * k)
                .opacity(0.92)
                .shadow(color: Color(hex: 0x093421).opacity(0.22), radius: 1.5 * k, y: 1 * k)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .shadow(color: Color(hex: 0x09B643).opacity(0.3), radius: 11 * k, y: 12 * k)
        // Drag: tilt toward the finger, stretch along the pull.
        .rotationEffect(-angle)
        .scaleEffect(x: 1 + stretch, y: 1 - stretch * 0.7)
        .rotationEffect(angle)
        .rotation3DEffect(.degrees(Double(drag.width) * 0.35), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(Double(-drag.height) * 0.35), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        // Tap: jelly squish over 720 ms.
        .keyframeAnimator(initialValue: Jelly(), trigger: taps) { c, v in
            c.scaleEffect(x: v.sx, y: v.sy)
        } keyframes: { _ in
            KeyframeTrack(\.sx) {
                CubicKeyframe(1.14, duration: 0.16)
                CubicKeyframe(0.9, duration: 0.16)
                CubicKeyframe(1.05, duration: 0.16)
                CubicKeyframe(1, duration: 0.24)
            }
            KeyframeTrack(\.sy) {
                CubicKeyframe(0.86, duration: 0.16)
                CubicKeyframe(1.1, duration: 0.16)
                CubicKeyframe(0.96, duration: 0.16)
                CubicKeyframe(1, duration: 0.24)
            }
        }
    }

    /// Ripple ring + lime sparkles for each tap.
    private func sparks(_ now: Date) -> some View {
        ZStack {
            ForEach(bursts) { b in
                let el = now.timeIntervalSince(b.start)
                let rp = min(1, el / 0.8)
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(1 + 0.75 * bezierEase(rp, 0.2, 0.7, 0.3, 1))
                    .opacity(0.8 * (1 - rp))
                ForEach(0..<9, id: \.self) { i in
                    let p = min(1, el / b.durations[i])
                    let e = bezierEase(p, 0.15, 0.7, 0.3, 1)
                    Circle()
                        .fill(RadialGradient(stops: [.init(color: .white, location: 0),
                                                     .init(color: Color(hex: 0xD9FF7A), location: 0.45),
                                                     .init(color: Color(hex: 0xBAFF29).opacity(0), location: 0.75)],
                                             center: .center, startRadius: 0, endRadius: 4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(b.sizes[i] * (1 - e))
                        .offset(x: cos(b.angles[i]) * b.distances[i] * e * k, y: sin(b.angles[i]) * b.distances[i] * e * k)
                        .opacity(1 - p)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Interaction

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                let t = v.translation
                guard dragging || hypot(t.width, t.height) > 6 else { return }
                dragging = true
                func band(_ x: CGFloat) -> CGFloat { x * 0.55 / (1 + abs(x) / 220) }
                raw = t
                drag = CGSize(width: band(t.width), height: band(t.height))
            }
            .onEnded { _ in
                if dragging {
                    dragging = false
                    releases += 1
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.42)) {
                        drag = .zero
                        raw = .zero
                    }
                    onPlay(.drag)
                } else {
                    tap()
                }
            }
    }

    private func tap() {
        taps += 1
        let b = Burst()
        bursts.append(b)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { bursts.removeAll { $0.id == b.id } }
        onPlay(.tap)
    }
}

/// The six-dot Equal mark (60 × 49 view box, r = 10). When `spinning`, the dots shrink into a
/// ring of radius 23 and the ring revolves once every 1.3 s; when it stops, the ring winds back
/// to upright while the dots return to the grid. `hop` ripples a little wave through the dots.
struct MarkDots: View {
    var spinning: Bool
    var hop: Int = 0

    @State private var spinStart: Date?
    @State private var stopAt: Date?
    @State private var stopAngle: Double = 0

    private static let grid: [CGPoint] = [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 10), CGPoint(x: 50, y: 10),
                                          CGPoint(x: 10, y: 39), CGPoint(x: 30, y: 39), CGPoint(x: 50, y: 39)]
    private static let ring: [CGPoint] = (0..<6).map { i in
        let a = (Double(i) * 60 - 90) * .pi / 180
        return CGPoint(x: 30 + 23 * cos(a), y: 24.5 + 23 * sin(a))
    }

    struct Hop { var y: CGFloat = 0; var s: CGFloat = 1 }

    var body: some View {
        GeometryReader { g in
            let sx = g.size.width / 60, sy = g.size.height / 49
            TimelineView(.animation(minimumInterval: nil, paused: spinStart == nil && stopAt == nil)) { ctx in
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        let p = spinning ? Self.ring[i] : Self.grid[i]
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20 * sx, height: 20 * sx)
                            .keyframeAnimator(initialValue: Hop(), trigger: hop) { c, v in
                                c.offset(y: v.y * sy).scaleEffect(v.s)
                            } keyframes: { _ in
                                let delay = Double(i % 3) * 0.07 + Double(i / 3) * 0.04
                                KeyframeTrack(\.y) {
                                    LinearKeyframe(0, duration: delay)
                                    CubicKeyframe(-4, duration: 0.17)
                                    CubicKeyframe(0, duration: 0.25)
                                }
                                KeyframeTrack(\.s) {
                                    LinearKeyframe(1, duration: delay)
                                    CubicKeyframe(1.12, duration: 0.17)
                                    CubicKeyframe(1, duration: 0.25)
                                }
                            }
                            .scaleEffect(spinning ? 0.56 : 1)
                            .position(x: p.x * sx, y: p.y * sy)
                            .animation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.55), value: spinning)
                    }
                }
                .rotationEffect(.degrees(angle(at: ctx.date)), anchor: UnitPoint(x: 0.5, y: 24.5 / 49))
            }
        }
        .onChange(of: spinning, initial: true) { _, on in
            if on {
                spinStart = Date(); stopAt = nil
            } else if let s = spinStart {
                stopAngle = runningAngle(since: s, now: Date()).truncatingRemainder(dividingBy: 360)
                spinStart = nil
                stopAt = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if spinStart == nil { stopAt = nil } }
            }
        }
    }

    private func runningAngle(since s: Date, now: Date) -> Double {
        max(0, now.timeIntervalSince(s) - 0.45) * 360 / 1.3
    }

    private func angle(at now: Date) -> Double {
        if let s = spinStart { return runningAngle(since: s, now: now) }
        if let s = stopAt {
            let p = min(1, now.timeIntervalSince(s) / 0.55)
            let e = 1 - pow(1 - p, 3)
            return stopAngle + (360 - stopAngle) * e
        }
        return 0
    }
}

/// CSS `cubic-bezier(x1,y1,x2,y2)` evaluated at progress `x` (Newton iterations on x(t)).
func bezierEase(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
    guard x > 0 else { return 0 }
    guard x < 1 else { return 1 }
    func bx(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t }
    func by(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t }
    func dx(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * x1 + 6 * (1 - t) * t * (x2 - x1) + 3 * t * t * (1 - x2) }
    var t = x
    for _ in 0..<6 {
        let d = dx(t)
        if abs(d) < 1e-6 { break }
        t -= (bx(t) - x) / d
        t = min(1, max(0, t))
    }
    return by(t)
}
