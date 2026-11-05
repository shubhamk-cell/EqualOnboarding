import SwiftUI

/// One orb for the whole flow. Each screen leaves an `OrbSlot` where its orb belongs. When the
/// step changes the stage glides the orb into the new screen's slot; once it has settled, the
/// slot draws it itself, inside the screen's layout, so anything that moves the screen (the
/// keyboard, options pushing it up) moves the orb with its bubble, at the same speed. Both draw
/// the same orb in the same place, so the hand-over can't be seen.
/// Bubbles wait for it to land (`OrbFlight.landing`) before they pop in.
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

/// The space the orb sits in: it reports where it is to the stage and, once the orb has
/// settled there, draws it.
struct OrbSlot: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.flowStep) private var step
    var diameter: CGFloat
    var spinning = false
    var rings = true

    @State private var frame: CGRect = .zero

    var body: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .overlay {
                if model.orbInSlot, step == model.step {
                    OrbBody(spinning: spinning, rings: rings)
                        .scaleEffect(diameter / OrbFlight.base)
                }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(OrbFlight.space)) } action: { r in
                frame = r
                report()
            }
            .onChange(of: spinning) { report() }
            .accessibilityHidden(true)
    }

    private func report() {
        guard step == model.step, frame != .zero else { return }
        model.place(OrbSpot(frame: frame, spinning: spinning, rings: rings))
    }
}

/// Draws the flow's one orb at the current spot.
struct OrbStage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let spot = model.orbSpot, !model.orbInSlot {
            OrbBody(spinning: spot.spinning, rings: spot.rings)
                .scaleEffect(spot.frame.width / OrbFlight.base)
                .position(x: spot.frame.midX, y: spot.frame.midY)
        }
    }
}

/// The orb itself at the stage's base size, with its aura. Tapping or dragging it switches what
/// it says to the next language.
private struct OrbBody: View {
    var spinning: Bool
    var rings: Bool

    var body: some View {
        ZStack {
            OrbAura()
            Orb(diameter: OrbFlight.base, spinning: spinning, rings: rings) { _ in
                Language.shared.next()
            }
        }
    }
}

/// A wide, faint green light around the orb, fading smoothly to nothing well outside it.
/// Sized for the stage's base orb and scaled with it.
struct OrbAura: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let green = Color(hex: 0x2FBF5E)
        Circle()
            .fill(RadialGradient(stops: [
                .init(color: green.opacity(0.22), location: 0),
                .init(color: green.opacity(0.17), location: 0.2),
                .init(color: green.opacity(0.10), location: 0.42),
                .init(color: green.opacity(0.045), location: 0.65),
                .init(color: green.opacity(0.01), location: 0.85),
                .init(color: green.opacity(0), location: 1)
            ], center: .center, startRadius: 0, endRadius: OrbFlight.base * 2.1))
            .frame(width: OrbFlight.base * 4.2, height: OrbFlight.base * 4.2)
            .opacity(reduceTransparency ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
            let hover = (1 - cos(2 * .pi * t / 5)) / 2
            let sway = sin(2 * .pi * t / 10)
            content.offset(x: 1 * k * sway, y: -4 * k * hover)
        }
    }
}
