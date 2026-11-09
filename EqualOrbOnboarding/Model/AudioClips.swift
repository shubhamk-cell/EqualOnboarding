import Foundation

/// Natural-sounding recordings of the sample calls and voice hellos, rendered ahead of time with
/// the open Kokoro-82M voice model (Apache 2.0) and bundled as AAC. Equal's lines exist in both
/// voices (`_f` Aanya, `_m` Kabir); each caller has a voice of their own (`_c`).
/// The recordings can't know the user's name, so they say “they” / “you” where the scripts on
/// screen use it. Anything without a recording falls back to the system voices.
enum AudioClips {
    /// A script line as it's recorded: the name placeholder `{n}` reworded away.
    static func spoken(_ line: String) -> String {
        var s = line
        let swaps: [(String, String)] = [
            ("Hi {n}, ", "Hi there, "),
            ("I’ll let {n} know.", "I’ll pass it on."),
            ("{n} never shares", "they never share"),
            ("I’m {n}’s assistant", "I’m the assistant on this number"),
            ("is this {n}?", "is this the right number?"),
            ("Is {n} free to talk?", "Are you free to talk?"),
            ("calling for {n}", "calling on their behalf"),
            ("pass this to {n}", "pass this on"),
            ("{n} is ", "they’re "),
            ("{n} isn’t", "they aren’t"),
            ("{n} will", "they’ll"),
            ("{n} never", "they never"),
            ("{n} asked", "they asked"),
            ("{n}", "them"),
        ]
        for (a, b) in swaps { s = s.replacingOccurrences(of: a, with: b) }
        // “They” at the start of a sentence.
        var out = ""
        var capitalise = true
        for ch in s {
            out.append(capitalise ? Character(ch.uppercased()) : ch)
            if ".!?".contains(ch) { capitalise = true } else if ch != " " { capitalise = false }
        }
        return out
    }

    /// Every sample call: the 25 picks (short script) and the four everyday calls (longer).
    static var calls: [(id: String, lines: [(speaker: String, line: String)])] {
        Catalog.useCases.map { ($0.id, Catalog.script($0, name: "{n}")) }
            + Catalog.everyday.map { ($0.id, Catalog.liveScript($0, name: "{n}")) }
    }

    static func name(call id: String, line: Int, equal: Bool, voice: Voice) -> String {
        "call_\(id)_\(line)_\(equal ? (voice.isFemale ? "f" : "m") : "c")"
    }

    static func url(call id: String, line: Int, equal: Bool, voice: Voice) -> URL? {
        Bundle.main.url(forResource: name(call: id, line: line, equal: equal, voice: voice), withExtension: "m4a")
    }

    /// The language-card hello, recorded for English and Hindi.
    static func hello(_ voice: Voice, _ l: CallLanguage) -> URL? {
        // Recorded for Aanya and Kabir only (the recording says their name).
        guard l == .english || l == .hindi, voice == .aanya || voice == .kabir else { return nil }
        return Bundle.main.url(forResource: "hello_\(l == .english ? "en" : "hi")_\(voice == .aanya ? "f" : "m")", withExtension: "m4a")
    }

    #if DEBUG
    /// Everything to record, for the render script (launch with `-dumpAudio`): file name, text,
    /// whose voice, and language.
    static func manifest() -> Data {
        var items: [[String: String]] = []
        for c in calls {
            for (i, l) in c.lines.enumerated() {
                let equal = l.speaker == "Equal AI"
                let text = spoken(l.line)
                if equal {
                    for v in [Voice.aanya, .kabir] {
                        items.append(["file": name(call: c.id, line: i, equal: true, voice: v), "text": text,
                                      "voice": v == .aanya ? "equal_f" : "equal_m", "lang": "en"])
                    }
                } else {
                    items.append(["file": name(call: c.id, line: i, equal: false, voice: .aanya), "text": text,
                                  "voice": "caller:" + l.speaker, "lang": "en"])
                }
            }
        }
        for v in [Voice.aanya, .kabir] {
            let key = v == .aanya ? "f" : "m"
            items.append(["file": "hello_en_\(key)", "text": Catalog.voiceHello(v, .english, name: "there").replacingOccurrences(of: "Hi there,", with: "Hi there!"),
                          "voice": "equal_\(key)", "lang": "en"])
            items.append(["file": "hello_hi_\(key)", "text": Catalog.voiceHello(v, .hindi, name: "").replacingOccurrences(of: "नमस्ते ,", with: "नमस्ते!"),
                          "voice": "equal_\(key)", "lang": "hi"])
        }
        return (try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted])) ?? Data()
    }
    #endif
}
