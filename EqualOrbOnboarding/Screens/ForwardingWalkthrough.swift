import SwiftUI

/// The call-forwarding walkthrough above the orb: a big phone, cropped at the bottom, playing
/// the steps at sizes you can actually read. It loops, and follows the screen's flow:
///
/// - call (iOS 26 and earlier): Equal → tap Call → iOS's “Call …?” → carrier reply → back, confirm.
/// - copy (iOS 27+): Equal → tap Copy → Phone keypad, paste, call → carrier reply → back, confirm.
///
/// Every frame is a function of time, so the loop is exact and nothing drifts.
struct ForwardingWalkthrough: View {
    var mode: ForwardingView.Mode
    @State private var start = Date()
    @State private var shown = false

    /// Design size of the visible part of the phone; the whole thing scales to fit the hero.
    static let canvas = CGSize(width: 244, height: 300)
    static let period = 11.5

    var body: some View {
        GeometryReader { g in
            let k = min(1, g.size.height / Self.canvas.height, g.size.width / Self.canvas.width)
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSince(start).truncatingRemainder(dividingBy: Self.period)
                Phone(t: t, mode: mode)
                    .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .top)
                    .scaleEffect(k, anchor: .bottom)
                    .frame(width: g.size.width, height: g.size.height, alignment: .bottom)
            }
        }
        // A long eased fade, so the dark screen melts into the sky instead of ending in a band.
        .mask(SoftBottomFade(start: 0.58))
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 24)
        .onAppear {
            start = Date()
            withAnimation(EQ.ease(0.7).delay(0.45)) { shown = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Timeline

private func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let x = min(max((t - a) / (b - a), 0), 1)
    return x * x * (3 - 2 * x)
}

/// 1 while `t` is inside [a, b], fading over `fade` at each end.
private func window(_ t: Double, _ a: Double, _ b: Double, fade: Double = 0.3) -> Double {
    ramp(t, a - fade, a) * (1 - ramp(t, b, b + fade))
}

private enum Beat {
    static let app = (0.0, 2.3)        // Equal: tap Call / Copy
    static let dial = (2.3, 4.6)       // iOS call prompt, or the keypad
    static let carrier = (4.6, 7.4)    // the carrier's reply
    static let back = (7.4, 9.2)       // back in Equal, confirm
    static let done = (9.2, 11.5)      // the screen fades out, a big tick says it's done
    static let tapAction = 1.25
    static let tapPaste = 2.85
    static let tapDial = 3.75
    static let tapConfirm = 8.5
}

// MARK: - Phone

private struct Phone: View {
    let t: Double
    let mode: ForwardingView.Mode

    var body: some View {
        let w = ForwardingWalkthrough.canvas.width
        ZStack(alignment: .top) {
            // Screens, cross-fading from one step to the next.
            ZStack(alignment: .top) {
                Color(hex: 0xF6F7F5)
                // Equal stays under iOS's prompt in the call flow; it also fades back in at the
                // end of the loop so the restart is seamless.
                EqualScreen(t: t, mode: mode, after: false)
                    .opacity(max(window(t, -1, mode == .call ? Beat.dial.1 : Beat.app.1, fade: 0.25), ramp(t, 11.1, 11.5)))
                if mode == .copy {
                    KeypadScreen(t: t).opacity(window(t, Beat.dial.0, Beat.dial.1, fade: 0.25))
                }
                CarrierScreen(t: t).opacity(window(t, Beat.carrier.0, Beat.carrier.1, fade: 0.25))
                EqualScreen(t: t, mode: mode, after: true)
                    .opacity(window(t, Beat.back.0, Beat.done.0, fade: 0.3))
                DoneTick(t: t)
                if mode == .call {
                    CallPrompt(t: t).opacity(window(t, Beat.dial.0, Beat.dial.1, fade: 0.25))
                }
                StatusBar(dark: window(t, Beat.carrier.0, Beat.carrier.1, fade: 0.25) > 0.5)
                TapMarks(t: t, mode: mode)
            }
            .frame(width: w - 14, height: 420)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40, style: .continuous))
            .padding(.top, 7)

            // Bezel and the island.
            UnevenRoundedRectangle(topLeadingRadius: 46, topTrailingRadius: 46, style: .continuous)
                .strokeBorder(Color(hex: 0x1A1A1A), lineWidth: 7)
                .frame(width: w, height: 440)
            Capsule().fill(.black).frame(width: 72, height: 21).padding(.top, 17)
        }
        .frame(width: w, height: ForwardingWalkthrough.canvas.height, alignment: .top)
        .compositingGroup()
        .shadow(color: Color(hex: 0x00280F).opacity(0.22), radius: 14, y: 12)
    }
}

private struct StatusBar: View {
    var dark: Bool
    var body: some View {
        HStack {
            Text("9:41").font(.system(size: 12, weight: .semibold))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(dark ? .white : .black)
        .padding(.horizontal, 24)
        .padding(.top, 15)
    }
}

/// The step is done: the screen has faded out and a round green tick pops in, then the loop restarts.
private struct DoneTick: View {
    let t: Double

    var body: some View {
        let p: Double = ramp(t, Beat.done.0 + 0.2, Beat.done.0 + 0.55)
        let out: Double = ramp(t, 11.0, 11.3)
        let pop: Double = 0.5 + 0.5 * p + 0.12 * sin(p * Double.pi)   // a little overshoot
        let scale = CGFloat(pop * (1 - 0.15 * out))
        let alpha = p * (1 - out)
        Circle()
            .fill(LinearGradient(colors: [Color(hex: 0x5BDB6A), EQ.green], startPoint: .top, endPoint: .bottom))
            .frame(width: 76, height: 76)
            .overlay(Image(systemName: "checkmark").font(.system(size: 32, weight: .bold)).foregroundStyle(.white))
            .shadow(color: EQ.green.opacity(0.35), radius: 12, y: 8)
            .scaleEffect(scale)
            .opacity(alpha)
            .frame(maxWidth: .infinity)
            .padding(.top, 118)
    }
}

/// Gray finger dots: fade in, press, lift.
private struct TapMarks: View {
    let t: Double
    let mode: ForwardingView.Mode

    private var marks: [(Double, CGPoint)] {
        var m: [(Double, CGPoint)] = [
            (Beat.tapAction, CGPoint(x: 184, y: 139)),
            (Beat.tapDial, mode == .call ? CGPoint(x: 115, y: 185) : CGPoint(x: 115, y: 257)),
            (Beat.tapConfirm, CGPoint(x: 31, y: 190)),
        ]
        if mode == .copy { m.append((Beat.tapPaste, CGPoint(x: 115, y: 60))) }
        return m
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(marks.indices, id: \.self) { i in
                let (at, p) = marks[i]
                let a = ramp(t, at - 0.45, at - 0.15) * (1 - ramp(t, at + 0.2, at + 0.45))
                let press = ramp(t, at - 0.15, at) * (1 - ramp(t, at, at + 0.2))
                Circle().fill(Color.black.opacity(0.2)).frame(width: 34, height: 34)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .scaleEffect(1 - 0.18 * press)
                    .opacity(a)
                    .position(p)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

// MARK: - Equal

/// Equal's own screen: the code with its button, and (back from the call) the confirmation.
private struct EqualScreen: View {
    let t: Double
    let mode: ForwardingView.Mode
    let after: Bool

    var body: some View {
        let used = after || (mode == .copy && t > Beat.tapAction + 0.05)
        let label = mode == .call ? "Call" : (used && !after ? "Copied" : "Copy")
        let ticked = after && t > Beat.tapConfirm + 0.05
        VStack(alignment: .center, spacing: 0) {
            Text("Call forwarding")
                .font(.dm(17, .bold)).tracking(-0.3)
                .foregroundStyle(EQ.ink)
            Text(mode == .call ? "Tap Call to dial this code" : "Copy the code, dial it in Phone")
                .font(.dm(12.5))
                .foregroundStyle(EQ.ink.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.top, 3)

            HStack(spacing: 6) {
                Text(Catalog.forwardingCode)
                    .font(.dm(12.5, .medium))
                    .monospacedDigit()
                    .foregroundStyle(EQ.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(label)
                    .font(.dm(12.5, .semibold))
                    .foregroundStyle(used ? EQ.greenDeep : .white)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(used ? EQ.mint : EQ.green))
                    .overlay(Capsule().strokeBorder(EQ.green.opacity(used ? 0.25 : 0), lineWidth: 1))
                    .scaleEffect(pressScale(Beat.tapAction, active: !after))
            }
            .padding(.leading, 12)
            .padding(.trailing, 5)
            .frame(height: 40)
            .background(Capsule().fill(.white))
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
            .padding(.top, 16)

            if after {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ticked ? EQ.green : .white)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(EQ.ink.opacity(ticked ? 0 : 0.3), lineWidth: 1.2))
                        .overlay(Image(systemName: "checkmark").font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.white).opacity(ticked ? 1 : 0))
                        .frame(width: 15, height: 15)
                    Text("I have activated call forwarding")
                        .font(.dm(11, .medium))
                        .foregroundStyle(EQ.ink)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                Text("Continue")
                    .font(.dm(14, .semibold))
                    .foregroundStyle(.white.opacity(ticked ? 1 : 0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(EQ.green.opacity(ticked ? 1 : 0.38)))
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 62)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: 0xF6F7F5))
        .animation(.easeOut(duration: 0.2), value: ticked)
    }

    private func pressScale(_ at: Double, active: Bool) -> CGFloat {
        guard active else { return 1 }
        return 1 - 0.08 * ramp(t, at - 0.12, at) * (1 - ramp(t, at, at + 0.18))
    }
}

// MARK: - iOS

/// iOS 26's call sheet over the dimmed Equal screen: a blue “Call <code>” and a grey Cancel on
/// a glass card. On a real phone it sits at the bottom; here it sits at the bottom of the part
/// of the phone that's visible, rising in the same way.
private struct CallPrompt: View {
    let t: Double

    var body: some View {
        let rise = ramp(t, Beat.dial.0, Beat.dial.0 + 0.35)
        let press = ramp(t, Beat.tapDial - 0.12, Beat.tapDial) * (1 - ramp(t, Beat.tapDial, Beat.tapDial + 0.18))
        ZStack(alignment: .top) {
            Color.black.opacity(0.22)
            VStack(spacing: 7) {
                Text("Call \(Catalog.forwardingCode)")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Capsule().fill(Color(hex: 0x0A84FF)))
                    .scaleEffect(1 - 0.05 * press)
                Text("Cancel")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Capsule().fill(Color(hex: 0xDCDCE0)))
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white.opacity(0.94)))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .padding(.horizontal, 7)
            .padding(.top, 156)
            .offset(y: 40 * (1 - rise))
        }
    }
}

/// Phone's keypad with the code pasted in, about to call.
private struct KeypadScreen: View {
    let t: Double

    var body: some View {
        let pasted = t > Beat.tapPaste + 0.1
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
        VStack(spacing: 0) {
            Text(pasted ? Catalog.forwardingCode : " ")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 16)
                .frame(height: 28)
                // Long-press the empty field: “Paste”.
                .overlay {
                    Text("Paste")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(Capsule().fill(Color(hex: 0x2C2C2E)))
                        .opacity(window(t, Beat.tapPaste - 0.35, Beat.tapPaste + 0.1, fade: 0.15))
                }
                .padding(.top, 46)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 18), count: 3), spacing: 5) {
                ForEach(keys, id: \.self) { k in
                    Text(k).font(.system(size: 16, weight: .regular)).foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color(hex: 0xE5E5EA)))
                }
            }
            .padding(.top, 8)
            Image(systemName: "phone.fill")
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(hex: 0x34C759)))
                .scaleEffect(1 - 0.1 * ramp(t, Beat.tapDial - 0.12, Beat.tapDial) * (1 - ramp(t, Beat.tapDial, Beat.tapDial + 0.18)))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
}

/// The carrier's reply: “Calling…”, then the registrations land one by one, then Dismiss.
private struct CarrierScreen: View {
    let t: Double

    var body: some View {
        let kinds = ["Voice", "Data", "SMS"]
        VStack(spacing: 12) {
            Text("Calling…")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.6))
            ForEach(kinds.indices, id: \.self) { i in
                let a = ramp(t, Beat.carrier.0 + 0.6 + Double(i) * 0.35, Beat.carrier.0 + 0.9 + Double(i) * 0.35)
                VStack(spacing: 1) {
                    Text("Setting Registration Succeeded")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text("\(kinds[i]) Call Forwarding")
                        .font(.system(size: 12))
                        .opacity(0.75)
                }
                .foregroundStyle(.white.opacity(i == 0 ? 1 : 0.8))
                .opacity(a)
                .offset(y: 6 * (1 - a))
            }
            Text("Dismiss")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 30)
                .frame(height: 32)
                .background(Capsule().fill(.white))
                .opacity(ramp(t, Beat.carrier.0 + 1.8, Beat.carrier.0 + 2.1))
                .padding(.top, 4)
        }
        .padding(.top, 58)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: 0x111111))
    }
}
