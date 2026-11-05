# Equal AI · Orb bubble — full setup in one go (native SwiftUI)

The “Orb bubble · full setup in one go” variation of the chat-first onboarding prototype, built natively for iOS.
The orb asks every question in a chat-style speech bubble (typing dots, then the message), and the whole setup (picks, permissions, call forwarding,
Live Voicemail) happens before Home.

## Run it
1. Open `EqualOrbOnboarding.xcodeproj` in **Xcode 16 or later** (built and tested with Xcode 26.5).
2. Swift Package Manager fetches **Lottie** (`airbnb/lottie-spm`, 4.5+). If it doesn't start: *File › Packages › Resolve Package Versions*.
3. Pick an iPhone simulator (iOS 17+) and press **Run**. For a real device, choose your team under *Signing & Capabilities*.

To replay onboarding, **long-press the “equal ai” logo on Home**. To see the system permission prompts again,
delete the app (or run `xcrun simctl privacy booted reset all ai.equal.onboarding.orbbubble`).

## The flow
1. **Splash** – six dots pop in on a spinning ring, settle into the Equal mark, the wordmark wipes in, tagline and
   “Proudly made in India” rise. Leaves after 3.8 s or on tap; the sky fades in and the orb glides in from the mark.
2. **Number** – the bubble types “What number do you get calls on?”; +91 field with the send button merged in, WhatsApp opt-in, terms.
3. **Code** – 4827 fills in digit by digit, “Verifying…”, then the real **App Tracking Transparency** prompt.
4. **Name** – “What should I call you?”.
5. **Picks** – twenty-five everyday jobs as two-per-row pills (widths follow the text), scrolling under the sticky orb. Continue curates in place: unpicked pills fade,
   the orb's dots gather into a spinning ring (“Curating sample calls from your picks…”), then the top three return as
   **sample-call cards**. Nothing plays until you tap: the waveform fills with a live timer; tap another to switch, tap play/pause/replay.
6. **Permissions** – lock-screen art; the orb explains, then the real **Notifications** prompt, then **Contacts**.
   Refusing either shows Equal's “permission required” sheet. Then Equal's own **call-data consent** dialog (asked once).
7. **Call forwarding** – looping Lottie demo, the MMI code with Copy, “Open Phone & dial” → iOS confirm → carrier reply → all steps tick.
8. **Live Voicemail** – looping Lottie demo; “Open Settings” opens a look-alike of iPhone Settings with a floating checklist
   (Apps → Phone, Live Voicemail off, Screen Unknown Callers → Never, Return to Equal AI). Steps strike through live.
9. **Welcome** – confetti, twinkling sparkles, the big orb pops in and the bubble types “Welcome to Equal, {name}!”.
   After 4.8 s it grows, blurs and fades into **Home**.
10. **Home** – Equal AI thread (rule saved, chips), example rider call, bottom tab pill and orb FAB. If forwarding was skipped,
    an “Enable Permissions” card opens a sheet to finish it.

**Everywhere:** tap the orb for a jelly squish, ripple, sparkles and a wave through the dots; drag it to stretch it on a rubber
band. Either way the bubble turns mint and retypes its line in the next language (English → हिन्दी → தமிழ் → বাংলা → English).
After the first nudge, a native language menu appears in the top bar. Back and Skip work as in the prototype.

## Onboarding V2 (experiment)
The app always starts with V1 above. On Home, the **You** tab has *Try onboarding V2* (and *Replay onboarding V1*).
V2 is the same flow, except that after the picks Equal drafts **three instructions** from them (a swipeable carousel).
Hold **Send voice note** and say one, or your own (live, on-device speech recognition; the keyboard button types one
instead). What you said lands on the right as your message (the voice note with its transcript), then the next page shows a **sample call** of how Equal will follow it, and the flow carries on to
permissions. If nothing is heard (no mic permission, or the simulator), the instruction card on screen is sent.

## What's real vs. pretend
- **Real:** App Tracking Transparency, notification and contacts prompts, copy to clipboard, opening the app's Settings page
  from the “permission required” sheet, haptics.
- **Pretend (as in the prototype):** the OTP auto-fills 4827; sample calls are scripted (no audio); iOS doesn't let apps dial
  `*`/`#` codes or deep-link into Phone settings, so the dial confirmation, carrier reply and iPhone Settings are look-alikes.

## Where things live
- `App/` – app entry (pre-parses the Lottie files), `RootView` (sky, splash → flow → home, overlays, toast, push transitions).
- `Design/` – tokens and DM Sans (optical size follows point size, like the browser), the pastel moving sky,
  the glass **Orb**, the speech bubble + typewriter (`Talk`).
- `Model/` – `AppModel` (steps, state, overlays) and `Catalog` (use cases, sample-call scripts, orb lines).
- `Screens/` – splash, number/code/name, picks + sample-call cards, permissions/forwarding/voicemail, welcome, home.
- `Overlays/` – consent dialog, decline sheet, carrier reply, Home's setup sheet, mock iPhone Settings.

Debug builds accept `-startStep <phone|otp|name|cases|instruct|permq|fwd|access|welcome|home>` (and `-variant v2`) as a launch argument
to jump straight to a screen. The shared scheme already lists `-startStep home` (unticked): *Product › Scheme ›
Edit Scheme… › Run › Arguments*, tick it and change the step.
