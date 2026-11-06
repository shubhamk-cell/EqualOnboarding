"""Renders the sample-call recordings bundled in EqualOrbOnboarding/Audio.

Uses Kokoro-82M (Apache 2.0) through kokoro-onnx, on this Mac:

    python3.12 -m venv .venv && .venv/bin/pip install kokoro-onnx soundfile
    curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
    curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin

Export the list of lines from a debug build (launch with `-dumpAudio`; it writes
Documents/audio.json in the app's container), put audio.json, the model and the voices next to
this script, then:

    .venv/bin/python render_calls.py ../EqualOrbOnboarding/Audio

Existing files are skipped, so delete one to re-record it. Voices: Indian-accented English from
Kokoro's Hindi voices (hf_alpha / hm_omega for Equal, hf_beta / hm_psi for callers). Converts to AAC with macOS `afconvert`.
"""
import json, os, subprocess, sys, soundfile as sf
from kokoro_onnx import Kokoro
here = os.path.dirname(os.path.abspath(__file__))
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
k = Kokoro(os.path.join(here, "kokoro-v1.0.onnx"), os.path.join(here, "voices-v1.0.bin"))
# Indian-accented English throughout: Kokoro's Hindi-trained voices reading English phonemes.
# Equal is hf_alpha (female) or hm_omega (male); callers get the other two, by gender.
FEMALE_CALLERS = {"Mom", "Cousin", "Clinic", "School", "Salon", "House help", "Tutor"}
def caller_voice(name):
    return "hf_beta" if name in FEMALE_CALLERS else "hm_psi"
items = json.load(open(os.path.join(here, "audio.json")))
for n, it in enumerate(items):
    dst = os.path.join(out, it["file"] + ".m4a")
    if os.path.exists(dst):
        continue
    v = it["voice"]
    if v.startswith("caller:"):
        voice = caller_voice(v[7:])
    else:
        voice = "hf_alpha" if v == "equal_f" else "hm_omega"
    lang = "hi" if it["lang"] == "hi" else "en-us"
    samples, sr = k.create(it["text"], voice=voice, speed=1.0, lang=lang)
    wav = os.path.join(here, "tmp.wav")
    sf.write(wav, samples, sr)
    subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "40000", "-c", "1", wav, dst], check=True)
    print(n + 1, "/", len(items), it["file"], flush=True)
print("done")
