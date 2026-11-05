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
    /// Said over the sample-call cards; counts the picks shown (up to three). “top 3 picks” is
    /// joined with non-breaking spaces so it never splits across lines.
    static func curated(_ count: Int) -> String {
        count <= 1 ? "Here’s how I’ll handle your pick" : "Here’s how I’ll handle your top\u{00A0}\(min(count, 3))\u{00A0}picks"
    }

    /// The orb's lines in the other languages, keyed by the English line. `{name}` stands in for
    /// the user's name.
    private static let translations: [String: [Lang: String]] = [
        title(.phone, name: ""): [.hi: "आपके कॉल किस नंबर पर आते हैं?",
                                  .ta: "உங்களுக்கு எந்த எண்ணில் அழைப்புகள் வரும்?",
                                  .bn: "আপনার কল কোন নম্বরে আসে?"],
        title(.otp, name: ""): [.hi: "अभी भेजा हुआ कोड डालिए",
                                .ta: "நான் இப்போது அனுப்பிய குறியீட்டை உள்ளிடுங்கள்",
                                .bn: "এইমাত্র পাঠানো কোডটি লিখুন"],
        title(.name, name: ""): [.hi: "मैं आपको क्या कहकर बुलाऊँ?",
                                 .ta: "உங்களை நான் எப்படி அழைக்கட்டும்?",
                                 .bn: "আপনাকে কী নামে ডাকব?"],
        title(.cases, name: ""): [.hi: "मैं आपके लिए क्या संभालूँ? कुछ भी चुनिए",
                                  .ta: "உங்களுக்காக எதைக் கவனிக்கட்டும்? ஏதேனும் தேர்ந்தெடுங்கள்",
                                  .bn: "আপনার জন্য কী সামলাব? যেকোনোটা বেছে নিন"],
        notifLine: [.hi: "हर कॉल का हाल बताने के लिए मुझे आपको नोटिफ़िकेशन भेजने होंगे।",
                    .ta: "ஒவ்வொரு அழைப்பும் எப்படிப் போனது என்று சொல்ல, உங்களுக்கு அறிவிப்புகள் அனுப்ப வேண்டும்.",
                    .bn: "প্রতিটি কল কেমন হলো জানাতে আপনাকে নোটিফিকেশন পাঠাতে হবে।"],
        contactsLine: [.hi: "और आपके लोगों को नाम से बुलाने के लिए मुझे आपके कॉन्टैक्ट्स चाहिए।",
                       .ta: "உங்கள் நபர்களைப் பெயர் சொல்லி வரவேற்க, உங்கள் தொடர்புகள் வேண்டும்.",
                       .bn: "আর চেনা মানুষদের নাম ধরে ডাকতে আপনার কন্টাক্টস দরকার।"],
        curating: [.hi: "आपकी पसंद से सैंपल कॉल तैयार हो रहे हैं…",
                   .ta: "உங்கள் தேர்வுகளிலிருந்து மாதிரி அழைப்புகளைத் தயாரிக்கிறேன்…",
                   .bn: "আপনার বাছাই থেকে নমুনা কল তৈরি হচ্ছে…"],
        curated(3): [.hi: "देखिए, आपकी टॉप 3 पसंद कैसे संभाली जाएँगी",
                     .ta: "உங்கள் முதல் 3 தேர்வுகளை இப்படிக் கையாள்வேன்",
                     .bn: "আপনার সেরা ৩টি বাছাই আমি এভাবে সামলাব"],
        curated(2): [.hi: "देखिए, आपकी टॉप 2 पसंद कैसे संभाली जाएँगी",
                     .ta: "உங்கள் முதல் 2 தேர்வுகளை இப்படிக் கையாள்வேன்",
                     .bn: "আপনার সেরা ২টি বাছাই আমি এভাবে সামলাব"],
        curated(1): [.hi: "देखिए, आपकी पसंद कैसे संभाली जाएगी",
                     .ta: "உங்கள் தேர்வை இப்படிக் கையாள்வேன்",
                     .bn: "আপনার বাছাইটি আমি এভাবে সামলাব"],
        title(.fwd, name: ""): [.hi: "बस एक कोड, और जो कॉल आप नहीं ले सकते या नहीं लेना चाहते, वो मेरे पास आएँगे",
                                .ta: "ஒரே ஒரு குறியீடு — நீங்கள் எடுக்க முடியாத அல்லது விரும்பாத அழைப்புகள் என்னிடம் வரும்",
                                .bn: "একটাই কোড, আর যে কল আপনি ধরতে পারবেন না বা চান না, সব আমার কাছে আসবে"],
        title(.access, name: ""): [.hi: "अब वॉइसमेल की जगह मुझे जवाब देने दीजिए",
                                   .ta: "இனி வாய்ஸ்மெயிலுக்குப் பதிலாக நான் பதிலளிக்கிறேன்",
                                   .bn: "এবার ভয়েসমেলের বদলে আমাকে উত্তর দিতে দিন"],
        title(.welcome, name: "{name}"): [.hi: "Equal में आपका स्वागत है, {name}!",
                                          .ta: "Equal-க்கு வரவேற்கிறோம், {name}!",
                                          .bn: "Equal-এ স্বাগতম, {name}!"],
    ]

    /// `line` (English) in `lang`; lines without a translation stay in English.
    static func translate(_ line: String, to lang: Lang) -> String {
        guard lang != .en else { return line }
        if let t = translations[line]?[lang] { return t }
        // The welcome line carries the user's name.
        let welcome = title(.welcome, name: "{name}").components(separatedBy: "{name}")
        if line.hasPrefix(welcome[0]), line.hasSuffix(welcome[1]), let t = translations[title(.welcome, name: "{name}")]?[lang] {
            let name = String(line.dropFirst(welcome[0].count).dropLast(welcome[1].count))
            return t.replacingOccurrences(of: "{name}", with: name)
        }
        return line
    }

    static let forwardingCode = "**67*04048938092#"
}
