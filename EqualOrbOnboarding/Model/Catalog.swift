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
    /// The situations on the “What can I handle for you?” screen, in display order.
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
                summary: "I said you’re in a meeting and will call back within the hour.", outgoing: false),
        UseCase(id: "cab", emoji: "🚕", label: "Guide cab drivers to my pickup", caller: "Cab driver",
                callerLine: "Madam, I’m at the main road — where exactly are you?",
                equalLine: "Please take the second left after the petrol pump. {n} is waiting at the blue gate.",
                summary: "I guided them to your pickup at the blue gate.", outgoing: false),
        UseCase(id: "gas", emoji: "🔥", label: "Book my gas cylinder refill", caller: "Gas agency",
                callerLine: "Your cylinder booking is due — shall we confirm it?",
                equalLine: "Yes, please book it for {n} and deliver after 5 pm.",
                summary: "I booked your refill for delivery after 5 PM.", outgoing: false),
        UseCase(id: "card", emoji: "💳", label: "Decline credit card offers", caller: "Card sales",
                callerLine: "Sir, you’re eligible for a lifetime-free credit card…",
                equalLine: "Thanks, but {n} isn’t interested. Please remove this number from your list.",
                summary: "I declined and asked them not to call again.", outgoing: false),
        UseCase(id: "insurance", emoji: "🛡️", label: "Handle insurance renewal calls", caller: "Insurance agent",
                callerLine: "Your car insurance expires next week.",
                equalLine: "Please send the renewal quote on WhatsApp — {n} will check it tonight.",
                summary: "I asked them to send the quote on WhatsApp.", outgoing: false),
        UseCase(id: "guard", emoji: "💂", label: "Talk to my building guard", caller: "Security guard",
                callerLine: "Someone from the bank is at the gate for you.",
                equalLine: "Please ask them to leave the documents with you — {n} will collect them.",
                summary: "I asked the guard to keep the documents.", outgoing: false),
        UseCase(id: "rent", emoji: "🏠", label: "Remind me to pay rent", caller: "You",
                callerLine: "Hello?",
                equalLine: "Hi {n}, your rent is due on the 5th — just a heads-up.",
                summary: "I reminded you rent is due on the 5th.", outgoing: true),
        UseCase(id: "bday", emoji: "🎂", label: "Wish family on their birthdays", caller: "Cousin",
                callerLine: "Hello?",
                equalLine: "Happy birthday! {n} asked me to call and wish you a wonderful year.",
                summary: "I wished them happy birthday from you.", outgoing: true),
        UseCase(id: "dad", emoji: "👴", label: "Remind dad about his checkup", caller: "Dad",
                callerLine: "Haan, who is this?",
                equalLine: "Uncle, it’s Equal calling for {n}. Your checkup is tomorrow at 10 am.",
                summary: "I reminded him about tomorrow’s 10 AM checkup.", outgoing: true),
        UseCase(id: "drive", emoji: "🚗", label: "Answer calls while I drive", caller: "Friend",
                callerLine: "Hey, are you free to talk?",
                equalLine: "{n} is driving right now. Shall I ask them to call you back in 30 minutes?",
                summary: "I said you’re driving and will call back.", outgoing: false),
        UseCase(id: "broker", emoji: "🏢", label: "Screen property broker calls", caller: "Property broker",
                callerLine: "We have a great 2BHK in your area…",
                equalLine: "{n} isn’t looking right now. Please don’t call again.",
                summary: "I said you’re not looking and declined.", outgoing: false),
        UseCase(id: "salon", emoji: "💇", label: "Confirm salon appointments", caller: "Salon",
                callerLine: "Calling to confirm your 4 pm haircut.",
                equalLine: "Yes, {n} will be there at 4. Thank you!",
                summary: "I confirmed your 4 PM appointment.", outgoing: false),
        UseCase(id: "tutor", emoji: "📚", label: "Take my kid’s tuition calls", caller: "Tutor",
                callerLine: "Tomorrow’s class is moved to 6 pm.",
                equalLine: "Got it — 6 pm tomorrow. I’ll let {n} know.",
                summary: "I noted tomorrow’s class moved to 6 PM.", outgoing: false),
        UseCase(id: "wifi", emoji: "📡", label: "Schedule broadband repairs", caller: "Broadband technician",
                callerLine: "I can come between 2 and 4 today.",
                equalLine: "That works. Please call this number when you’re downstairs.",
                summary: "I scheduled the visit for 2–4 PM today.", outgoing: false),
        UseCase(id: "help", emoji: "🧹", label: "Coordinate with my house help", caller: "House help",
                callerLine: "Didi, I’ll come late today, around 11.",
                equalLine: "No problem, 11 is fine. I’ll tell {n}.",
                summary: "I noted she’ll come at 11 today.", outgoing: false),
        UseCase(id: "recharge", emoji: "📱", label: "Remind me to recharge my phone", caller: "You",
                callerLine: "Hello?",
                equalLine: "Hi {n}, your prepaid plan ends in 2 days — time to recharge.",
                summary: "I reminded you your plan ends in 2 days.", outgoing: true)
    ]

    static func useCase(_ id: String) -> UseCase? { useCases.first { $0.id == id } }

    // MARK: V2 instructions

    /// The instruction Equal drafts for each pick (V2), in the user's voice.
    static let instructions: [String: String] = [
        "task_door": "When a delivery rider calls, tell them it’s Tower B, flat 402, and to use gate 2",
        "bank": "If a bank calls about a loan, say I’m not interested and ask them not to call again",
        "task_bill": "Call me two days before my electricity bill is due",
        "task_med": "Call Mom at 9 every night and remind her to take her medicine",
        "unknown": "When an unknown number calls, ask who they are and why they’re calling",
        "task_appt": "When the clinic calls, book the earliest evening slot for me",
        "hm_svc": "If the AC technician calls, confirm any time after 3 pm on weekdays",
        "task_resched": "If a courier calls while I’m out, ask them to come back after 7 pm",
        "hm_school": "If my kid’s school calls, note what it’s about and message me right away",
        "pro_meet": "When I’m in a meeting, tell callers I’ll call back within the hour",
        "cab": "When my cab driver calls, guide them to the blue gate after the petrol pump",
        "gas": "When the gas agency calls, confirm my refill for delivery after 5 pm",
        "card": "Decline every credit card offer and ask them to remove my number",
        "insurance": "If an insurance agent calls, ask them to send the quote on WhatsApp",
        "guard": "If the building guard calls about a visitor or parcel, ask them to keep it at the gate",
        "rent": "Remind me on the 3rd of every month that rent is due on the 5th",
        "bday": "Call my family on their birthdays and wish them from me",
        "dad": "Call Dad the day before his checkups to remind him",
        "drive": "When I’m driving, tell callers I’ll call back in 30 minutes",
        "broker": "If a property broker calls, say I’m not looking and decline",
        "salon": "When the salon calls to confirm, say yes and thank them",
        "tutor": "If my kid’s tutor calls about a class change, note the new time and tell me",
        "wifi": "When the broadband technician calls, book a slot between 2 and 4 pm",
        "help": "If my house help calls about being late, say it’s fine and let me know",
        "recharge": "Remind me two days before my prepaid plan runs out",
    ]

    /// The pick an instruction is about: the one it was drafted from, or, for one the user said
    /// themselves, the pick sharing the most words with it (falling back to the first pick).
    static func useCase(for instruction: String, among picks: [String]) -> UseCase? {
        if let id = picks.first(where: { instructions[$0] == instruction }) { return useCase(id) }
        func words(_ s: String) -> Set<String> {
            Set(s.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 3 })
        }
        let said = words(instruction)
        let pool = picks.isEmpty ? useCases.map(\.id) : picks
        let best = pool.max { a, b in
            let wa = words((useCase(a)?.label ?? "") + " " + (instructions[a] ?? "") + " " + (useCase(a)?.caller ?? ""))
            let wb = words((useCase(b)?.label ?? "") + " " + (instructions[b] ?? "") + " " + (useCase(b)?.caller ?? ""))
            return wa.intersection(said).count < wb.intersection(said).count
        }
        return best.flatMap(useCase) ?? pool.first.flatMap(useCase)
    }

    static let drafting = "Writing instructions from your picks…"
    static let instructAsk = "Hold the button and say one of these, or tell me your own"
    static let listening = "Listening…"
    static let instructHeard = "Got it! Let me show you how I’ll handle that"
    static let instructSaved = "Saved! Here’s how I’ll handle it"

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
