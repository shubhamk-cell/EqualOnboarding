import SwiftUI

/// The background behind every onboarding screen: plain white with Equal's doodle
/// pattern over the top, barely there and fading away down the screen.
///
/// Accessibility: Reduce Transparency or Increase Contrast drops the doodles.
struct Sky: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                Color.white
                if !reduceTransparency, contrast != .increased {
                    doodles(g.size)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Equal's doodle pattern, faint at the top and gone by the middle of the screen.
    private func doodles(_ size: CGSize) -> some View {
        Image("Doodles")
            .renderingMode(.template)
            .foregroundStyle(Color(hex: 0x0B5A3A).opacity(0.06))
            .frame(width: size.width, height: size.height * 0.6, alignment: .top)
            .clipped()
            .mask {
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.55), location: 0.35),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
    }
}
