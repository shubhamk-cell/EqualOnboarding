import SwiftUI

/// One orb for the whole flow. Each screen leaves an `OrbSlot` where its orb belongs; the stage
/// draws the single orb there, and when the step changes it glides and resizes into the new
/// screen's slot. Bubbles wait for it to land (`OrbFlight.landing`) before they pop in.
enum OrbFlight {
    /// Coordinate space of the flow container, shared by the slots and the stage.
    static let space = "orbFlow"
    /// Size the orb is drawn at; slots of other sizes scale it, so size changes animate.
    static let base: CGFloat = 128
    static let glide = Animation.spring(response: 0.78, dampingFraction: 0.86)
    /// When the orb settles into the current screen's slot.
    @MainActor static var landing = Date.distantPast

    /// Called on every step change: the orb is on its way.
    @MainActor static func departing() { landing = Date().addingTimeInterval(0.62) }

    /// Suspends until the orb has landed.
    @MainActor static func untilLanded() async {
        let wait = landing.timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
    }
}

/// Where the current screen wants the orb, and how.
struct OrbSpot: Equatable {
    var frame: CGRect
    var spinning: Bool
    var rings: Bool
}

private struct FlowStepKey: EnvironmentKey {
    static let defaultValue: Step? = nil
}

extension EnvironmentValues {
    /// The step a screen was built for. A screen that is leaving keeps its old step, so its
    /// slot stops steering the orb.
    var flowStep: Step? {
        get { self[FlowStepKey.self] }
        set { self[FlowStepKey.self] = newValue }
    }
}

/// An empty space the size of the orb, which reports where it is to the stage.
struct OrbSlot: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.flowStep) private var step
    var diameter: CGFloat
    var spinning = false
    var rings = true
    var onPlay: (OrbPlay) -> Void = { _ in }

    @State private var frame: CGRect = .zero

    var body: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(OrbFlight.space)) } action: { r in
                frame = r
                report()
            }
            .onChange(of: spinning) { report() }
            .accessibilityHidden(true)
    }

    private func report() {
        guard step == model.step, frame != .zero else { return }
        model.orbOnPlay = onPlay
        model.place(OrbSpot(frame: frame, spinning: spinning, rings: rings))
    }
}

/// Draws the flow's one orb at the current spot.
struct OrbStage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let spot = model.orbSpot {
            Orb(diameter: OrbFlight.base, spinning: spot.spinning, rings: spot.rings) { play in
                model.orbOnPlay?(play)
            }
            .scaleEffect(spot.frame.width / OrbFlight.base)
            .position(x: spot.frame.midX, y: spot.frame.midY)
            // Welcome's goodbye: grows, blurs and fades with the screen.
            .scaleEffect(model.orbLeaving ? 1.06 : 1)
            .blur(radius: model.orbLeaving ? 8 : 0)
            .opacity(model.orbLeaving ? 0 : 1)
        }
    }
}

/// Floats a view in step with the orb's idle hover (same clock and curve as `Orb`), so a bubble
/// rides up and down with the orb it belongs to. `diameter` is that orb's size on screen.
struct OrbHover: ViewModifier {
    var diameter: CGFloat

    func body(content: Content) -> some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let k = diameter / 112
            let hover = (1 - cos(2 * .pi * t / 3.6)) / 2
            let sway = sin(2 * .pi * t / 7.2)
            content.offset(x: 2.5 * k * sway, y: -11 * k * hover)
        }
    }
}
