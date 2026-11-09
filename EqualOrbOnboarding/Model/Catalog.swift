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

    /// V8's voice-note covers: a profile photo of who's on the call (AI-generated, fictional
    /// people), one per kind of caller and shared by the options they cover.
    static func cover(_ id: String) -> String? {
        switch id {
        case "task_door", "task_resched", "ev_rider": "CoverDelivery"
        case "bank", "card", "insurance", "broker", "ev_kyc", "ev_loan": "CoverSales"
        case "task_bill", "rent", "recharge": "CoverYou"
        case "task_med": "CoverMom"
        case "dad": "CoverDad"
        case "unknown", "ev_unknown": "CoverUnknown"
        case "task_appt", "salon": "CoverReception"
        case "hm_svc", "wifi", "gas": "CoverTechnician"
        case "hm_school", "tutor": "CoverTeacher"
        case "pro_meet", "drive", "bday": "CoverFriend"
        case "cab": "CoverCab"
        case "guard": "CoverGuard"
        case "help": "CoverHelp"
        default: nil
        }
    }

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
        case .cases: "I can handle all kinds of calls! Tap the ones that matter most to you"
        case .permq: notifLine
        case .fwd: "One code, and all calls you can’t or don’t want to take come to me"
        case .access: "Now let me answer instead of voicemail"
        case .welcome: "Welcome to Equal, \(name)!"
        }
    }

    /// V7's asks, beside the sample call each would have helped with.
    static let ctxNotifications = "I just handled this call for you. Want a ping every time I do? Without it, you might miss calls that matter"
    static let ctxContacts = "I didn’t know this number, so I asked who it was. Allow contacts and I’ll greet your people by name"
    /// iOS 27+, after Copy: where to go next, with the guide floating along.
    static let fwdCopied = "Copied! Now swipe up, open Phone and paste it"
    static let notifLine = "To tell you how every call went, I’ll need to send you notifications."
    static let contactsLine = "And to greet your people by name, I’ll need access to your contacts."
    static let curating = "Curating sample calls from your picks…"
    /// V8, on the name screen once the name is in.
    static func genderAsk(_ name: String) -> String {
        "Nice to meet you, \(name)! What’s your gender? I’ll use it to address you on calls"
    }
    /// V8's picks: exactly three, and they turn into sample calls on the spot. Only a glimpse:
    /// the line says Equal takes all calls, so nobody thinks the three limit it.
    /// V8, after the sample calls.
    static let assistantAsk = "Now that you’ve seen me in action, how would you like me to\u{00A0}sound?"
    static let pickThree = "I can handle all your calls. Select any 3 to get a\u{00A0}glimpse"
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
        title(.cases, name: ""): [.hi: "मैं हर तरह के कॉल संभाल सकती हूँ! आपके लिए जो सबसे ज़रूरी हैं, उन पर टैप कीजिए",
                                  .ta: "எல்லா வகை அழைப்புகளையும் நான் கவனிப்பேன்! உங்களுக்கு முக்கியமானவற்றைத் தட்டுங்கள்",
                                  .bn: "সব ধরনের কল আমি সামলাতে পারি! আপনার কাছে যেগুলো জরুরি, সেগুলোয় ট্যাপ করুন"],
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
        langVoiceTitle: [.hi: "आपके कॉल करने वाले कौन-सी भाषाएँ बोलते हैं? 3 तक चुनिए",
                         .ta: "உங்களை அழைப்பவர்கள் எந்த மொழிகள் பேசுகிறார்கள்? 3 வரை தேர்ந்தெடுங்கள்",
                         .bn: "যাঁরা আপনাকে ফোন করেন, তাঁরা কোন ভাষায় কথা বলেন? ৩টে পর্যন্ত বেছে নিন"],
        langLimit: [.hi: "मैं ज़्यादा से ज़्यादा 3 भाषाओं में बात कर सकती हूँ। पहले किसी एक को हटाइए",
                    .ta: "நான் அதிகபட்சம் 3 மொழிகளில் பேசுவேன். முதலில் ஒன்றை நீக்குங்கள்",
                    .bn: "আমি বড়জোর ৩টে ভাষায় কথা বলতে পারি। আগে একটা সরান"],
        listenAfter: [.hi: "रोज़ मैं आपकी कैसे मदद करूँगी, ये तो बस कुछ झलकियाँ हैं",
                      .ta: "தினமும் நான் உங்களுக்கு உதவும் வழிகளில் இவை சில மட்டுமே",
                      .bn: "রোজ আমি আপনাকে কীভাবে সাহায্য করব, এগুলো তার কয়েকটা মাত্র"],
        listenTitle: [.hi: "देखिए, आपके रोज़ के कॉल पर मैं कैसे काम करती हूँ",
                      .ta: "உங்கள் அன்றாட அழைப்புகளில் நான் செயல்படுவதைப் பாருங்கள்",
                      .bn: "আপনার রোজকার কলে আমাকে কাজ করতে দেখুন"],
        genderAsk("{name}"): [.hi: "आपसे मिलकर अच्छा लगा, {name}! आपका जेंडर क्या है? कॉल पर आपको उसी हिसाब से संबोधित करूँगी",
                              .ta: "உங்களைச் சந்தித்ததில் மகிழ்ச்சி, {name}! உங்கள் பாலினம் என்ன? அழைப்புகளில் உங்களை அப்படியே குறிப்பிடுவேன்",
                              .bn: "আপনার সঙ্গে আলাপ করে ভালো লাগল, {name}! আপনার লিঙ্গ কী? কলে আপনাকে সেভাবেই সম্বোধন করব"],
        assistantAsk: [.hi: "अब आपने मुझे काम करते देख लिया, बताइए मेरी आवाज़ कैसी हो?",
                       .ta: "என்னைச் செயலில் பார்த்துவிட்டீர்கள், என் குரல் எப்படி இருக்க வேண்டும்?",
                       .bn: "আমাকে কাজ করতে দেখলেন, এবার বলুন আমার গলা কেমন হবে?"],
        pickThree: [.hi: "मैं आपके सारे कॉल संभाल सकती हूँ। एक झलक के लिए कोई भी 3 चुनिए",
                    .ta: "உங்கள் எல்லா அழைப்புகளையும் நான் கவனிப்பேன். ஒரு பார்வைக்கு ஏதேனும் 3-ஐத் தேர்ந்தெடுங்கள்",
                    .bn: "আপনার সব কল আমি সামলাতে পারি। এক ঝলক দেখতে যেকোনো ৩টে বেছে নিন"],
        title(.welcome, name: "{name}"): [.hi: "Equal में आपका स्वागत है, {name}!",
                                          .ta: "Equal-க்கு வரவேற்கிறோம், {name}!",
                                          .bn: "Equal-এ স্বাগতম, {name}!"],
    ]

    /// `line` (English) in `lang`; lines without a translation stay in English.
    static func translate(_ line: String, to lang: Lang) -> String {
        guard lang != .en else { return line }
        if let t = translations[line]?[lang] { return t }
        // The welcome and gender lines carry the user's name.
        for key in [title(.welcome, name: "{name}"), genderAsk("{name}")] {
            let parts = key.components(separatedBy: "{name}")
            if line.hasPrefix(parts[0]), line.hasSuffix(parts[1]), let t = translations[key]?[lang] {
                let name = String(line.dropFirst(parts[0].count).dropLast(parts[1].count))
                return t.replacingOccurrences(of: "{name}", with: name)
            }
        }
        return line
    }

    static let forwardingCode = "**67*04048938092#"

    // MARK: Everyday calls (V5)

    /// Four calls everyone gets, for the versions that show value without asking anything.
    static let everyday: [UseCase] = [
        UseCase(id: "ev_rider", emoji: "🛵", label: "Guided a rider to your door", caller: "Delivery rider",
                callerLine: "Hello, I’m outside the society — which tower is it?",
                equalLine: "Hi! It’s Tower B, flat 402. Please use gate 2, the guard knows you’re coming.",
                summary: "I guided the rider to your door and shared the gate number.", outgoing: false),
        UseCase(id: "ev_kyc", emoji: "🏦", label: "Stopped a fake KYC call", caller: "“Bank KYC desk”",
                callerLine: "Your KYC is pending. Please share the OTP you just received to avoid a block.",
                equalLine: "{n} never shares OTPs on a call. If this is genuine, please write to them from the bank’s official email.",
                summary: "They asked for an OTP. I refused and flagged it as a likely scam.", outgoing: false),
        UseCase(id: "ev_unknown", emoji: "❓", label: "Found out who was calling", caller: "Unknown number",
                callerLine: "Hello, is this {n}?",
                equalLine: "I’m {n}’s assistant. May I know who’s calling and what it’s about?",
                summary: "It was the society office about Sunday’s water cut. I noted the timings.", outgoing: false),
        UseCase(id: "ev_loan", emoji: "💸", label: "Said no to a loan offer", caller: "Loan agent",
                callerLine: "Sir, you have a pre-approved personal loan of 5 lakhs at a special rate…",
                equalLine: "Thanks, but {n} isn’t interested. Please remove this number from your list.",
                summary: "A loan offer. I declined and asked them not to call again.", outgoing: false),
    ]

    /// The everyday calls in `l` (V5 speaks in the language chosen up front). Hindi and Hinglish
    /// have their own scripts; the other languages keep the English calls.
    static func everyday(in l: CallLanguage) -> [UseCase] {
        guard let local = everydayLocal[l] else { return everyday }
        return everyday.map { u in
            guard let c = local[u.id] else { return u }
            return UseCase(id: u.id, emoji: u.emoji, label: c.label, caller: c.caller, callerLine: c.callerLine,
                           equalLine: c.equalLine, summary: c.summary, outgoing: false)
        }
    }

    /// One everyday call in another language: its card, and the rest of the conversation
    /// (`true` = the caller speaks).
    private struct LocalCall {
        let label, caller, callerLine, equalLine, summary: String
        let rest: [(Bool, String)]
    }

    private static let everydayLocal: [CallLanguage: [String: LocalCall]] = [
        .hinglish: [
            "ev_rider": LocalCall(label: "Rider ko ghar tak guide kiya", caller: "Delivery rider",
                                  callerLine: "Hello, main society ke bahar hoon — kaunsa tower hai?",
                                  equalLine: "Hi! Tower B, flat 402. Gate 2 se aaiye, guard ko pata hai.",
                                  summary: "Rider ko gate number bata ke ghar tak guide kiya.",
                                  rest: [(true, "Gate 2, theek hai. Guard ke paas chhod doon?"),
                                         (false, "Nahi, upar le aaiye — {n} ghar pe hain. Thank you!"),
                                         (true, "Theek hai, do minute mein aata hoon.")]),
            "ev_kyc": LocalCall(label: "Fake KYC call roki", caller: "“Bank KYC desk”",
                                callerLine: "Aapka KYC pending hai. Block se bachne ke liye abhi aaya OTP bata dijiye.",
                                equalLine: "{n} call pe kabhi OTP share nahi karte. Agar ye genuine hai, toh bank ki official email se likhiye.",
                                summary: "Unhone OTP maanga. Maine mana kiya aur ise scam flag kar diya.",
                                rest: [(true, "Ma’am, urgent hai, aaj hi account block ho jayega."),
                                       (false, "Bank kabhi call pe OTP nahi maangta. Main ye call ab end kar rahi hoon.")]),
            "ev_unknown": LocalCall(label: "Pata kiya kaun call kar raha tha", caller: "Unknown number",
                                    callerLine: "Hello, kya ye {n} hain?",
                                    equalLine: "Main {n} ki assistant hoon. Aap kaun bol rahe hain, aur kis baare mein?",
                                    summary: "Society office tha — Sunday ko paani band rahega. Timings note kar li.",
                                    rest: [(true, "Society office se. Sunday ko 10 se 2 paani band rahega."),
                                           (false, "Batane ke liye shukriya. Main {n} ko abhi bata deti hoon."),
                                           (true, "Thank you, bye.")]),
            "ev_loan": LocalCall(label: "Loan offer ko mana kiya", caller: "Loan agent",
                                 callerLine: "Sir, aapke liye 5 lakh ka pre-approved personal loan hai, special rate pe…",
                                 equalLine: "Thanks, par {n} interested nahi hain. Please ye number apni list se hata dijiye.",
                                 summary: "Loan offer tha. Maine mana kiya aur dobara call na karne ko kaha.",
                                 rest: [(true, "Bas do minute sir, ye rate sirf aaj ke liye hai…"),
                                        (false, "Samajh gayi. {n} ko loan nahi chahiye. Have a good day!")]),
        ],
        .hindi: [
            "ev_rider": LocalCall(label: "राइडर को घर तक पहुँचाया", caller: "डिलीवरी राइडर",
                                  callerLine: "हैलो, मैं सोसाइटी के बाहर हूँ — कौन सा टावर है?",
                                  equalLine: "नमस्ते! टावर B, फ़्लैट 402. गेट 2 से आइए, गार्ड को पता है।",
                                  summary: "राइडर को गेट नंबर बताकर घर तक पहुँचाया।",
                                  rest: [(true, "गेट 2, ठीक है। गार्ड के पास छोड़ दूँ?"),
                                         (false, "नहीं, ऊपर ले आइए — {n} घर पर हैं। धन्यवाद!"),
                                         (true, "ठीक है, दो मिनट में आता हूँ।")]),
            "ev_kyc": LocalCall(label: "नकली KYC कॉल रोकी", caller: "“बैंक KYC डेस्क”",
                                callerLine: "आपका KYC पेंडिंग है। ब्लॉक से बचने के लिए अभी आया OTP बताइए।",
                                equalLine: "{n} कॉल पर कभी OTP नहीं बताते। अगर यह असली है, तो बैंक की आधिकारिक ईमेल से लिखिए।",
                                summary: "उन्होंने OTP माँगा। मैंने मना किया और इसे स्कैम बताकर फ़्लैग किया।",
                                rest: [(true, "मैडम, ज़रूरी है, आज ही अकाउंट ब्लॉक हो जाएगा।"),
                                       (false, "बैंक कभी कॉल पर OTP नहीं माँगता। मैं यह कॉल अब ख़त्म कर रही हूँ।")]),
            "ev_unknown": LocalCall(label: "पता किया कौन कॉल कर रहा था", caller: "अनजान नंबर",
                                    callerLine: "हैलो, क्या यह {n} हैं?",
                                    equalLine: "मैं {n} की असिस्टेंट हूँ। आप कौन बोल रहे हैं, और किस बारे में?",
                                    summary: "सोसाइटी ऑफ़िस था — रविवार को पानी बंद रहेगा। समय नोट कर लिया।",
                                    rest: [(true, "सोसाइटी ऑफ़िस से। रविवार को 10 से 2 पानी बंद रहेगा।"),
                                           (false, "बताने के लिए शुक्रिया। मैं {n} को अभी बता देती हूँ।"),
                                           (true, "धन्यवाद, नमस्ते।")]),
            "ev_loan": LocalCall(label: "लोन ऑफ़र को मना किया", caller: "लोन एजेंट",
                                 callerLine: "सर, आपके लिए 5 लाख का प्री-अप्रूव्ड पर्सनल लोन है, ख़ास रेट पर…",
                                 equalLine: "धन्यवाद, पर {n} को इसमें रुचि नहीं है। कृपया यह नंबर अपनी लिस्ट से हटा दीजिए।",
                                 summary: "लोन ऑफ़र था। मैंने मना किया और दोबारा कॉल न करने को कहा।",
                                 rest: [(true, "बस दो मिनट सर, यह रेट सिर्फ़ आज के लिए है…"),
                                        (false, "समझ गई। {n} को लोन नहीं चाहिए। आपका दिन शुभ हो!")]),
        ],
    ]

    /// Longer calls for the live transcript (V5), so they feel like a real conversation.
    static func liveScript(_ u: UseCase, name: String, language: CallLanguage = .english) -> [(speaker: String, line: String)] {
        let f = { (s: String) in s.replacingOccurrences(of: "{n}", with: name) }
        let me = "Equal AI"
        if let c = everydayLocal[language]?[u.id] {
            return [(c.caller, f(c.callerLine)), (me, f(c.equalLine))] + c.rest.map { ($0.0 ? c.caller : me, f($0.1)) }
        }
        switch u.id {
        case "ev_rider":
            return [(u.caller, f(u.callerLine)), (me, f(u.equalLine)),
                    (u.caller, "Gate 2, okay. Should I leave it with the guard?"),
                    (me, f("No, please bring it up — {n} is home. Thank you!")),
                    (u.caller, "Okay, coming up in two minutes.")]
        case "ev_kyc":
            return [(u.caller, f(u.callerLine)), (me, f(u.equalLine)),
                    (u.caller, "Ma’am, it’s urgent, your account will be blocked today."),
                    (me, "Banks never ask for OTPs on a call. I’m ending this call now."),]
        case "ev_unknown":
            return [(u.caller, f(u.callerLine)), (me, f(u.equalLine)),
                    (u.caller, "This is the society office. Water will be off on Sunday from 10 to 2."),
                    (me, f("Thanks for letting us know. I’ll tell {n} right away.")),
                    (u.caller, "Thank you, bye.")]
        case "ev_loan":
            return [(u.caller, f(u.callerLine)), (me, f(u.equalLine)),
                    (u.caller, "Just two minutes, sir, the rate is only for today…"),
                    (me, f("I understand. {n} isn’t looking for a loan. Have a good day!"))]
        default:
            return script(u, name: name)
        }
    }

    // MARK: Lines for the newer versions

    /// The sample-call pages (V3, V5) open with this.
    static let listenTitle = "See me in action on your everyday calls"
    /// V3's calls: the kinds Equal handles most.
    static let commonCalls = ["task_door", "bank", "unknown", "task_resched", "task_appt", "pro_meet"]
    /// Said after the first sample call: these are only a taste of everyday help.
    static let listenAfter = "These are just a few of the ways I’ll help you every day"

    static let langVoiceTitle = "Which languages do your callers speak? Pick up to 3"
    /// Said when a fourth language is tapped.
    static let langLimit = "I can switch between 3 at most. Tap one to remove it first"

    /// What a voice says when previewed, in the chosen language.
    static func voiceHello(_ voice: Voice, _ l: CallLanguage, name: String) -> String {
        let v = voice.name
        switch l {
        case .english: return "Hi \(name), I’m \(v). I’ll take your calls from now on."
        case .hindi: return "नमस्ते \(name), मैं \(v) हूँ। अब से आपके कॉल मैं \(voice.isFemale ? "संभालूँगी" : "संभालूँगा")।"
        case .hinglish: return "Hi \(name), main \(v) hoon. Ab se aapke calls main \(voice.isFemale ? "sambhaalungi" : "sambhaalunga")."
        case .tamil: return "வணக்கம் \(name), நான் \(v). இனி உங்கள் அழைப்புகளை நான் பார்த்துக்கொள்கிறேன்."
        case .telugu: return "నమస్తే \(name), నేను \(v). ఇకపై మీ కాల్స్ నేను చూసుకుంటాను."
        case .kannada: return "ನಮಸ್ಕಾರ \(name), ನಾನು \(v). ಇನ್ನು ಮುಂದೆ ನಿಮ್ಮ ಕರೆಗಳನ್ನು ನಾನು ನೋಡಿಕೊಳ್ಳುತ್ತೇನೆ."
        case .bengali: return "নমস্কার \(name), আমি \(v)। এখন থেকে আপনার কল আমি সামলাব।"
        case .marathi: return "नमस्कार \(name), मी \(v). आतापासून तुमचे कॉल मी सांभाळेन."
        case .malayalam: return "നമസ്കാരം \(name), ഞാൻ \(v). ഇനി നിങ്ങളുടെ കോളുകൾ ഞാൻ നോക്കിക്കൊള്ളാം."
        }
    }
}
