import SwiftUI

/// Stages the app: the green splash, the onboarding flow on its moving sky, and Home.
/// Modal surfaces (consent, decline sheets, carrier reply, mock Settings) and the toast sit on top.
struct RootView: View {
    @EnvironmentObject var model: AppModel

    private var onSky: Bool { model.step != .splash && model.step != .home }

    var body: some View {
        ZStack {
            Sky()
                .opacity(onSky ? 1 : 0)
                .animation(.easeInOut(duration: 0.45), value: onSky)

            switch model.step {
            case .splash:
                SplashView()
                    .transition(.splashOut)
                    .zIndex(3)
            case .home:
                HomeView()
                    .transition(.homeIn)
                    .zIndex(1)
            default:
                FlowContainer()
                    .transition(.identity)
                    .zIndex(2)
            }

            OverlayHost()
                .zIndex(10)

            if let t = model.toast {
                ToastView(text: t)
                    .transition(.scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: 8)))
                    .zIndex(20)
            }
        }
        .preferredColorScheme(model.step == .splash ? .dark : .light)
    }
}

/// The onboarding screens: a fixed top bar (back / skip) over the current screen, which pushes
/// in from the side. The orb isn't part of the screens: one shared orb glides between them.
struct FlowContainer: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ZStack {
                screen
                    .environment(\.flowStep, model.step)
                    .id(model.step)
                    .transition(model.arrivingFromSplash && model.step == .phone ? .identity : .push(model.direction))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Behind the screens: the shared orb, and under it a catcher that puts the keyboard
        // away when you tap anything that isn't a control (the sky, empty space).
        .background {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                OrbStage()
            }
        }
        .coordinateSpace(.named(OrbFlight.space))
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { model.flowOrigin = $0 }
    }

    @ViewBuilder private var screen: some View {
        switch model.step {
        case .phone: PhoneView()
        case .otp: OTPView()
        case .name: NameView()
        case .cases: CasesView()
        case .permq: PermissionsView()
        case .fwd: ForwardingView()
        case .access: VoicemailView()
        case .welcome: WelcomeView()
        default: EmptyView()
        }
    }
}

/// Back on the left, Skip on the right. Swaps instantly (it doesn't slide with the screen).
private struct TopBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack {
            if model.step.hasBack {
                BackButton { model.back() }
            } else {
                Color.clear.frame(width: 48, height: 48)
            }
            Spacer()
            if model.step.skippable {
                SkipButton { model.skip() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .frame(height: 58, alignment: .bottom)
        .transaction { $0.animation = nil }
        .riseIn(model.arrivingFromSplash && model.step == .phone, delay: 0.35, distance: -8, duration: 0.6)
    }
}

// MARK: - Transitions

private struct PushOut: ViewModifier {
    var x: CGFloat
    var opacity: Double
    var blur: CGFloat
    func body(content: Content) -> some View {
        content.offset(x: x).opacity(opacity).blur(radius: blur)
    }
}

private struct SplashOut: ViewModifier {
    var p: CGFloat
    func body(content: Content) -> some View {
        content.scaleEffect(1 + 0.06 * p).blur(radius: 10 * p).opacity(1 - p)
    }
}

private struct SlideFade: ViewModifier {
    var x: CGFloat
    var opacity: Double
    func body(content: Content) -> some View { content.offset(x: x).opacity(opacity) }
}

extension AnyTransition {
    /// iOS-style push: the new screen slides in a full width; the old one drifts a third of
    /// the way, fades and blurs (560 ms, cubic-bezier(.32,.72,0,1)).
    static func push(_ dir: CGFloat) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: dir > 0 ? .trailing : .leading),
            removal: .modifier(active: PushOut(x: -dir * 130, opacity: 0, blur: 2),
                               identity: PushOut(x: 0, opacity: 1, blur: 0))
        )
    }

    /// The splash dissolves into the sky: grows 6 %, blurs and fades.
    static var splashOut: AnyTransition {
        .asymmetric(insertion: .opacity,
                    removal: .modifier(active: SplashOut(p: 1), identity: SplashOut(p: 0)))
    }

    /// Home slides in 24 pt from the right as it fades up.
    static var homeIn: AnyTransition {
        .asymmetric(insertion: .modifier(active: SlideFade(x: 24, opacity: 0), identity: SlideFade(x: 0, opacity: 1)),
                    removal: .opacity)
    }
}

// MARK: - Shared screen scaffolding

/// Standard layout of a question screen: content centred in the space between the top bar and
/// the footer, footer pinned to the bottom.
struct QuestionLayout<Main: View, Footer: View>: View {
    var arriving = false
    @ViewBuilder var main: Main
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            main
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            footer
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .riseIn(arriving, delay: 0.52, distance: 40, duration: 0.75)
        }
    }
}

/// Toast pill, 130 pt above the bottom.
struct ToastView: View {
    var text: String
    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .font(.dm(13, .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.4), in: Capsule())
                .background(Color(hex: 0x161618).opacity(0.9), in: Capsule())
                .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
                .padding(.horizontal, 24)
                .padding(.bottom, 96)
        }
        .allowsHitTesting(false)
        .accessibilityAddTraits(.isStaticText)
    }
}
