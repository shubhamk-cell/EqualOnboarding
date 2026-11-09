import SwiftUI

// MARK: - Number

struct PhoneView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @FocusState private var focused: Bool
    @State private var askedForNumber = false

    private let title = Catalog.title(.phone, name: "")

    var body: some View {
        let arriving = model.arrivingFromSplash
        QuestionLayout(arriving: arriving) {
            // No rise-in here: the orb already flies in from the splash, and offsetting its slot
            // made the flight land 26 pt low and then jump up when the slot took over.
            OrbWithBubble(talk: talk, reserve: title)
        } footer: {
            VStack(spacing: 0) {
                InputPill(filled: !model.phone.isEmpty, canSend: model.phone.count == 10, sendLabel: "Send OTP", send: sendOTP) {
                    HStack(spacing: 12) {
                        Text("🇮🇳 +91")
                            .font(.dm(17, .medium))
                            .foregroundStyle(EQ.ink)
                            .fixedSize()
                        Rectangle().fill(EQ.ink.opacity(0.15)).frame(width: 1, height: 26)
                        TextField("", text: $model.phone, prompt: Text("Mobile number").foregroundStyle(EQ.ink.opacity(0.55)))
                            .font(.dm(18, .medium))
                            .foregroundStyle(EQ.ink)
                            // The phone pad is the keyboard iOS pairs with phone-number AutoFill (your
                            // number from Contacts › My Info shows above it).
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focused)
                            .onChange(of: model.phone) { old, v in
                                if let clean = Self.tenDigits(v, was: old), clean != v { model.phone = clean }
                            }
                    }
                }
                .padding(.bottom, 12)

                Button { Haptics.select(); model.whatsapp.toggle() } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(model.whatsapp ? EQ.green : .clear)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(model.whatsapp ? EQ.green : EQ.ink.opacity(0.35), lineWidth: 1.5)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(model.whatsapp ? 1 : 0)
                        }
                        .frame(width: 18, height: 18)
                        Text("Send me updates on WhatsApp")
                            .font(.dm(12))
                            .foregroundStyle(EQ.ink.opacity(0.7))
                    }
                }
                .buttonStyle(PressStyle())
                .padding(.top, 2)
                .padding(.bottom, 10)

                (Text("You agree to our ")
                 + Text("Terms").foregroundStyle(EQ.greenDeep).font(.dm(12, .medium))
                 + Text(" & ")
                 + Text("Privacy Policy").foregroundStyle(EQ.greenDeep).font(.dm(12, .medium)))
                    .font(.dm(12))
                    .foregroundStyle(EQ.ink.opacity(0.62))
                    .multilineTextAlignment(.center)
            }
            .afterOrb(talk)
        }
        .onAppear {
            let arriving = model.arrivingFromSplash
            talk.intro(title, delay: arriving ? 0.75 : 0.42)
        }
        // The keyboard comes up once the orb has finished asking, not while it's typing.
        .onChange(of: talk.typing) { was, isTyping in
            guard was, !isTyping, !askedForNumber else { return }
            askedForNumber = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    /// Digits only, at most 10. Autofill and paste bring the whole number, often with its country
    /// code (“+91 98765 43210”), so when several digits land at once keep the last ten; typing past
    /// ten just stops.
    static func tenDigits(_ text: String, was old: String) -> String? {
        let digits = text.filter(\.isNumber)
        guard digits.count > 10 else { return digits }
        let pasted = digits.count - old.filter(\.isNumber).count > 1
        return String(pasted ? digits.suffix(10) : digits.prefix(10))
    }

    private func sendOTP() {
        guard model.phone.count == 10 else { return }
        focused = false
        model.go(.otp)
    }
}

// MARK: - Code

struct OTPView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()

    private let title = Catalog.title(.otp, name: "")

    private var spaced: String {
        let p = model.phone
        guard p.count == 10 else { return p }
        return "\(p.prefix(5)) \(p.suffix(5))"
    }

    var body: some View {
        let digits = model.otpDigits
        let verifying = model.otpVerifying
        let length = model.variant.codeLength
        QuestionLayout {
            VStack(spacing: 0) {
                OrbWithBubble(talk: talk, reserve: title)
                    .padding(.bottom, 32)
                VStack(spacing: 0) {
                HStack(spacing: length > 4 ? 8 : 12) {
                    ForEach(0..<length, id: \.self) { i in
                        let filled = i < digits.count
                        Text(filled ? digits[i] : "")
                            .font(.dm(length > 4 ? 24 : 26, .semibold))
                            .foregroundStyle(EQ.ink)
                            .frame(maxWidth: .infinity, minHeight: length > 4 ? 60 : 68)
                            .glass(RoundedRectangle(cornerRadius: length > 4 ? 16 : 18, style: .continuous), tint: 0.62,
                                   stroke: filled ? EQ.green : EQ.edge)
                            .popOnChange(of: filled)
                    }
                }
                Text(verifying ? "Verifying…" : "Reading the SMS automatically…")
                    .font(.dm(14))
                    .foregroundStyle(EQ.ink.opacity(0.62))
                    .padding(.top, 14)
                    .contentTransition(.opacity)
                Button { model.go(.phone, direction: -1) } label: {
                    HStack(spacing: 6) {
                        Text("+91 \(spaced)").font(.dm(15, .semibold)).foregroundStyle(EQ.ink)
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(EQ.greenDeep)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(EQ.green.opacity(0.12)))
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Edit number, +91 \(spaced)")
                .padding(.top, 6)
                }
                .afterOrb(talk)
            }
        } footer: {
            // Ready to tap once the code is in, in case verifying is ever slow.
            Button(verifying ? "Verifying…" : "Confirm") { model.confirmOTP() }
                .buttonStyle(PrimaryButtonStyle(lookEnabled: verifying))
                .disabled(digits.count < length)
                .afterOrb(talk, index: 1)
        }
        .onAppear {
            talk.intro(title)
            // Belt and braces: if the code never started filling (e.g. opened another way), start it.
            if model.otpDigits.isEmpty, !model.otpVerifying { model.startOTP() }
        }
    }
}

// MARK: - Name

struct NameView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var talk = Talk()
    @FocusState private var focused: Bool
    @State private var askedForName = false
    @State private var text = ""
    /// V8: the name is in, and the same page now asks how to address them.
    @State private var askingGender = false
    @State private var gendersShown = false
    /// Back from the picks, with a gender already chosen.
    @State private var cameBack = false

    private let title = Catalog.title(.name, name: "")
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        QuestionLayout {
            // V8: the gender cards sit right under the orb, the three centred together. Their room
            // opens the moment the name is in, so the orb glides up once, with the answer.
            VStack(spacing: 0) {
                OrbWithBubble(talk: talk, reserve: askingGender ? Catalog.genderAsk(trimmed) : title)
                if askingGender {
                    genders
                        .padding(.top, 30)
                        .transition(.opacity.combined(with: .offset(y: 18)))
                }
            }
        } footer: {
            if !askingGender {
                // Drops away with the keyboard, quickly, before the cards arrive below the orb (and
                // rises back to edit the name).
                namePill
                    .afterOrb(talk)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 24)),
                        removal: .opacity.combined(with: .offset(y: 110)).animation(.easeOut(duration: 0.18))))
            } else if cameBack, model.gender != nil {
                // Back here with a choice already ticked: tapping it again isn't obvious, so the
                // way on is spelled out (another card still moves on by itself).
                Button(model.nextCTA) { Haptics.step(); model.next() }
                    .buttonStyle(PrimaryButtonStyle())
                    .reveal(gendersShown, index: 3)
                    .transition(.opacity)
            }
        }
        // Once the name is in, the page stops making room for the keyboard: the orb and cards go
        // straight to where they'll rest, in one move, while the keyboard slides away underneath
        // (rather than the orb dropping with the keyboard and then rising for the cards).
        .ignoresSafeArea(askingGender ? .keyboard : [], edges: .bottom)
        .onAppear {
            // Back on the gender question returns to the name, on this page.
            model.localBack = (.name, {
                guard askingGender else { return false }
                editName()
                return true
            })
            text = model.name
            // Back from V8's picks: straight to the gender question, the earlier answer marked.
            if model.variant == .v8, model.gender != nil, !trimmed.isEmpty {
                askingGender = true
                askedForName = true
                cameBack = true
                talk.intro(Catalog.genderAsk(trimmed))
            } else {
                talk.intro(title)
            }
        }
        // As on the number screen: the keyboard waits for the orb to finish asking.
        .onChange(of: talk.typing) { was, isTyping in
            if askingGender, was, !isTyping { gendersShown = true }
            guard was, !isTyping, !askedForName else { return }
            askedForName = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    private var namePill: some View {
        InputPill(filled: !text.isEmpty, canSend: !trimmed.isEmpty, sendLabel: "Continue", send: submit) {
            TextField("", text: $text, prompt: Text("Your name").foregroundStyle(EQ.ink.opacity(0.55)))
                .font(.dm(18, .medium))
                .foregroundStyle(EQ.ink)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit(submit)
        }
    }

    /// Back to typing the name, on the same page and the same way in reverse: the cards drop and
    /// fade as the name pill rises back, and the orb asks again once it's there.
    private func editName() {
        gendersShown = false
        withAnimation(.easeOut(duration: 0.3)) {
            askingGender = false
            cameBack = false
        }
        talk.full = title
        Task { await talk.think() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard !askingGender else { return }
            Task { await talk.show(title) }
        }
    }

    /// V8: two cards side by side, over a link back to the name.
    private var genders: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                ForEach(Array(Gender.allCases.enumerated()), id: \.element) { i, g in
                    genderCard(g)
                        .reveal(gendersShown, index: i)
                }
            }

            Button { Haptics.select(); editName() } label: {
                HStack(spacing: 6) {
                    Text("Not \(trimmed)?").font(.dm(14)).foregroundStyle(EQ.ink.opacity(0.6))
                    Text("Edit name").font(.dm(14, .semibold)).foregroundStyle(EQ.greenDeep)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Edit name, \(trimmed)")
            .reveal(gendersShown, index: 2)
        }
    }

    /// As in the design: a tinted glass card, the name of the choice on top, a 3D bust rising
    /// from the bottom edge, and a faint ♂ / ♀ in the corner.
    private func genderCard(_ g: Gender) -> some View {
        let on = model.gender == g
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button { pick(g) } label: {
            ZStack {
                shape.fill(Color(hex: g.fill))
                GenderMark(gender: g)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: g == .male ? .topLeading : .bottomLeading)
                LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 0) {
                    Text(g.label)
                        .font(.dm(17, .medium))
                        .foregroundStyle(EQ.ink)
                        .padding(.top, 18)
                    Spacer(minLength: 6)
                    Image(g.avatar)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 76)
                        .scaleEffect(on ? 1.06 : 1, anchor: .bottom)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .clipShape(shape)
            .background(shape.inset(by: -4).fill(EQ.green.opacity(on ? 0.14 : 0)))
            .overlay(shape.strokeBorder(on ? EQ.green : EQ.edge, lineWidth: on ? 2 : 1))
            .shadow(color: Color(hex: 0x1E2A6B).opacity(on ? 0.12 : 0.07), radius: 10, y: 5)
            // The chosen card keeps a tick on its corner, as the picks do.
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(EQ.green))
                    .overlay(Circle().stroke(EQ.page, lineWidth: 2))
                    .scaleEffect(on ? 1 : 0.4)
                    .opacity(on ? 1 : 0)
                    .offset(x: 6, y: -6)
                    .accessibilityHidden(true)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: on)
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .accessibilityLabel("\(g.label). Equal will say \(trimmed) \(g.honorific)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func pick(_ g: Gender) {
        Haptics.select()
        model.gender = g
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard model.step == .name else { return }
            model.next()
        }
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        model.name = trimmed
        focused = false
        // V8 asks how to address them on the same page.
        guard model.variant == .v8 else { model.next(); return }
        model.gender = nil
        let ask = Catalog.genderAsk(trimmed)
        talk.full = ask
        // All on the same page: the keyboard goes down as the name pill drops and fades; the old
        // question goes back into the orb and the typing dots come out; the orb asks; and only
        // once its question is showing do the cards and the edit link rise in (on `talk.typing`).
        withAnimation(.easeOut(duration: 0.3)) { askingGender = true }
        Task { await talk.think() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            guard askingGender else { return }
            Task { await talk.show(ask) }
        }
    }
}

// MARK: - Shared input

/// White 60 pt pill holding a field, with the screen's main action merged in as a round
/// green send button at its right end. Gains a green rim once something is typed.
struct InputPill<Field: View>: View {
    var filled: Bool
    var canSend: Bool
    var sendLabel: String
    var send: () -> Void
    @ViewBuilder var field: Field

    var body: some View {
        HStack(spacing: 8) {
            field
            Button(action: send) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(canSend ? EQ.green : Color(hex: 0xBFE6CB)))
                    .shadow(color: Color(hex: 0x008C32).opacity(canSend ? 0.3 : 0), radius: 6, y: 4)
            }
            .buttonStyle(PressStyle(scale: 0.92))
            .disabled(!canSend)
            .accessibilityLabel(sendLabel)
            .animation(.easeInOut(duration: 0.2), value: canSend)
        }
        .padding(.leading, 22)
        .padding(.trailing, 8)
        .frame(height: 60)
        .background(Capsule().fill(.white))
        .background(Capsule().inset(by: -3).fill(EQ.green.opacity(filled ? 0.12 : 0)))
        .overlay(Capsule().strokeBorder(filled ? EQ.green : EQ.edge, lineWidth: filled ? 1.5 : 1))
        .shadow(color: Color(hex: 0x003214).opacity(0.08), radius: 10, y: 6)
        .animation(.easeInOut(duration: 0.2), value: filled)
    }
}

/// The faint gender symbol in a card's corner, drawn from the design's vectors and partly cut off
/// by the card's edge: ♂ at the top left, ♀ at the bottom left (V8's gender and voice cards).
struct GenderMark: View {
    var gender: Gender

    var body: some View {
        let colour = Color(hex: gender.mark)
        Canvas { ctx, _ in
            if gender == .male {
                var arrow = Path()
                arrow.move(to: CGPoint(x: 76, y: 11.9))
                for p in [(58.2, 31.8), (68, 39.2), (84.6, 20.5), (84.6, 34.1), (95, 34.1), (95, 0), (61.2, 0), (61.2, 11.9)] {
                    arrow.addLine(to: CGPoint(x: p.0, y: p.1))
                }
                arrow.closeSubpath()
                ctx.fill(arrow, with: .color(colour))
                ctx.stroke(Path(ellipseIn: CGRect(x: 38.9 - 31.8, y: 64.1 - 31.8, width: 63.6, height: 63.6)),
                           with: .color(colour), lineWidth: 14.25)
            } else {
                ctx.stroke(Path(ellipseIn: CGRect(x: 54.3 - 36.5, y: 44.7 - 36.5, width: 73, height: 73)),
                           with: .color(colour), lineWidth: 16.4)
                var cross = Path()
                cross.move(to: CGPoint(x: 56, y: 80.6)); cross.addLine(to: CGPoint(x: 56, y: 118.5))
                cross.move(to: CGPoint(x: 34.8, y: 100.7)); cross.addLine(to: CGPoint(x: 75.8, y: 100.7))
                ctx.stroke(cross, with: .color(colour), lineWidth: 10.9)
            }
        }
        .frame(width: gender == .male ? 95 : 109, height: gender == .male ? 103 : 118.5)
        .opacity(gender == .male ? 0.1 : 0.16)
        .offset(gender == .male ? CGSize(width: -22, height: -10) : CGSize(width: -30, height: 40))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
