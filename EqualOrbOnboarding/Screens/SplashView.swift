import SwiftUI

/// Full-green splash. Six dots pop in on a spinning ring, settle into the Equal mark, the lockup
/// slides left as the wordmark wipes in, then the tagline and “made in India” rise.
/// Leaves after 3.8 s (or on tap) — the mark becomes the orb on the first question.
struct SplashView: View {
    @EnvironmentObject var model: AppModel
    @State private var start = Date()
    /// The lockup's laid-out frame (before its slide), used to find the mark when leaving.
    @State private var lockFrame: CGRect = .zero

    // Dot i: start on a ring of radius 34, end on the mark's grid.
    private let radial: [CGPoint] = [CGPoint(x: 0, y: -34), CGPoint(x: 29.4, y: -17), CGPoint(x: 29.4, y: 17),
                                     CGPoint(x: 0, y: 34), CGPoint(x: -29.4, y: 17), CGPoint(x: -29.4, y: -17)]
    private let grid: [CGPoint] = [CGPoint(x: 0, y: -13.3), CGPoint(x: 16.8, y: -13.3), CGPoint(x: 16.8, y: 13.3),
                                   CGPoint(x: 0, y: 13.3), CGPoint(x: -16.8, y: 13.3), CGPoint(x: -16.8, y: -13.3)]

    /// Wordmark is 480 × 101; at 44 pt tall it is 209.1 pt wide and its mark sits 25.5 pt in.
    private let lockW: CGFloat = 209.1
    private let lockH: CGFloat = 44
    private let markX: CGFloat = 25.5

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            ZStack {
                background
                VStack(spacing: 16) {
                    lockup(t)
                    tagline
                        .modifier(IntroUp(p: introP(t, at: 2.45)))
                }
                VStack {
                    Spacer()
                    Text("🇮🇳 Proudly made in India")
                        .font(.dm(12, .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.18)))
                        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                        .modifier(IntroUp(p: introP(t, at: 2.65)))
                        .padding(.bottom, 22)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { leave() }
        .task {
            start = Date()
            guard (try? await Task.sleep(for: .seconds(3.8))) != nil else { return }
            leave()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Equal AI. India’s No. 1 AI Call Assistant.")
        .accessibilityAddTraits(.isButton)
    }

    private var background: some View {
        LinearGradient(stops: [.init(color: Color(hex: 0xBFFF3A), location: 0),
                               .init(color: Color(hex: 0x4ADB45), location: 0.45),
                               .init(color: EQ.green, location: 1)],
                       startPoint: UnitPoint(x: 0.32, y: 0), endPoint: UnitPoint(x: 0.68, y: 1))
            .overlay(
                EllipticalGradient(stops: [.init(color: .white.opacity(0.22), location: 0),
                                           .init(color: .white.opacity(0), location: 0.6)],
                                   center: UnitPoint(x: 0.3, y: 0.2), startRadiusFraction: 0, endRadiusFraction: 0.7)
            )
            .ignoresSafeArea()
    }

    private func lockup(_ t: Double) -> some View {
        let slide = slide(at: t)
        let wipe = bezierEase((t - 1.9) / 0.8, 0.65, 0, 0.35, 1)
        let spin = 360 * bezierEase(t / 1.8, 0.65, 0, 0.35, 1)
        return ZStack(alignment: .topLeading) {
            // Wordmark: the mark part (left 30 %) stays hidden — the dots stand in for it.
            Image("Wordmark")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.white)
                .frame(width: lockW, height: lockH)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: lockW * 0.7 * wipe, height: lockH)
                        .offset(x: lockW * 0.3)
                }
                .opacity(wipe)

            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    let pin = bezierEase((t - Double(i) * 0.06) / 0.45, 0.22, 1, 0.36, 1)
                    let form = bezierEase((t - 0.8) / 1.0, 0.65, 0, 0.35, 1)
                    let x = radial[i].x + (grid[i].x - radial[i].x) * form
                    let y = radial[i].y + (grid[i].y - radial[i].y) * form
                    Circle()
                        .fill(.white)
                        .frame(width: 17.4, height: 17.4)
                        .shadow(color: .white.opacity(0.6 * (1 - form)), radius: 8)
                        .scaleEffect(pin)
                        .opacity(pin)
                        .offset(x: x, y: y)
                }
            }
            .rotationEffect(.degrees(spin))
            .frame(width: 0, height: 0)
            .offset(x: markX, y: lockH / 2)
        }
        .frame(width: lockW, height: lockH, alignment: .topLeading)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { lockFrame = $0 }
        .offset(x: slide)
    }

    private var tagline: some View {
        HStack(spacing: 12) {
            Image("LaurelLeft").resizable().frame(width: 24, height: 48)
            Text("India’s No. 1\nAI Call Assistant")
                .font(.dm(15, .semibold))
                .lineSpacing(1)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Image("LaurelRight").resizable().frame(width: 24, height: 48)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.18)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    private func introP(_ t: Double, at delay: Double) -> Double {
        bezierEase((t - delay) / 0.5, 0.2, 0.8, 0.2, 1)
    }

    private func slide(at t: Double) -> CGFloat {
        79 * (1 - bezierEase((t - 1.85) / 0.8, 0.65, 0, 0.35, 1))
    }

    private func leave() {
        guard model.step == .splash else { return }
        let t = Date().timeIntervalSince(start)
        model.splashMark = CGPoint(x: lockFrame.minX + markX + slide(at: t), y: lockFrame.midY)
        model.arrivingFromSplash = true
        model.direction = 1
        withAnimation(EQ.push(0.76)) { model.step = .phone }
    }
}

private struct IntroUp: ViewModifier {
    var p: Double
    func body(content: Content) -> some View {
        content.opacity(p).offset(y: 12 * (1 - p))
    }
}
