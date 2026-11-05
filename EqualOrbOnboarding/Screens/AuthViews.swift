import SwiftUI
import AppTrackingTransparency

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
            OrbWithBubble(talk: talk, reserve: title)
                .riseIn(arriving, delay: 0.3)
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
                            .keyboardType(.numberPad)
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
    @State private var digits: [String] = []
    @State private var verifying = false

    private let title = Catalog.title(.otp, name: "")
    private let code = ["4", "8", "2", "7"]

    private var spaced: String {
        let p = model.phone
        guard p.count == 10 else { return p }
        return "\(p.prefix(5)) \(p.suffix(5))"
    }

    var body: some View {
        QuestionLayout {
            VStack(spacing: 0) {
                OrbWithBubble(talk: talk, reserve: title)
                    .padding(.bottom, 32)
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { i in
                        let filled = i < digits.count
                        Text(filled ? digits[i] : "")
                            .font(.dm(26, .semibold))
                            .foregroundStyle(EQ.ink)
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .glass(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: 0.62,
                                   stroke: filled ? EQ.green : .white.opacity(0.75))
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
        } footer: {
            Button(verifying ? "Verifying…" : "Confirm") {}
                .buttonStyle(PrimaryButtonStyle(lookEnabled: verifying))
                .disabled(true)
        }
        .task {
            talk.intro(title)
            do {
                // Give the SMS a moment to “arrive” before the code fills in.
                try await Task.sleep(for: .seconds(3))
                for d in code {
                    try await Task.sleep(for: .seconds(0.38))
                    withAnimation(.easeOut(duration: 0.2)) { digits.append(d) }
                    Haptics.select()
                }
                withAnimation { verifying = true }
                try await Task.sleep(for: .seconds(0.7))
                // App Tracking Transparency, asked once right after sign-in.
                if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                    try await Task.sleep(for: .seconds(0.35))
                    _ = await ATTrackingManager.requestTrackingAuthorization()
                }
                try Task.checkCancellation()
                Haptics.success()
                model.go(.name, haptic: false)
            } catch {}
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

    private let title = Catalog.title(.name, name: "")
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        QuestionLayout {
            OrbWithBubble(talk: talk, reserve: title)
        } footer: {
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
        .onAppear {
            text = model.name
            talk.intro(title)
        }
        // As on the number screen: the keyboard waits for the orb to finish asking.
        .onChange(of: talk.typing) { was, isTyping in
            guard was, !isTyping, !askedForName else { return }
            askedForName = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        model.name = trimmed
        focused = false
        model.go(.cases)
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
        .overlay(Capsule().strokeBorder(filled ? EQ.green : .white, lineWidth: 1.5))
        .shadow(color: Color(hex: 0x003214).opacity(0.08), radius: 10, y: 6)
        .animation(.easeInOut(duration: 0.2), value: filled)
    }
}
