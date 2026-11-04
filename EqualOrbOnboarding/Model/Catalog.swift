import Foundation

/// One everyday job Equal can take on, with the pretend call used to demo it.
struct UseCase: Identifiable, Hashable {
    let id: String
    let emoji: String
    let label: String
    /// Who is on the other end of the sample call.
    let caller: String
    /// Caller's first line and Equal's reply. `{n}` is the user's name.
    let callerLine: String
    let equalLine: String
    /// One-line summary shown after the call.
    let summary: String
    /// True when Equal places the call (reminders) rather than answering it.
    let outgoing: Bool
}

enum Catalog {
    /// The ten situations on the “What can I handle for you?” screen, in display order.
    static let useCases: [UseCase] = [
        UseCase(id: "task_door", emoji: "🛵", label: "Guide delivery riders to my door", caller: "Delivery rider",
                callerLine: "I’m outside the society, which tower is it?",
                equalLine: "Tower B, flat 402. Please use gate 2 — the guard will let you in.",
                summary: "I guided them to your door and shared the gate number.", outgoing: false),
        UseCase(id: "bank", emoji: "🏦", label: "Say no to loan offers", caller: "Bank",
                callerLine: "About a pre-approved loan offer…",
                equalLine: "{n} is busy right now. Please call back after 6 pm.",
                summary: "I asked them to call back after 6 PM.", outgoing: false),
        UseCase(id: "task_bill", emoji: "⚡", label: "Remind me before bills", caller: "You",
                callerLine: "Hello?",
                equalLine: "Hi {n}, quick reminder — your electricity bill is due in 2 days.",
                summary: "I reminded you the electricity bill is due in 2 days.", outgoing: true),
        UseCase(id: "task_med", emoji: "💊", label: "Remind mom to take medicine", caller: "Mom",
                callerLine: "Hello? Who’s calling?",
                equalLine: "Hi Aunty, it’s Equal calling for {n}. Just a reminder to take your 9 o’clock medicine.",
                summary: "I reminded her to take her 9 o’clock medicine.", outgoing: true),
        UseCase(id: "unknown", emoji: "❓", label: "Screen calls from strangers", caller: "Unknown number",
                callerLine: "Hello, is this {n}?",
                equalLine: "I’m {n}’s assistant. May I know who’s calling and why?",
                summary: "I asked who they are and why they called.", outgoing: false),
        UseCase(id: "task_appt", emoji: "🩺", label: "Book doctor appointments", caller: "Clinic",
                callerLine: "We have slots tomorrow — what time works?",
                equalLine: "Tomorrow at 6 PM works for {n}. Please book it under their name.",
                summary: "I booked tomorrow at 6 PM under your name.", outgoing: false),
        UseCase(id: "hm_svc", emoji: "🔧", label: "Schedule AC repair", caller: "AC technician",
                callerLine: "I can come at 3 today.",
                equalLine: "3 pm works. I’ll let {n} know you’re coming.",
                summary: "I confirmed they’ll come at 3 PM today.", outgoing: false),
        UseCase(id: "task_resched", emoji: "📦", label: "Reschedule Amazon couriers", caller: "Courier",
                callerLine: "Sir, I’m at your address — is anyone home?",
                equalLine: "No one’s home right now. Could you come back after 7 PM?",
                summary: "I asked them to come back after 7 PM.", outgoing: false),
        UseCase(id: "hm_school", emoji: "🏫", label: "Note my kid’s school calls", caller: "School",
                callerLine: "Calling about the PTM on Friday.",
                equalLine: "Thank you! I’ll pass this to {n} — they’ll call back soon.",
                summary: "I noted it’s about the PTM on Friday.", outgoing: false),
        UseCase(id: "pro_meet", emoji: "💼", label: "Take messages in meetings", caller: "Caller",
                callerLine: "Is {n} free to talk?",
                equalLine: "{n} is in a meeting — they’ll call you back within the hour.",
                summary: "I said you’re in a meeting and will call back within the hour.", outgoing: false)
    ]

    static func useCase(_ id: String) -> UseCase? { useCases.first { $0.id == id } }

    /// Tints for the emoji tiles on the three curated sample-call cards.
    static let cardTints: [UInt32] = [0xFFE6D5, 0xE2F8E6, 0xECE6FF]

    /// The four lines of a sample call.
    static func script(_ u: UseCase, name: String) -> [(speaker: String, line: String)] {
        let f = { (s: String) in s.replacingOccurrences(of: "{n}", with: name) }
        return [(u.caller, f(u.callerLine)), ("Equal AI", f(u.equalLine)),
                (u.caller, "Okay, got it. Thank you!"), ("Equal AI", "You’re welcome! I’ll let \(name) know.")]
    }

    static func summary(_ u: UseCase) -> String {
        let lead = u.outgoing ? "I called \(u.caller == "You" ? "you" : u.caller) as scheduled." : "\(u.caller) called just now."
        return "\(lead) \(u.summary) Nothing for you to do."
    }

    // MARK: Orb lines

    /// What the orb says on each screen (typed into its bubble).
    enum Ask: String { case phone, otp, name, cases, permq, fwd, access, welcome }

    static func title(_ ask: Ask, name: String) -> String {
        switch ask {
        case .phone: "What number do you get calls on?"
        case .otp: "Enter the code I just texted you"
        case .name: "What should I call you?"
        case .cases: "What can I handle for you? Pick any"
        case .permq: notifLine
        case .fwd: "One code, and all calls you can’t or don’t want to take come to me"
        case .access: "Now let me answer instead of voicemail"
        case .welcome: "Welcome to Equal, \(name)!"
        }
    }

    static let notifLine = "To tell you how every call went, I’ll need to send you notifications."
    static let contactsLine = "And to greet your people by name, I’ll need access to your contacts."
    static let curating = "Curating sample calls from your picks…"
    static let curated = "Here’s how I’ll handle your top picks"

    /// Playful lines when someone taps or drags the orb: they nod to the play, then steer back.
    static func playful(_ ask: Ask) -> [String] {
        switch ask {
        case .phone: ["Fun as this is, I can’t call you back without a number 😄", "Wheee! Okay — your number, and I’m all yours.", "I’m flattered. Now, what number do your calls come to?", "Careful, I bounce. Your number goes just below 👇", "Let’s make this official — pop your number in?"]
        case .otp: ["Shh, I’m watching for that code 👀", "Almost there! Just the 4 digits I texted you.", "Easy — still waiting on that little code.", "Boing! Now, the code from your SMS?"]
        case .name: ["Okay, you’ve met me. What should I call you?", "You know my name… I don’t know yours yet 🙂", "Wheee! So, who am I answering calls for?", "Before we go on a ride — what’s your name?", "Nice to meet you too. Name, please?"]
        case .cases: ["I’m better at errands than acrobatics. Pick a few?", "Okay, okay! Now show me what I should handle.", "Tap a couple below — that’s where I really shine ✨", "Fun! Now point me at some real work 👇", "You can’t keep me busy like this forever. Pick a task?"]
        case .welcome: ["We’re nearly there!", "Almost home 🏡"]
        default: ["Okay, okay — back to it?", "Wheee! Now, where were we?", "I could do this all day. Shall we continue?"]
        }
    }

    static let forwardingCode = "**67*04048938092#"
}
