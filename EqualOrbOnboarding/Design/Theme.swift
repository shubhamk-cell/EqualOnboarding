import SwiftUI

/// Equal AI brand tokens for the orb-bubble onboarding.
enum EQ {
    static let green = Color(hex: 0x00B140)
    static let greenDeep = Color(hex: 0x00843A)
    static let greenText = Color(hex: 0x00602A)
    static let greenPress = Color(hex: 0x00A33B)
    static let lime = Color(hex: 0xBAFF29)
    static let voiceTop = Color(hex: 0x8CEA35)
    static let mint = Color(hex: 0xE8FFED)
    static let mintAlt = Color(hex: 0xE9FCEC)
    static let ink = Color(hex: 0x0B1F12)
    static let page = Color(hex: 0xF7F7F7)
    static let secondary = Color(hex: 0x555555)
    static let placeholder = Color(hex: 0xAAAAAA)
    static let hair = Color.black.opacity(0.08)

    /// The iOS push curve every screen change uses: cubic-bezier(.32,.72,0,1).
    static func push(_ duration: Double = 0.56) -> Animation { .timingCurve(0.32, 0.72, 0, 1, duration: duration) }
    /// The house ease: cubic-bezier(.2,0,0,1).
    static func ease(_ duration: Double) -> Animation { .timingCurve(0.2, 0, 0, 1, duration: duration) }
    /// Overshooting pop used by the speech bubble: cubic-bezier(.32,1.25,.5,1).
    static func pop(_ duration: Double = 0.55) -> Animation { .timingCurve(0.32, 1.25, 0.5, 1, duration: duration) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension Font {
    /// DM Sans (variable) – the only typeface in this flow. Optical size follows the point size,
    /// as browsers do, so letterforms match the prototype.
    static func dm(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font(DMSans.font(size, weight))
    }
}

enum DMSans {
    private static let cache = NSCache<NSString, UIFont>()
    private static let opsz = 0x6F70_737A   // 'opsz'
    private static let wght = 0x7767_6874   // 'wght'

    static func font(_ size: CGFloat, _ weight: Font.Weight) -> UIFont {
        let w: CGFloat
        switch weight {
        case .ultraLight: w = 200
        case .thin: w = 250
        case .light: w = 300
        case .medium: w = 500
        case .semibold: w = 600
        case .bold: w = 700
        case .heavy: w = 800
        case .black: w = 900
        default: w = 400
        }
        let key = "\(size)-\(w)" as NSString
        if let f = cache.object(forKey: key) { return f }
        let variations: [Int: CGFloat] = [opsz: min(40, max(9, size)), wght: w]
        let d = UIFontDescriptor(fontAttributes: [
            .family: "DM Sans",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations
        ])
        let f = UIFont(descriptor: d, size: size)
        cache.setObject(f, forKey: key)
        return f
    }
}

/// `**bold**` runs set in a heavier DM Sans weight; everything else in the base weight.
func rich(_ s: String, size: CGFloat, weight: Font.Weight = .regular, bold: Font.Weight = .semibold) -> Text {
    s.components(separatedBy: "**").enumerated().reduce(Text("")) { out, part in
        out + Text(part.element).font(.dm(size, part.offset % 2 == 1 ? bold : weight))
    }
}

// MARK: - Surfaces

/// Frosted glass used for fields, chips and small buttons.
struct Glass<S: Shape>: ViewModifier {
    var shape: S
    var tint: Double = 0.55
    var stroke: Color = .white.opacity(0.75)
    var shadow: Bool = true
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .background(Color.white.opacity(tint), in: shape)
            .overlay(shape.stroke(stroke, lineWidth: 1))
            .shadow(color: Color(hex: 0x003214).opacity(shadow ? 0.08 : 0), radius: 10, y: 6)
    }
}

extension View {
    func glass<S: Shape>(_ shape: S, tint: Double = 0.55, stroke: Color = .white.opacity(0.75), shadow: Bool = true) -> some View {
        modifier(Glass(shape: shape, tint: tint, stroke: stroke, shadow: shadow))
    }
}

// MARK: - Buttons

/// Big green pill (60pt). Disabled: washed-out green, no shadow.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var enabled
    var lookEnabled = false
    func makeBody(configuration: Configuration) -> some View {
        let on = enabled || lookEnabled
        configuration.label
            .font(.dm(18, .semibold))
            .tracking(-0.18)
            .foregroundStyle(.white.opacity(on ? 1 : 0.75))
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Capsule().fill(on ? EQ.green : EQ.green.opacity(0.38)))
            .shadow(color: Color(hex: 0x00782D).opacity(on ? 0.3 : 0), radius: 12, y: 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.25), value: on)
    }
}

/// Generic press feedback for custom-drawn buttons.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Low-key text link (“I’ll do this later”).
struct LinkButtonStyle: ButtonStyle {
    var color: Color = EQ.ink.opacity(0.65)
    var size: CGFloat = 15
    var weight: Font.Weight = .medium
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dm(size, weight))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Haptics

/// The app's whole haptic vocabulary. Every interaction uses one of these, so the same kind of
/// moment always feels the same:
/// - `step`: moving through the flow — next, back, skip, opening or closing a sheet, a CTA.
/// - `select`: choosing — picks, toggles, checkboxes, a language, a sample call, a tab.
/// - `success`: something finished well — code verified, code copied, carrier confirmed,
///   permissions granted, setup done, welcome.
/// - `warning`: something needs attention — a permission was refused.
/// - `land`: a soft settle when something arrives — the curated cards, the orb docking on Home.
/// (The orb's own squish and rubber-band release live in `Orb`.)
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func step() { light.impactOccurred(intensity: 0.7) }
    static func select() { selection.selectionChanged() }
    static func success() { notification.notificationOccurred(.success) }
    static func warning() { notification.notificationOccurred(.warning) }
    static func land() { soft.impactOccurred(intensity: 0.6) }
}

/// 48pt frosted circle with a chevron (back).
struct BackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(EQ.ink)
                .frame(width: 48, height: 48)
                .glass(Circle(), tint: 0.28, stroke: .white.opacity(0.45))
                .shadow(color: Color(hex: 0x00280F).opacity(0.12), radius: 7, y: 4)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Back")
    }
}

/// 48pt frosted circle with a cross (leave the onboarding).
struct CloseButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(EQ.ink)
                .frame(width: 48, height: 48)
                .glass(Circle(), tint: 0.28, stroke: .white.opacity(0.45))
                .shadow(color: Color(hex: 0x00280F).opacity(0.12), radius: 7, y: 4)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Close")
    }
}

/// Frosted “Skip” capsule.
struct SkipButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Skip")
                .font(.dm(15, .semibold))
                .foregroundStyle(EQ.ink.opacity(0.7))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .glass(Capsule(), tint: 0.42, stroke: .white.opacity(0.6), shadow: false)
        }
        .buttonStyle(PressStyle(scale: 0.96))
    }
}

// MARK: - Motion helpers

/// Rises in from below with a fade, after a delay (used for content arriving from the splash).
struct RiseIn: ViewModifier {
    var active: Bool
    var delay: Double
    var distance: CGFloat = 26
    var duration: Double = 0.7
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(!active || shown ? 1 : 0)
            .offset(y: !active || shown ? 0 : distance)
            .onChange(of: active, initial: true) { _, on in
                guard on, !shown else { return }
                withAnimation(EQ.push(duration).delay(delay)) { shown = true }
            }
    }
}

extension View {
    func riseIn(_ active: Bool, delay: Double, distance: CGFloat = 26, duration: Double = 0.7) -> some View {
        modifier(RiseIn(active: active, delay: delay, distance: distance, duration: duration))
    }
}

/// Little bounce used when a tick or digit lands (mkPop: 1 → 1.14 → 1).
struct PopOnChange<V: Equatable>: ViewModifier {
    var value: V
    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(1), trigger: value) { c, s in
            c.scaleEffect(s)
        } keyframes: { _ in
            CubicKeyframe(1.14, duration: 0.13)
            CubicKeyframe(1, duration: 0.17)
        }
    }
}

extension View {
    func popOnChange<V: Equatable>(of value: V) -> some View { modifier(PopOnChange(value: value)) }
}

/// The Equal mark rendered from the wordmark is a template image; this is its brand-green version.
struct Wordmark: View {
    var height: CGFloat = 24
    var color: Color = EQ.green
    var body: some View {
        Image("Wordmark")
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(color)
            .aspectRatio(480 / 101, contentMode: .fit)
            .frame(height: height)
            .accessibilityLabel("equal ai")
    }
}
