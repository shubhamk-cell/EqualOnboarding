package ai.equal.orb.model

/** One everyday job Equal can take on, with the pretend call used to demo it. */
data class UseCase(
    val id: String,
    val emoji: String,
    val label: String,
    /** Who is on the other end of the sample call. */
    val caller: String,
    /** Caller's first line and Equal's reply. `{n}` is the user's name. */
    val callerLine: String,
    val equalLine: String,
    /** One-line summary shown after the call. */
    val summary: String,
    /** True when Equal places the call (reminders) rather than answering it. */
    val outgoing: Boolean,
)

object Catalog {
    /** The ten situations on the “What can I handle for you?” screen, in display order. */
    val useCases = listOf(
        UseCase("task_door", "🛵", "Guide delivery riders to my door", "Delivery rider",
            "I’m outside the society, which tower is it?", "Tower B, flat 402. Please use gate 2 — the guard will let you in.",
            "I guided them to your door and shared the gate number.", false),
        UseCase("bank", "🏦", "Say no to loan offers", "Bank",
            "About a pre-approved loan offer…", "{n} is busy right now. Please call back after 6 pm.",
            "I asked them to call back after 6 PM.", false),
        UseCase("task_bill", "⚡", "Remind me before bills", "You",
            "Hello?", "Hi {n}, quick reminder — your electricity bill is due in 2 days.",
            "I reminded you the electricity bill is due in 2 days.", true),
        UseCase("task_med", "💊", "Remind mom to take medicine", "Mom",
            "Hello? Who’s calling?", "Hi Aunty, it’s Equal calling for {n}. Just a reminder to take your 9 o’clock medicine.",
            "I reminded her to take her 9 o’clock medicine.", true),
        UseCase("unknown", "❓", "Screen calls from strangers", "Unknown number",
            "Hello, is this {n}?", "I’m {n}’s assistant. May I know who’s calling and why?",
            "I asked who they are and why they called.", false),
        UseCase("task_appt", "🩺", "Book doctor appointments", "Clinic",
            "We have slots tomorrow — what time works?", "Tomorrow at 6 PM works for {n}. Please book it under their name.",
            "I booked tomorrow at 6 PM under your name.", false),
        UseCase("hm_svc", "🔧", "Schedule AC repair", "AC technician",
            "I can come at 3 today.", "3 pm works. I’ll let {n} know you’re coming.",
            "I confirmed they’ll come at 3 PM today.", false),
        UseCase("task_resched", "📦", "Reschedule Amazon couriers", "Courier",
            "Sir, I’m at your address — is anyone home?", "No one’s home right now. Could you come back after 7 PM?",
            "I asked them to come back after 7 PM.", false),
        UseCase("hm_school", "🏫", "Note my kid’s school calls", "School",
            "Calling about the PTM on Friday.", "Thank you! I’ll pass this to {n} — they’ll call back soon.",
            "I noted it’s about the PTM on Friday.", false),
        UseCase("pro_meet", "💼", "Take messages in meetings", "Caller",
            "Is {n} free to talk?", "{n} is in a meeting — they’ll call you back within the hour.",
            "I said you’re in a meeting and will call back within the hour.", false),
    )

    fun useCase(id: String) = useCases.firstOrNull { it.id == id }

    /** Tints for the emoji tiles on the three curated sample-call cards. */
    val cardTints = listOf(0xFFE6D5L, 0xE2F8E6L, 0xECE6FFL)

    /** The four lines of a sample call. */
    fun script(u: UseCase, name: String): List<Pair<String, String>> {
        fun f(s: String) = s.replace("{n}", name)
        return listOf(u.caller to f(u.callerLine), "Equal AI" to f(u.equalLine),
            u.caller to "Okay, got it. Thank you!", "Equal AI" to "You’re welcome! I’ll let $name know.")
    }

    // MARK: Orb lines

    enum class Ask { Phone, Otp, Name, Cases, PermQ, Access, Welcome }

    fun title(ask: Ask, name: String = "") = when (ask) {
        Ask.Phone -> "What number do you get calls on?"
        Ask.Otp -> "Enter the code I just texted you"
        Ask.Name -> "What should I call you?"
        Ask.Cases -> "What can I handle for you? Pick any"
        Ask.PermQ -> notifLine
        Ask.Access -> "Send missed calls to me"
        Ask.Welcome -> "Welcome to Equal, $name!"
    }

    const val notifLine = "To tell you how every call went, I’ll need to send you notifications."
    const val contactsLine = "And to greet your people by name, I’ll need access to your contacts."
    const val curating = "Curating sample calls from your picks…"
    const val curated = "Here’s how I’ll handle your top picks"

    /** The three call-forwarding cases set up over USSD on Android. */
    val forwardingCases = listOf("When you’re busy", "When you don’t answer", "When you’re unreachable")

    /** Playful lines when someone taps or drags the orb: they nod to the play, then steer back. */
    fun playful(ask: Ask): List<String> = when (ask) {
        Ask.Phone -> listOf("Fun as this is, I can’t call you back without a number 😄", "Wheee! Okay — your number, and I’m all yours.",
            "I’m flattered. Now, what number do your calls come to?", "Careful, I bounce. Your number goes just below 👇",
            "Let’s make this official — pop your number in?")
        Ask.Otp -> listOf("Shh, I’m watching for that code 👀", "Almost there! Just the 4 digits I texted you.",
            "Easy — still waiting on that little code.", "Boing! Now, the code from your SMS?")
        Ask.Name -> listOf("Okay, you’ve met me. What should I call you?", "You know my name… I don’t know yours yet 🙂",
            "Wheee! So, who am I answering calls for?", "Before we go on a ride — what’s your name?", "Nice to meet you too. Name, please?")
        Ask.Cases -> listOf("I’m better at errands than acrobatics. Pick a few?", "Okay, okay! Now show me what I should handle.",
            "Tap a couple below — that’s where I really shine ✨", "Fun! Now point me at some real work 👇",
            "You can’t keep me busy like this forever. Pick a task?")
        Ask.Welcome -> listOf("We’re nearly there!", "Almost home 🏡")
        else -> listOf("Okay, okay — back to it?", "Wheee! Now, where were we?", "I could do this all day. Shall we continue?")
    }
}
