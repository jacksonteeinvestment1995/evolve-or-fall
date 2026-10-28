"""Re-encodes every music track so they all sit at the same loudness and loop cleanly.
  * trailing silence is cut off (it made an audible gap every time a track looped),
  * each track is gain-adjusted to TARGET_LUFS (intro and loop of one piece share a gain, so there is no jump),
  * mono, Ogg Vorbis q2, with a peak limiter so nothing clips.
Run from the project folder: python art/tools/normalize_music.py <folder with the original .ogg files> <folder with the synth .wav files>
Needs ffmpeg on the PATH."""
import os
import re
import subprocess
import sys

TARGET_LUFS = -16.0
TRIM_END = {"boss1", "boss3", "dk_metal_chromatic"}          # these end in 1.5 to 3 seconds of silence
PAIRS = {"boss4_intro": "boss4_loop", "dk_nene8_intro": "dk_nene8_loop", "dk_nene9_intro": "dk_nene9_loop"}  # intro -> loop


def run(args):
    return subprocess.run(args, capture_output=True, text=True)


def loudness(path, af_prefix=""):
    r = run(["ffmpeg", "-nostats", "-i", path, "-af", af_prefix + "ebur128=peak=true", "-f", "null", "-"])
    m = re.findall(r"I:\s*(-?[\d.]+) LUFS", r.stderr)
    return float(m[-1])


def encode(src, dst, gain_db, trim_end):
    chain = []
    if trim_end:
        chain.append("areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse")
    chain.append("volume=%.2fdB" % gain_db)
    chain.append("alimiter=limit=0.93:level=disabled")
    r = run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", ",".join(chain), "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", dst])
    if r.returncode != 0:
        raise SystemExit(r.stderr)


def main():
    src_dir, wav_dir = sys.argv[1], sys.argv[2]
    here = os.path.join(os.path.dirname(__file__), "..", "..")
    music_out = os.path.join(here, "audio", "music")
    synth_out = os.path.join(here, "audio", "synth")
    gains = {}
    for f in sorted(os.listdir(src_dir)):
        if not f.endswith(".ogg"):
            continue
        name = f[:-4]
        if name in PAIRS:
            continue
        trimmed = ("areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,") if name in TRIM_END else ""
        gains[name] = TARGET_LUFS - loudness(os.path.join(src_dir, f), trimmed)
    for intro, loop in PAIRS.items():
        gains[intro] = gains[loop]
    for name, g in gains.items():
        encode(os.path.join(src_dir, name + ".ogg"), os.path.join(music_out, name + ".ogg"), g, name in TRIM_END)
        print("%-24s gain %+5.1f dB" % (name, g))
    for f in sorted(os.listdir(wav_dir)):
        if f.endswith(".wav"):
            name = f[:-4]
            g = TARGET_LUFS - loudness(os.path.join(wav_dir, f))
            encode(os.path.join(wav_dir, f), os.path.join(synth_out, name + ".ogg"), g, False)
            print("synth %-18s gain %+5.1f dB" % (name, g))


if __name__ == "__main__":
    main()
