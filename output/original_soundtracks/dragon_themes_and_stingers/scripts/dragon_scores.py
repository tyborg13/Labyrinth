"""Authored symbolic scores: six dragon boss themes and three stingers.

Every note below is an explicit, hand-authored event. Tokens read
``beat:pitch:duration[:vNN][:tr]`` inside one 4/4 bar; beats may be fractions
(``2+2/3``), ``vNN`` overrides velocity and ``tr`` marks bowed tremolo. The
approved Thorns in the Dark v02 string-ensemble patches are the starting palette.
"""
from __future__ import annotations

import copy
from fractions import Fraction
from pathlib import Path
import sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "project.godot").exists())
CASE = Path(__file__).resolve().parents[1]
THORNS = ROOT / "output/original_soundtracks/thorns_string_revision"
sys.path.insert(0, str(THORNS / "scripts"))
import build_thorns as thorns  # noqa: E402  (also exposes the approved string/v02/v01 engines)

v01 = thorns.v01
THORNS_PATCHES = copy.deepcopy(thorns.arrange()["patches"])
THEMES = ["01_zekarion_the_raging_tempest", "02_tharokh_the_worldspine", "03_vyraketh_the_cinder_crown",
          "04_vaeloryx_the_hollow_gale", "05_iskaldra_the_rime_tyrant", "06_noctyrax_the_last_eclipse"]
STINGERS = ["07_stinger_level_up", "08_stinger_rare_reward", "09_stinger_boss_defeated"]
SLUGS = THEMES + STINGERS
STRING_LANES = {"violin_1", "violin_2", "viola", "cello"}
DRUM_GATES = {36: .28, 38: .20, 41: .20, 42: .10}
NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]


def num(text):
    return float(sum(Fraction(part) for part in str(text).split("+")))


def name(midi):
    return f"{NAMES[midi % 12]}{midi // 12 - 1}"


def pitch_of(token):
    return int(token) if token.isdigit() else v01.pitch(token)


# ----------------------------------------------------------------- score scaffolding

def new_score(slug, title, bpm, bars, key, mood, kind, identity):
    patches = copy.deepcopy(THORNS_PATCHES)
    return {"schema_version": 1, "version": "v01", "slug": slug, "title": title, "kind": kind,
            "bpm": bpm, "bars": bars, "beats_per_bar": 4, "key": key, "mood": mood,
            "source_kind": "original_authored_symbolic_composition", "lead_instrument": "violin_1",
            "palette": "Thorns in the Dark v02 string ensemble (violins/viola over pluck, bass, restrained drums)",
            "identity": identity, "patches": patches, "mix": {}, "notes": [], "harmony": [], "sections": []}


def bell_patch(**changes):
    patch = copy.deepcopy(v01.PATCHES["lantern_mallet"])
    patch.update(changes)
    return patch


def cello_patch(**changes):
    patch = copy.deepcopy(THORNS_PATCHES["viola"])
    patch.update({"program": 42, "pan": .10, "wet": .26, "attack_seconds": .085, "release_seconds": .28,
                  "vibrato_cents": 5, "vibrato_hz": 4.4, "bow_noise": .0034, "lowpass_hz": 2400})
    patch.update(changes)
    return patch


def mix_plan(**offsets):
    """Stem loudness = the approved Thorns v02 calibration target for a reference lane + offset (LU)."""
    plan = {lane: [lane, 0.0] for lane in ["violin_1", "violin_2", "viola", "drums", "bowed_veil",
                                           "hollow_bass", "thread_pluck"]}
    for lane, value in offsets.items():
        plan[lane] = list(value) if isinstance(value, (list, tuple)) else [plan.get(lane, [lane])[0], float(value)]
    return plan


def line(s, part, bars, velocity, start_bar=0):
    for bar, text in enumerate(bars, start_bar):
        for i, token in enumerate(text.split()):
            fields = token.split(":")
            vel, tremolo = velocity - 3 * (i % 2), False
            for flag in fields[3:]:
                if flag == "tr":
                    tremolo = True
                elif flag.startswith("v"):
                    vel = int(flag[1:])
                else:
                    raise ValueError(f"Unknown flag in {token}")
            v01.add(s, part, bar, num(fields[0]), num(fields[2]), pitch_of(fields[1]), vel)
            if tremolo:
                s["notes"][-1]["articulation"] = "tremolo"


def progression(s, table, bars):
    """Bars hold 'Chord' or 'Chord Other@beat'. Returns (start, end, key) harmonic segments."""
    segments = []
    for bar, text in enumerate(bars):
        labels, triads = [], []
        for part in text.split():
            key, _, at = part.partition("@")
            segments.append([bar * 4 + (num(at) if at else 0.0), None, key])
            labels.append(table[key][0])
            triads.append(table[key][4])
        s["harmony"].append({"bar": bar + 1, "chord": " | ".join(labels), "triads": triads})
    for current, following in zip(segments, segments[1:]):
        current[1] = following[0]
    segments[-1][1] = float(s["bars"] * 4)
    return segments


def chord_at(segments, table, beat):
    return next(table[key] for start, end, key in segments if start <= beat + 1e-9 < end)


def pad(s, segments, table, velocity=59):
    merged = []
    for start, end, key in segments:
        if merged and merged[-1][2] == key:
            merged[-1][1] = end
        else:
            merged.append([start, end, key])
    for start, end, key in merged:
        if table[key][2]:
            v01.add(s, "bowed_veil", 0, start, end - start - .10, table[key][2], velocity)


def groove(s, part, segments, table, plan):
    """plan: one event list per bar. Bass (beat, dur, interval, vel); pluck/bell
    (beat, dur, chord-tone index, vel); drums (beat, MIDI drum note, vel)."""
    for bar, events in enumerate(plan):
        for event in events:
            at = bar * 4 + event[0]
            chord = chord_at(segments, table, at)
            if part == "drums":
                v01.add(s, part, 0, at, DRUM_GATES[event[1]], event[1], event[2])
            elif part == "hollow_bass":
                v01.add(s, part, 0, at, event[1], v01.pitch(chord[1]) + event[2], event[3])
            else:
                v01.add(s, part, 0, at, event[1], chord[3][event[2]], event[3])


def terrace(s, spans):
    """Authored dynamic terraces: (first bar, last bar, {part: velocity change}) with 1-based bars."""
    for first, last, changes in spans:
        for n in s["notes"]:
            if n["instrument"] in changes and (first - 1) * 4 <= n["beat"] < last * 4:
                n["velocity"] = max(1, min(127, n["velocity"] + changes[n["instrument"]]))


def seq(*runs):
    plan = []
    for pattern, count in runs:
        plan.extend([pattern] * count)
    return plan


def finish(s):
    lanes = {n["instrument"] for n in s["notes"]}
    s["patches"] = {k: v for k, v in s["patches"].items() if k in lanes}
    s["mix"] = {k: v for k, v in s["mix"].items() if k in lanes}
    missing = lanes - set(s["patches"]) | lanes - set(s["mix"])
    if missing:
        raise ValueError(f"{s['slug']}: lanes without patch/mix plan: {sorted(missing)}")
    s["notes"].sort(key=lambda n: (n["beat"], n["instrument"], n["pitch"]))
    return s


def cell(start, octave_notes=(0, 5, 4, 5, 7, 8)):
    """Vyraketh's 'ember' cell: fifth, leap to root, leading-tone flick, climb to the minor third."""
    beats, gates = [0, .5, 1, 1.25, 1.5, 2], [.45, .45, .2, .2, .45, 1.9]
    base = v01.pitch(start)
    return " ".join(f"{b}:{name(base + o)}:{g}" for b, o, g in zip(beats, octave_notes, gates))


def hammer(a, b):
    """Driving detached eighths, 3+3+2 weighted: a a b a a b a b."""
    return " ".join(f"{i * .5}:{p}:.4" for i, p in enumerate([a, a, b, a, a, b, a, b]))


def gust(first, run, hold=1.9):
    """A held note, then six connected triplet eighths rushing to the next bar (Vaeloryx)."""
    beats = ["2", "7/3", "8/3", "3", "10/3", "11/3"]
    return f"0:{first}:{hold} " + " ".join(f"{b}:{p}:1/3" for b, p in zip(beats, run.split()))


# =================================================================== 1. Zekarion

def zekarion():
    s = new_score(THEMES[0], "Zekarion, the Raging Tempest", 156, 32,
                  "F# minor; Phrygian G-natural flashes, German-sixth D7 and C#7(b9) strikes",
                  "Lightning boss: a jagged dotted-sixteenth zigzag over 3+3+2 stabs, restless tremolo and crackle.",
                  "loop_theme", {"dragon": "Zekarion, the Raging Tempest", "tonic": "F#", "element": "lightning",
                                 "motif": "F#-C#-G-F# zigzag in dotted sixteenths (3+3+3+3+2+2), the G natural as a flash",
                                 "relation_to_thorns": "Same ensemble and minor-key combat pulse; 40 BPM faster, F# not C, "
                                                       "syncopated 3+3+2 instead of Thorns' even eighths."})
    p = s["patches"]
    p["violin_1"].update(attack_seconds=.03, release_seconds=.12, bow_noise=.0045, vibrato_cents=9,
                         vibrato_hz=5.3, lowpass_hz=3400)
    p["violin_2"].update(attack_seconds=.04, tremolo_division=4, tremolo_depth=.6)
    p["viola"].update(attack_seconds=.045, tremolo_division=4, tremolo_depth=.6)
    p["drums"].update(lowpass_hz=1900, wet=.08)
    p["thread_pluck"].update(lowpass_hz=1300)
    s["mix"] = mix_plan(violin_1=.75, violin_2=.5, viola=.5, drums=1.0, thread_pluck=1.0, bowed_veil=-1.0)
    T = {"F#m": ("F#m", "F#1", "A3", ["F#3", "C#4", "F#4", "A3"], "F#m"),
         "Bm": ("Bm", "B1", "D4", ["B2", "F#3", "B3", "D3"], "Bm"),
         "D7": ("D7 (German-sixth colour)", "D2", "C4", ["D3", "A3", "C4", "F#3"], "D"),
         "C#7": ("C#7", "C#2", "B3", ["C#3", "G#3", "C#4", "E#3"], "C#"),
         "C#7b9": ("C#7(b9)", "C#2", "D4", ["C#3", "G#3", "D4", "E#3"], "C#"),
         "G": ("G (Neapolitan)", "G1", "B3", ["G2", "D3", "G3", "B2"], "G"),
         "Dmaj7": ("Dmaj7", "D2", "C#4", ["D3", "A3", "C#4", "F#3"], "D"),
         "E": ("E(add9)", "E2", "B3", ["E3", "B3", "F#4", "G#3"], "E")}
    seg = progression(s, T, ["F#m", "F#m", "D7", "C#7", "F#m", "Bm", "G", "C#7b9",
                             "F#m", "F#m", "D7", "C#7", "Bm", "E", "Dmaj7", "C#7b9",
                             "Dmaj7", "Dmaj7", "E", "E", "F#m", "F#m", "G", "C#7b9",
                             "F#m", "F#m", "D7", "C#7", "Bm", "G", "G", "C#7b9"])
    motif = "0:F#5:.35 .75:C#5:.35 1.5:G5:.35 2.25:F#5:.6 3:C#5:.3 3.5:E5:.4"
    line(s, "violin_1", [
        motif, "0:D5:.35 .5:C#5:.35 1:B4:.35 1.5:C#5:2.3:tr",
        "0:A5:.35 .75:E5:.35 1.5:C6:.35 2.25:A5:.6 3:F#5:.3 3.5:E5:.4",
        "0:E#5:.35 .5:G#5:.35 1:B5:.35 1.5:D6:.35 2:C#6:1.7:tr",
        "0:F#5:.35 .75:C#5:.35 1.5:G5:.35 2.25:F#5:.6 3:A5:.3 3.5:C#6:.4",
        "0:D6:.35 .5:C#6:.35 1:B5:.35 1.5:F#5:2.3:tr",
        "0:B5:.35 .75:G5:.35 1.5:D6:.35 2.25:B5:.6 3:G5:.3 3.5:B5:.4",
        "0:D6:.35 .5:C#6:.35 1:B5:.35 1.5:G#5:.35 2:E#5:.35 2.5:D5:.35 3:C#5:.8",
        # 9-16: the answer rises; the zigzag moves onto B minor with a C-natural flash
        motif, "0:D5:.35 .5:E5:.35 1:F#5:.35 1.5:A5:2.3:tr",
        "0:A5:.35 .75:E5:.35 1.5:C6:.35 2.25:A5:.6 3:C6:.3 3.5:D6:.4",
        "0:C#6:.35 .5:B5:.35 1:G#5:.35 1.5:E#5:.35 2:G#5:1.7:tr",
        "0:B5:.35 .75:F#5:.35 1.5:C6:.35 2.25:B5:.6 3:F#5:.3 3.5:A5:.4",
        "0:G#5:.35 .5:F#5:.35 1:E5:.35 1.5:B5:2.3:tr",
        "0:A5:.35 .75:F#5:.35 1.5:C#6:.35 2.25:A5:.6 3:F#5:.3 3.5:E5:.4",
        "0:D5:.35 .5:E#5:.35 1:G#5:.35 1.5:B5:.35 2:D6:.35 2.5:C#6:1.3",
        # 17-24: eye of the storm - the motif in rhythmic augmentation, sequenced up by step
        "0:F#5:1.45:v64 1.5:C#5:1.45:v62 3:G5:1.45:v64", ".5:F#5:1.45:v62 2:C#5:.95:v60 3:E5:.95:v62",
        "0:G#5:1.45:v66 1.5:D#5:1.45:v64 3:A5:1.45:v68", ".5:G#5:1.45:v66 2:D#5:.95:v66 3:F#5:.95:v68",
        "0:A5:1.45:v72 1.5:E5:1.45:v70 3:B5:1.45:v74", ".5:A5:1.45:v74 2:C#6:.95:v76 3:B5:.95:v76",
        "0:D6:3.8:tr:v82", "0:D6:.35:v86 .5:C#6:.35 1:B5:.35 1.5:G#5:.35 2:E#5:.35 2.5:D5:.35 3:C#5:.35 3.5:E#5:.4",
        # 25-32: full strike and tutti turnaround
        motif, "0:D5:.35 .5:C#5:.35 1:B4:.35 1.5:C#5:1.2 2.75:F#5:.25 3:A5:.35 3.5:C#6:.4",
        "0:D6:.35 .75:A5:.35 1.5:C6:.35 2.25:A5:.6 3:F#5:.3 3.5:A5:.4",
        "0:G#5:.35 .5:B5:.35 1:D6:.35 1.5:C#6:2.3:tr",
        "0:B5:.35 .75:F#5:.35 1.5:C6:.35 2.25:B5:.6 3:D6:.3 3.5:C#6:.4",
        "0:B5:.35 .75:G5:.35 1.5:D6:.35 2.25:B5:.6 3:G5:.3 3.5:B5:.4",
        "0:D6:.3 1.5:D6:.3 3:B5:.3 3.5:D6:.3",
        "0:C#6:.3 .5:B5:.3 1:G#5:.3 1.5:E#5:.3 2:D5:.3 2.5:C#5:1.25",
    ], 78)
    line(s, "violin_2", [
        "0:A4:.3 1.5:A4:.3 3:C#5:.3", "0:A4:.3 1.5:F#4:2.2:tr", "0:C5:.3 1.5:C5:.3 3:A4:.3",
        "0:B4:.3 1.5:G#4:2.2:tr", "0:A4:.3 1.5:A4:.3 3:C#5:.3", "0:B4:.3 1.5:D5:2.2:tr",
        "0:B4:.3 1.5:D5:.3 3:B4:.3", "0:B4:.3 1.5:G#4:.3 3:E#4:.8",
        # parallel fourths/thirds shadow the zigzag
        "0:C#5:.35 .75:G#4:.35 1.5:D5:.35 2.25:C#5:.6 3:G#4:.3 3.5:B4:.4",
        "0:A4:.35 .5:B4:.35 1:C#5:.35 1.5:E5:2.3:tr",
        "0:F#5:.35 .75:C5:.35 1.5:A5:.35 2.25:F#5:.6 3:A5:.3 3.5:F#5:.4",
        "0:E#5:.35 .5:D5:.35 1:B4:.35 1.5:G#4:.35 2:E#5:1.7:tr",
        "0:F#5:.35 .75:C#5:.35 1.5:G5:.35 2.25:F#5:.6 3:C#5:.3 3.5:E5:.4",
        "0:E5:.35 .5:C#5:.35 1:B4:.35 1.5:G#5:2.3:tr",
        "0:F#5:.35 .75:D5:.35 1.5:A5:.35 2.25:F#5:.6 3:D5:.3 3.5:C#5:.4",
        "0:B4:.35 .5:D5:.35 1:E#5:.35 1.5:G#5:.35 2:B5:.35 2.5:G#5:1.3",
        "0:A4:4:tr:v54", "0:B4:4:tr:v54", "0:B4:4:tr:v58", "0:G#4:4:tr:v60", "0:C#5:4:tr:v64",
        "0:E5:4:tr:v68", "0:B4:3.9:tr:v74", "0:B4:.3 .75:G#4:.3 1.5:B4:.3 2.25:D5:.6 3:E#5:.3 3.5:G#5:.4",
        "0:C#5:.35 .75:G#4:.35 1.5:D5:.35 2.25:C#5:.6 3:G#4:.3 3.5:B4:.4",
        "0:B4:.35 .5:A4:.35 1:G#4:.35 1.5:A4:1.2 2.75:C#5:.25 3:F#5:.35 3.5:A5:.4",
        "0:A5:.35 .75:F#5:.35 1.5:A5:.35 2.25:F#5:.6 3:D5:.3 3.5:F#5:.4",
        "0:E#5:.35 .5:G#5:.35 1:B5:.35 1.5:G#5:2.3:tr",
        "0:F#5:.35 .75:D5:.35 1.5:G5:.35 2.25:F#5:.6 3:B5:.3 3.5:A5:.4",
        "0:G5:.35 .75:D5:.35 1.5:B5:.35 2.25:G5:.6 3:D5:.3 3.5:G5:.4",
        "0:B5:.3 1.5:B5:.3 3:G5:.3 3.5:B5:.3",
        "0:E#5:.3 .5:D5:.3 1:B4:.3 1.5:G#4:.3 2:B4:.3 2.5:G#4:1.25",
    ], 66)
    line(s, "viola", [
        "0:C#4:1.4 1.5:C#4:1.4 3:A3:.9", "0:A3:1.4 1.5:A3:1.4 3:C#4:.9", "0:A3:1.4 1.5:A3:1.4 3:C4:.9",
        "0:G#3:1.4 1.5:G#3:1.4 3:B3:.9", "0:C#4:1.4 1.5:C#4:1.4 3:A3:.9", "0:B3:1.4 1.5:B3:1.4 3:D4:.9",
        "0:B3:1.4 1.5:B3:1.4 3:D4:.9", "0:G#3:1.4 1.5:B3:1.4 3:E#3:.9",
        "0:A3:1.4 1.5:C#4:1.4 3:F#3:.9", "0:C#4:1.4 1.5:A3:1.4 3:C#4:.9", "0:F#3:1.4 1.5:A3:1.4 3:C4:.9",
        "0:B3:1.4 1.5:G#3:1.4 3:E#3:.9", "0:D4:1.4 1.5:B3:1.4 3:F#3:.9", "0:B3:1.4 1.5:G#3:1.4 3:E3:.9",
        "0:A3:1.4 1.5:F#3:1.4 3:C#4:.9", "0:B3:1.4 1.5:G#3:1.4 3:D4:.9",
        "0:D4:4:tr:v50", "0:C#4:4:tr:v50", "0:B3:4:tr:v54", "0:B3:4:tr:v56", "0:A3:4:tr:v60",
        "0:C#4:4:tr:v64", "0:G3:3.9:tr:v68", "0:G#3:.3 .75:B3:.3 1.5:D4:.3 2.25:E#3:.6 3:G#3:.3 3.5:B3:.4",
        "0:A3:1.4 1.5:C#4:1.4 3:A3:.9", "0:C#4:1.4 1.5:A3:1.4 3:C#4:.9", "0:C4:1.4 1.5:A3:1.4 3:F#3:.9",
        "0:B3:1.4 1.5:G#3:1.4 3:E#3:.9", "0:D4:1.4 1.5:B3:1.4 3:F#3:.9", "0:D4:1.4 1.5:B3:1.4 3:G3:.9",
        "0:G3:.3 1.5:G3:.3 3:D4:.3 3.5:G3:.3", "0:G#3:.3 .5:B3:.3 1:D4:.3 1.5:B3:.3 2:G#3:.3 2.5:E#3:1.25",
    ], 62)
    pad(s, seg, T, 56)
    jag = [(0, 1.4, 0, 84), (1.5, 1.4, 12, 70), (3, .9, 7, 74)]
    jag_fill = [(0, 1.4, 0, 84), (1.5, 1.4, 12, 70), (3, .4, 7, 72), (3.5, .4, 12, 68)]
    eye = [(0, 1.9, 0, 56), (2, 1.9, 0, 48)]
    push = [(i * .5, .4, 12 * (i % 2), 70 + i * 2) for i in range(8)]
    stab = [(0, .3, 0, 86), (1.5, .3, 0, 80), (3, .3, 0, 82), (3.5, .3, 12, 78)]
    fall = [(0, .4, 0, 84), (.5, .4, 12, 70), (1, .4, 0, 76), (1.5, .4, 12, 72), (2, 1.7, 0, 80)]
    groove(s, "hollow_bass", seg, T, seq((jag, 3), (jag_fill, 1), (jag, 3), (jag_fill, 1),
                                         (jag, 3), (jag_fill, 1), (jag, 3), (jag_fill, 1),
                                         (eye, 4), ([(b, d, i, v + 8) for b, d, i, v in eye], 2), (push, 2),
                                         (jag, 3), (jag_fill, 1), (jag, 2),
                                         (stab, 1), (fall, 1)))
    storm = [(i * .5, .25, k, v) for i, (k, v) in enumerate(zip([0, 1, 2, 0, 1, 2, 3, 2],
                                                                 [64, 48, 50, 62, 48, 50, 60, 48]))]
    calm = [(b, d, k, v - 18) for b, d, k, v in storm]
    stabs = [(0, .25, 0, 70), (1.5, .25, 0, 66), (3, .25, 1, 66), (3.5, .25, 2, 62)]
    rising = [(b, d, k, v - 8) for b, d, k, v in storm]
    groove(s, "thread_pluck", seg, T, seq((storm, 16), (calm, 4), (rising, 4), (storm, 6), (stabs, 1), (storm, 1)))
    crackle = [(.25, 42, 30), (1.25, 42, 26), (1.75, 42, 34), (2.75, 42, 28), (3.25, 42, 32)]
    d_a = [(0, 36, 80), (1.5, 36, 66), (3, 41, 56), (3.5, 41, 46)]
    d_fill = [(0, 36, 80), (1.5, 36, 66), (3, 41, 54), (3.25, 41, 50), (3.5, 41, 58), (3.75, 41, 64)]
    d_eye = [(0, 36, 54), (1.25, 42, 22), (2, 41, 34), (3.75, 42, 26)]
    d_build = [(0, 36, 66), (1, 41, 40), (2, 36, 60), (2.5, 41, 44), (3, 41, 48), (3.5, 41, 52)]
    d_roll = [(0, 36, 72)] + [(i * .25, 41, 40 + i * 3) for i in range(1, 16)]
    crackle2 = [(.25, 42, 30), (.75, 42, 26), (1.75, 42, 32), (2.25, 42, 28), (2.75, 42, 34), (3.75, 42, 30)]
    d_c = [(0, 36, 86), (1, 38, 50), (1.5, 36, 72), (3, 36, 70), (3, 38, 56), (3.5, 41, 52)] + crackle2
    d_c_fill = [(0, 36, 86), (1, 38, 50), (1.5, 36, 72), (3, 41, 58), (3.25, 41, 62), (3.5, 41, 66),
                (3.75, 41, 72)] + crackle2[:4]
    d_stab = [(0, 36, 90), (0, 38, 56), (1.5, 36, 84), (1.5, 38, 54), (3, 36, 84), (3.5, 41, 66)]
    groove(s, "drums", seg, T, seq((d_a, 3), (d_fill, 1), (d_a, 3), (d_fill, 1),
                                   (d_a + crackle, 3), (d_fill + crackle[:4], 1),
                                   (d_a + crackle, 3), (d_fill + crackle[:4], 1),
                                   (d_eye, 6), (d_build, 1), (d_roll, 1),
                                   (d_c, 3), (d_c_fill, 1), (d_c, 2), (d_stab, 1), (d_c_fill, 1)))
    s["sections"] = ["1-8: the zigzag strike over 3+3+2 stabs (F#m-D7-C#7 | F#m-Bm-G-C#7b9)",
                     "9-16: rising answer; second violins shadow the motif in fourths; motif on B minor",
                     "17-24: eye of the storm - augmented motif sequenced D-E-F#m under tremolo, tom roll",
                     "25-32: full strike with crackle and backbeat, tutti Neapolitan stabs, diminished fall"]
    return finish(s)


# =================================================================== 2. Tharokh

def tharokh():
    s = new_score(THEMES[1], "Tharokh, the Worldspine", 64, 16,
                  "A minor with a Phrygian B-flat (A Phrygian-inflected; E7 cadences)",
                  "Earth boss: a dotted low-string march, grinding viola semitones and heavy paired drum strokes.",
                  "loop_theme", {"dragon": "Tharokh, the Worldspine", "tonic": "A", "element": "earth",
                                 "motif": "A . A-E | F-E-D-C | Bb-C-D-F | E-G#: a dotted cello march falling to the Phrygian Bb",
                                 "relation_to_thorns": "Same string family, but the melody moves to a low cello-register voice; "
                                                       "half Thorns' tempo, A minor, paired kick strokes."})
    p = s["patches"]
    p["cello"] = cello_patch()
    p["viola"].update(lowpass_hz=2300, bow_noise=.0034, tremolo_division=8, tremolo_depth=.55, pan=-.32)
    p["violin_1"].update(lowpass_hz=3000, vibrato_cents=8, pan=-.15)
    p["drums"].update(lowpass_hz=950, wet=.15)
    p["thread_pluck"].update(lowpass_hz=800)
    p["bowed_veil"].update(lowpass_hz=1400)
    s["lead_instrument"] = "cello"
    s["mix"] = mix_plan(cello=["violin_1", -.5], violin_1=["violin_2", -.5], viola=1.5, hollow_bass=.5,
                        drums=2.5, thread_pluck=-1.0, bowed_veil=.5)
    T = {"Am": ("Am", "A1", "E4", ["A2", "E3", "A3", "C3"], "Am"),
         "F": ("F", "F1", "A3", ["F2", "C3", "F3", "A2"], "F"),
         "Bb": ("Bb (Phrygian bII)", "Bb1", "D4", ["Bb2", "F3", "Bb3", "D3"], "Bb"),
         "E7": ("E7", "E2", "G#3", ["E3", "B3", "D4", "G#3"], "E"),
         "Dm": ("Dm", "D2", "A3", ["D3", "A3", "D4", "F3"], "Dm"),
         "G": ("G", "G1", "B3", ["G2", "D3", "G3", "B2"], "G")}
    seg = progression(s, T, ["Am", "F", "Bb", "E7", "Am", "Dm", "Bb", "E7",
                             "F", "G", "Am", "Bb E7@2", "Am", "F", "Bb", "E7"])
    theme = ["0:A2:1.45 1.5:A2:.45 2:E3:1.9", "0:F3:1.45 1.5:E3:.45 2:D3:.95 3:C3:.95",
             "0:Bb2:1.45 1.5:C3:.45 2:D3:1.45 3.5:F3:.45", "0:E3:1.9 2:G#2:1.9"]
    line(s, "cello", theme + [
        "0:A2:1.45 1.5:C3:.45 2:E3:.95 3:A3:.95", "0:F3:1.45 1.5:E3:.45 2:D3:.95 3:A2:.95",
        "0:Bb2:1.45 1.5:D3:.45 2:F3:1.45 3.5:E3:.45", "0:E3:1.45 1.5:D3:.45 2:B2:.95 3:G#2:.95",
        # 9-12: the spine rises - fourth-then-third cells climbing C, D, E
        "0:C3:1.45 1.5:F3:.45 2:A3:1.9", "0:D3:1.45 1.5:G3:.45 2:B3:1.9",
        "0:E3:1.45 1.5:A3:.45 2:C4:1.9", "0:D4:1.45 1.5:C4:.45 2:B3:.95 3:G#3:.95",
    ] + theme, 84)
    line(s, "violin_1", ["", "", "", "",
                         "0:E5:2.9 3:D5:.45 3.5:C5:.45", "0:D5:1.9 2:F5:1.9",
                         "0:F5:1.4 1.5:E5:.45 2:D5:1.9", "0:E5:1.9 2:D5:.95 3:B4:.95",
                         "0:A4:.95 1:C5:.95 2:F5:1.9", "0:B4:.95 1:D5:.95 2:G5:1.9",
                         "0:C5:.95 1:E5:.95 2:A5:1.9", "0:Bb5:1.9 2:G#5:1.9"]
         # 13-16: the march two octaves above the cello
         + [" ".join(f"{t.split(':')[0]}:{name(v01.pitch(t.split(':')[1]) + 24)}:{t.split(':')[2]}"
                     for t in bar.split()) for bar in theme], 74)
    grind = {"Am": "0:A3:.5 .5:Bb3:.45 1:A3:.45 1.5:E3:.45 2:A3:.5 2.5:Bb3:.45 3:A3:.45 3.5:G#3:.45",
             "F": "0:A3:.5 .5:Bb3:.45 1:A3:.45 1.5:F3:.45 2:A3:.5 2.5:Bb3:.45 3:C4:.45 3.5:A3:.45",
             "Bb": "0:D4:.5 .5:E4:.45 1:D4:.45 1.5:Bb3:.45 2:D4:.5 2.5:E4:.45 3:F4:.45 3.5:D4:.45",
             "E7": "0:G#3:.5 .5:A3:.45 1:G#3:.45 1.5:E3:.45 2:G#3:.5 2.5:A3:.45 3:B3:.45 3.5:D4:.45",
             "Dm": "0:A3:.5 .5:Bb3:.45 1:A3:.45 1.5:F3:.45 2:A3:.5 2.5:Bb3:.45 3:D4:.45 3.5:C4:.45"}
    line(s, "viola", [grind[k] for k in ["Am", "F", "Bb", "E7", "Am", "Dm", "Bb", "E7"]]
         + ["0:A3:4:tr", "0:B3:4:tr", "0:C4:4:tr", "0:D4:3.9:tr"]
         + [grind[k] for k in ["Am", "F", "Bb", "E7"]], 70)
    pad(s, seg, T, 58)
    tread = [(0, .45, 0, 88), (.5, 1.4, 0, 76), (2, .45, 0, 84), (2.5, 1.3, 12, 64)]
    rise = [(0, .45, 0, 86), (.5, 1.4, 0, 74), (2, .45, 7, 80), (2.5, 1.3, 12, 66)]
    split = [(0, .45, 0, 86), (.5, 1.4, 0, 74), (2, .45, 0, 84), (2.5, 1.3, 0, 74)]
    groove(s, "hollow_bass", seg, T, seq((tread, 8), (rise, 3), (split, 1), (tread, 4)))
    stones = [(.5, .3, 0, 52), (1.5, .3, 1, 46), (2.5, .3, 2, 48), (3.5, .3, 1, 44)]
    rubble = [(i * .5, .28, k, v) for i, (k, v) in enumerate(zip([0, 1, 2, 1, 0, 1, 3, 1],
                                                                  [56, 44, 48, 44, 54, 44, 50, 44]))]
    groove(s, "thread_pluck", seg, T, seq((stones, 8), (rubble, 4), (stones, 4)))
    step = [(0, 36, 90), (.5, 36, 74), (2, 36, 86), (2.5, 36, 70), (3.5, 41, 50)]
    step_fill = [(0, 36, 90), (.5, 36, 74), (2, 36, 86), (2.5, 36, 70), (3, 41, 56), (3.25, 41, 50),
                 (3.5, 41, 62), (3.75, 41, 70)]
    climb = [(0, 36, 92), (.5, 36, 76), (1.5, 41, 48), (2, 36, 88), (2.5, 36, 72), (3, 41, 54), (3.5, 41, 60)]
    groove(s, "drums", seg, T, seq((step, 3), (step_fill, 1), (step, 3), (step_fill, 1),
                                   (climb, 3), (step_fill, 1), (step, 3), (step_fill, 1)))
    s["sections"] = ["1-4: the Worldspine march alone in the low strings (Am-F-Bb-E7)",
                     "5-8: the march answered; a slow violin descant enters over Dm and the Phrygian Bb",
                     "9-12: the spine rises - cello and violin climb in sequence over F-G-Am, viola tremolo",
                     "13-16: the march doubled two octaves apart, grinding viola, full paired strokes"]
    return finish(s)


# =================================================================== 3. Vyraketh

def vyraketh():
    s = new_score(THEMES[2], "Vyraketh, the Cinder Crown", 138, 32,
                  "F harmonic minor; Neapolitan G-flat and a chromatic minor-chord climb",
                  "Fire boss: an ember cell that climbs in sequence, hammering strings and galloping percussion.",
                  "loop_theme", {"dragon": "Vyraketh, the Cinder Crown", "tonic": "F", "element": "fire",
                                 "motif": "C-F, E-F-G-Ab: a leap and a leading-tone flick that climbs a third each bar",
                                 "relation_to_thorns": "Same palette with heavier kit (backbeat, gallop); F not C minor, "
                                                       "138 BPM, rising sequences instead of Thorns' circling phrases."})
    p = s["patches"]
    p["violin_1"].update(bow_noise=.0048, attack_seconds=.04, vibrato_cents=11, vibrato_hz=5.4, lowpass_hz=3300)
    p["drums"].update(lowpass_hz=1500, wet=.09)
    p["thread_pluck"].update(lowpass_hz=1300)
    s["mix"] = mix_plan(violin_1=.75, drums=2.0, thread_pluck=.5, violin_2=.5, viola=.5)
    T = {"Fm": ("Fm", "F1", "Ab3", ["F3", "C4", "Ab3", "F4"], "Fm"),
         "Ab": ("Ab", "Ab1", "C4", ["Ab2", "Eb3", "C3", "Ab3"], "Ab"),
         "Bbm": ("Bbm", "Bb1", "Db4", ["Bb2", "F3", "Db3", "Bb3"], "Bbm"),
         "C7b9": ("C7(b9)", "C2", "Bb3", ["C3", "G3", "E3", "Db4"], "C"),
         "C7": ("C7", "C2", "Bb3", ["C3", "G3", "E3", "Bb3"], "C"),
         "Db": ("Dbmaj7", "Db2", "C4", ["Db3", "Ab3", "F3", "C4"], "Db"),
         "Edim": ("E dim7", "E2", "Db4", ["E3", "Bb3", "G3", "Db4"], "Edim"),
         "Fm/C": ("Fm/C", "C2", "Ab3", ["C3", "F3", "Ab3", "C4"], "Fm"),
         "Gb": ("Gb (Neapolitan)", "Gb1", "Bb3", ["Gb2", "Db3", "Bb2", "Gb3"], "Gb"),
         "Eb": ("Eb", "Eb2", "G3", ["Eb3", "Bb3", "G3", "Eb4"], "Eb"),
         "C": ("C", "C2", "G3", ["C3", "G3", "E3", "C4"], "C"),
         "Gbm": ("Gb minor", "Gb1", "A3", ["Gb2", "Db3", "A2", "Gb3"], "Gbm"),
         "Gm": ("Gm", "G1", "Bb3", ["G2", "D3", "Bb2", "G3"], "Gm"),
         "Abm": ("Abm", "Ab1", "Cb4", ["Ab2", "Eb3", "Cb3", "Ab3"], "Abm"),
         "Am": ("Am", "A1", "C4", ["A2", "E3", "C3", "A3"], "Am")}
    seg = progression(s, T, ["Fm", "Ab", "Bbm", "C7b9", "Db", "Edim", "Fm/C", "C7",
                             "Fm", "Ab", "Bbm", "C7b9", "Db", "Gb", "C7", "C7",
                             "Db", "Eb", "Fm", "Fm", "Db", "Eb", "C", "C7",
                             "Fm", "Gbm", "Gm", "Abm", "Am", "Bbm", "C7", "C7b9"])
    rise = ["0:C5:.45 .5:F5:.45 1:E5:.2 1.25:F5:.2 1.5:G5:.45 2:Ab5:1.4 3.5:G5:.45",
            "0:Eb5:.45 .5:Ab5:.45 1:G5:.2 1.25:Ab5:.2 1.5:Bb5:.45 2:C6:1.4 3.5:Bb5:.45",
            "0:F5:.45 .5:Bb5:.45 1:A5:.2 1.25:Bb5:.2 1.5:C6:.45 2:Db6:1.4 3.5:C6:.45"]
    line(s, "violin_1", rise + [
        "0:E5:.45 .5:G5:.45 1:Bb5:.45 1.5:Db6:.45 2:C6:1.9",
        "0:Db6:.9 1:C6:.45 1.5:Bb5:.45 2:Ab5:.45 2.5:G5:.45 3:F5:.9",
        "0:E5:.45 .5:F5:.45 1:G5:.45 1.5:Ab5:.45 2:Bb5:.9 3:Db6:.45 3.5:Bb5:.45",
        "0:C6:.45 .5:Ab5:.45 1:F5:.9 2:Ab5:.45 2.5:G5:.45 3:F5:.45 3.5:E5:.45",
        "0:G5:1.4 1.5:Bb5:.45 2:Ab5:.45 2.5:G5:.45 3:E5:.45 3.5:Db5:.45",
    ] + rise + [
        "0:E5:.45 .5:G5:.45 1:Bb5:.45 1.5:Db6:.45 2:C6:1.4 3.5:Db6:.45",
        "0:C6:.45 .5:Db6:.45 1:Eb6:.9 2:Db6:.45 2.5:C6:.45 3:Ab5:.9",
        "0:Bb5:.9 1:Gb5:.45 1.5:Ab5:.45 2:Bb5:.45 2.5:Db6:.45 3:Bb5:.9",
        "0:C6:.45 .5:Bb5:.45 1:G5:.45 1.5:E5:.45 2:G5:1.9",
        "0:E5:.45 .5:F5:.45 1:G5:.45 1.5:Ab5:.45 2:Bb5:.45 2.5:C6:1.4",
        # 17-24: the crown blazes - long soaring notes over hammering strings
        "0:F5:2.9 3:Ab5:.9", "0:G5:2.9 3:Bb5:.9", "0:C6:2.9 3:Eb6:.45 3.5:Db6:.45",
        "0:C6:1.4 1.5:Ab5:.45 2:F5:1.9", "0:F5:2.9 3:Ab5:.9", "0:Bb5:2.9 3:Db6:.9",
        "0:C6:1.9 2:G5:.9 3:Bb5:.9", "0:G5:.9 1:E5:.9 2:C5:1.9",
        # 25-32: the ember cell climbs chromatically through parallel minor chords
        cell("C5"), cell("Db5"), cell("D5"), cell("Eb5"), cell("E5"), cell("F5"),
        "0:C6:.45 .5:Db6:.45 1:E6:1.4 2.5:Db6:.45 3:Bb5:.45 3.5:G5:.45",
        "0:E5:.45 .5:G5:.45 1:Bb5:.45 1.5:Db6:.45 2:C6:1.4 3.5:G5:.45",
    ], 80)
    line(s, "violin_2", [
        "0:Ab4:1.9 2:C5:1.9", "0:C5:1.9 2:Eb5:1.9", "0:Db5:1.9 2:F5:1.9",
        "0:Bb4:.45 .5:Db5:.45 1:E5:.45 1.5:G5:.45 2:E5:1.9", "0:F5:1.9 2:Db5:1.9", "0:Db5:1.9 2:E5:1.9",
        "0:F5:1.9 2:C5:1.9", "0:E5:1.9 2:Bb4:1.9",
        "0:Ab4:.45 .5:Ab4:.45 1:G4:.2 1.25:Ab4:.2 1.5:Bb4:.45 2:C5:1.4 3.5:Bb4:.45",
        "0:C5:.45 .5:C5:.45 1:Bb4:.2 1.25:C5:.2 1.5:Db5:.45 2:Eb5:1.4 3.5:Db5:.45",
        "0:Db5:.45 .5:Db5:.45 1:C5:.2 1.25:Db5:.2 1.5:Eb5:.45 2:F5:1.4 3.5:Eb5:.45",
        "0:C5:.45 .5:E5:.45 1:G5:.45 1.5:Bb5:.45 2:G5:1.4 3.5:Bb5:.45",
        "0:F5:.45 .5:F5:.45 1:Ab5:.9 2:F5:.45 2.5:Eb5:.45 3:F5:.9",
        "0:Gb5:.9 1:Db5:.45 1.5:Eb5:.45 2:Gb5:.45 2.5:Bb5:.45 3:Gb5:.9",
        "0:E5:.45 .5:E5:.45 1:Db5:.45 1.5:Bb4:.45 2:E5:1.9",
        "0:C5:.45 .5:Db5:.45 1:E5:.45 1.5:F5:.45 2:G5:.45 2.5:Ab5:1.4",
        hammer("Ab4", "F4"), hammer("Bb4", "G4"), hammer("C5", "Ab4"), hammer("C5", "Ab4"),
        hammer("Ab4", "F4"), hammer("Bb4", "G4"), hammer("G4", "E4"), hammer("Bb4", "E4"),
        hammer("Ab4", "F4"), hammer("A4", "Gb4"), hammer("Bb4", "G4"), hammer("Cb5", "Ab4"),
        hammer("C5", "A4"), hammer("Db5", "Bb4"), hammer("E5", "Bb4"), hammer("Bb4", "G4"),
    ], 68)
    line(s, "viola", [
        "0:C4:1.9 2:Ab3:1.9", "0:Eb4:1.9 2:C4:1.9", "0:F4:1.9 2:Db4:1.9", "0:E4:1.9 2:G3:1.9",
        "0:Ab3:1.9 2:F3:1.9", "0:G3:1.9 2:Bb3:1.9", "0:Ab3:1.9 2:F3:1.9", "0:G3:1.9 2:E3:1.9",
        hammer("F3", "C4"), hammer("Ab3", "Eb4"), hammer("Bb3", "F4"), hammer("C4", "G3"),
        hammer("Db4", "Ab3"), hammer("Gb3", "Db4"), hammer("C4", "G3"), hammer("Bb3", "G3"),
        "0:Ab3:1.9 2:F3:1.9", "0:Bb3:1.9 2:G3:1.9", "0:C4:1.9 2:Ab3:1.9", "0:F3:1.9 2:Ab3:1.9",
        "0:Ab3:1.9 2:Db4:1.9", "0:G3:1.9 2:Bb3:1.9", "0:E3:1.9 2:G3:1.9", "0:Bb3:1.9 2:G3:1.9",
        hammer("F3", "C4"), hammer("Gb3", "Db4"), hammer("G3", "D4"), hammer("Ab3", "Eb4"),
        hammer("A3", "E4"), hammer("Bb3", "F4"), hammer("C4", "G3"), hammer("C4", "E3"),
    ], 64)
    pad(s, seg, T, 58)
    pump = [(i * .5, .4, 0, v) for i, v in enumerate([86, 58, 70, 58, 82, 58, 70, 64])]
    pump_turn = pump[:6] + [(3, .4, 7, 72), (3.5, .4, 12, 70)]
    broad = [(0, 1.4, 0, 84), (1.5, .4, 0, 64), (2, 1.4, 0, 80), (3.5, .4, 12, 66)]
    groove(s, "hollow_bass", seg, T, seq((pump, 3), (pump_turn, 1), (pump, 3), (pump_turn, 1),
                                         (pump, 3), (pump_turn, 1), (pump, 3), (pump_turn, 1),
                                         (broad, 7), (pump_turn, 1), (pump, 6), (pump_turn, 2)))
    gallop = [(b + o, .2, k, v) for b in range(4)
              for o, k, v in zip((0, .5, .75), [0, 2, 1] if b < 3 else [3, 2, 1], (60, 46, 50))]
    soft_gallop = [(b, d, k, v - 8) for b, d, k, v in gallop]
    groove(s, "thread_pluck", seg, T, seq((soft_gallop, 8), (gallop, 24)))
    k_open = [(0, 36, 80), (1.5, 36, 58), (2, 36, 74), (3, 41, 48), (3.5, 41, 46)]
    k_a = [(0, 36, 84), (1, 38, 50), (1.5, 36, 62), (2, 36, 78), (3, 38, 56), (3.5, 41, 50)]
    k_fill = [(0, 36, 84), (1, 38, 50), (1.5, 36, 62), (2, 36, 78), (3, 41, 56), (3.25, 41, 60),
              (3.5, 41, 64), (3.75, 41, 70)]
    k_b = [(0, 36, 86), (.75, 36, 64), (1, 38, 54), (2, 36, 82), (2.75, 36, 64), (3, 38, 58), (3.5, 41, 50)]
    k_c = [(0, 36, 88), (.5, 36, 58), (1, 38, 58), (1.5, 36, 64), (2, 36, 84), (2.5, 36, 58), (3, 38, 62),
           (3.5, 41, 56), (3.75, 41, 60)]
    k_roll = [(0, 36, 86), (2, 36, 80)] + [(i * .25, 41, 48 + i * 2) for i in range(16)]
    groove(s, "drums", seg, T, seq((k_open, 3), (k_fill, 1), (k_open, 3), (k_fill, 1), (k_a, 3), (k_fill, 1),
                                   (k_a, 3), (k_fill, 1), (k_b, 3), (k_fill, 1), (k_b, 3), (k_fill, 1),
                                   (k_c, 6), (k_roll, 2)))
    terrace(s, [(1, 8, {"violin_1": -4, "violin_2": -8, "viola": -8, "hollow_bass": -6}),
                (9, 16, {"violin_2": -2, "viola": -2}),
                (17, 24, {"violin_1": 4, "violin_2": 2}),
                (25, 32, {"violin_1": 6, "violin_2": 6, "viola": 6, "hollow_bass": 4, "drums": 4})])
    s["sections"] = ["1-8: the ember cell rises Fm-Ab-Bbm-C7b9, then falls back through the E dim7",
                     "9-16: the cell in sixths; a Neapolitan G-flat blaze before the dominant",
                     "17-24: the crown blazes - soaring line over hammering strings (Db-Eb-Fm)",
                     "25-32: the cell climbs chromatically Fm-Gbm-Gm-Abm-Am-Bbm to C7, tom rolls"]
    return finish(s)


# =================================================================== 4. Vaeloryx

def vaeloryx():
    s = new_score(THEMES[3], "Vaeloryx, the Hollow Gale", 126, 28,
                  "D Dorian (B natural) with Lydian B-flat(#11) and an E7/G# threat",
                  "Air boss: long wide lines, rushing triplet gusts, swirling pluck arpeggios and light drums.",
                  "loop_theme", {"dragon": "Vaeloryx, the Hollow Gale", "tonic": "D", "element": "air",
                                 "motif": "held D5, a triplet gust up to the Dorian B natural, then a fall",
                                 "relation_to_thorns": "Same instruments, spread wider with more echo; compound triplet "
                                                       "motion, modal D Dorian, long lines instead of Thorns' short gestures."})
    p = s["patches"]
    p["violin_1"].update(pan=-.32, wet=.32, vibrato_cents=11, vibrato_hz=4.6, lowpass_hz=3400)
    p["violin_2"].update(pan=.45, wet=.34)
    p["viola"].update(pan=-.45, wet=.32)
    p["thread_pluck"].update(pan=.38, lowpass_hz=1600, wet=.30)
    p["bowed_veil"].update(pan=-.22, wet=.36)
    p["drums"].update(lowpass_hz=1000, wet=.14)
    p["hollow_bass"].update(wet=.03)
    s["mix"] = mix_plan(violin_1=.75, drums=-2.5, thread_pluck=1.5, bowed_veil=1.0, violin_2=.5)
    T = {"Dm9": ("Dm9", "D2", "E4", ["D3", "A3", "E4", "F4"], "Dm"),
         "G/D": ("G/D (Dorian IV)", "D2", "D4", ["D3", "G3", "B3", "D4"], "G"),
         "Cadd9": ("C(add9)", "C2", "D4", ["C3", "G3", "D4", "E4"], "C"),
         "Am7": ("Am7", "A1", "G3", ["A2", "E3", "C4", "G4"], "Am"),
         "Bb": ("Bbmaj7(#11)", "Bb1", "A3", ["Bb2", "F3", "A3", "E4"], "Bb"),
         "E7/G#": ("E7/G#", "G#1", "D4", ["G#2", "E3", "B3", "D4"], "E"),
         "A7": ("A7", "A1", "C#4", ["A2", "E3", "G3", "C#4"], "A"),
         "Fmaj7": ("Fmaj7", "F2", "E4", ["F3", "C4", "E4", "A4"], "F"),
         "G": ("G", "G2", "D4", ["G2", "D3", "B3", "D4"], "G"),
         "Am": ("Am", "A1", "C4", ["A2", "E3", "C4", "E4"], "Am")}
    theme = ["Dm9", "G/D", "Cadd9", "Am7", "Bb", "Bb", "E7/G#", "A7"]
    seg = progression(s, T, theme + ["Fmaj7", "G", "Am", "Am", "Fmaj7", "G", "Bb", "A7",
                                     "Dm9", "Bb", "Dm9", "Bb"] + theme)
    a1 = ["0:D5:2.6 8/3:E5:1/3 3:F5:1/3 10/3:G5:1/3 11/3:A5:1/3", "0:B5:2.9 3:A5:.95",
          "0:G5:1.9 2:E5:.9 3:F5:2/3 11/3:G5:1/3", "0:A5:3.9",
          "0:D6:2.6 8/3:C6:1/3 3:Bb5:1/3 10/3:A5:1/3 11/3:G5:1/3", "0:E5:2.9 3:F5:.95",
          "0:G5:4/3 4/3:E5:2/3 2:G#5:1.9", "0:A5:1.9 2:G5:1/3 7/3:F5:1/3 8/3:E5:1/3 3:C#5:.95"]
    line(s, "violin_1", a1 + [
        "0:A4:.95 1:C5:.95 2:E5:1.9", "0:D5:4/3 4/3:B4:2/3 2:G5:1.9", "0:E5:1.9 2:C6:1.9",
        "0:B5:4/3 4/3:A5:2/3 2:E5:1.9", "0:F5:4/3 4/3:A5:2/3 2:E6:1.9", "0:D6:1.9 2:B5:4/3 10/3:G5:2/3",
        "0:E6:3.9", "0:C#6:1.9 2:E5:4/3 10/3:G5:2/3",
        "0:D5:1.9:v66", "4/3:E5:2/3:v62 2:A4:1.9:v60", "0:F5:1.9:v64 8/3:E5:1/3:v60 3:D5:.95:v62", "0:A4:3.9:v62",
        a1[0], "0:B5:1.9 2:D6:.95 3:C6:.95", a1[2], "0:A5:1.9 2:E6:1.9", a1[4], a1[5], a1[6], a1[7],
    ], 78)
    line(s, "violin_2", [
        "0:A4:3.9", "0:G4:3.9", "0:C5:3.9", "0:E5:3.9", "0:F5:3.9", "0:A4:3.9", "0:B4:3.9", "0:E5:1.9 2:G4:1.9",
        gust("C5", "F4 G4 A4 C5 E5 F5"), gust("D5", "G5 F5 E5 D5 C5 B4"), gust("C5", "A4 B4 C5 E5 G5 A5"),
        gust("G5", "A5 G5 E5 D5 C5 A4"), gust("C5", "F4 A4 C5 E5 F5 A5"), gust("G5", "F5 E5 D5 C5 B4 A4"),
        gust("Bb4", "D5 E5 F5 A5 Bb5 D6"), gust("A5", "G5 E5 C#5 A4 G4 E4"),
        "0:F4:3.9:v52", "0:E4:3.9:v52", "0:A4:3.9:v56", gust("F4", "D5 E5 F5 G5 A5 Bb5"),
        gust("A5", "F5 E5 D5 C5 A4 F4"), gust("G4", "B4 C5 D5 E5 G5 A5"), gust("E5", "D5 C5 B4 A4 G4 E4"),
        gust("C5", "E5 G5 A5 B5 C6 D6"), gust("A5", "F5 E5 D5 C5 Bb4 A4"), gust("D5", "E5 F5 A5 Bb5 D6 E6"),
        gust("D6", "B5 G#5 E5 D5 B4 G#4"), gust("A4", "C#5 E5 G5 A5 G5 E5"),
    ], 64)
    line(s, "viola", [
        "0:F3:1.9 2:A3:1.9", "0:B3:1.9 2:G3:1.9", "0:E3:1.9 2:G3:1.9", "0:C4:3.9", "0:D4:3.9",
        "0:F3:1.9 2:A3:1.9", "0:D4:1.9 2:B3:1.9", "0:C#4:1.9 2:E4:1.9",
        "0:A3:3.9", "0:B3:3.9", "0:C4:1.9 2:E4:1.9", "0:E4:1.9 2:C4:1.9", "0:A3:3.9", "0:B3:1.9 2:D4:1.9",
        "0:D4:1.9 2:F4:1.9", "0:E4:1.9 2:C#4:1.9",
        "0:C4:3.9:v54", "0:D4:3.9:v54", "0:C4:3.9:v56", "0:D4:1.9:v58 2:E4:1.9:v60",
        "0:F3:1.9 2:A3:1.9", "0:B3:1.9 2:G3:1.9", "0:E3:1.9 2:G3:1.9", "0:C4:3.9", "0:D4:3.9",
        "0:F3:1.9 2:A3:1.9", "0:D4:1.9 2:B3:1.9", "0:C#4:1.9 2:E4:1.9",
    ], 60)
    pad(s, seg, T, 58)
    sweep = [(0, 1.9, 0, 76), (2, 4 / 3, 7, 64), (10 / 3, 2 / 3, 12, 58)]
    still = [(0, 3.8, 0, 62)]
    groove(s, "hollow_bass", seg, T, seq((sweep, 16), (still, 4), (sweep, 8)))
    swirl = [(k / 3, .22, i, v) for k, (i, v) in enumerate(zip([0, 1, 2, 3, 2, 1] * 2,
                                                                [56, 42, 46, 50, 44, 40, 54, 42, 46, 50, 44, 40]))]
    hollow = [(k * 2 / 3, .3, i, 42) for k, i in enumerate([0, 1, 2, 3, 2, 1])]
    groove(s, "thread_pluck", seg, T, seq((swirl, 16), (hollow, 4), (swirl, 8)))
    wind = [(0, 36, 64), (4 / 3, 41, 38), (2, 36, 54), (10 / 3, 41, 42), (11 / 3, 41, 36)]
    wind_fill = [(0, 36, 64), (2, 36, 54), (8 / 3, 41, 40), (3, 41, 46), (10 / 3, 41, 52), (11 / 3, 41, 58)]
    lull = [(0, 36, 50)]
    lift = [(0, 36, 54), (2, 41, 40), (7 / 3, 41, 44), (8 / 3, 41, 48), (3, 41, 52), (10 / 3, 41, 56), (11 / 3, 41, 60)]
    groove(s, "drums", seg, T, seq((wind, 3), (wind_fill, 1), (wind, 3), (wind_fill, 1),
                                   (wind, 3), (wind_fill, 1), (wind, 3), (wind_fill, 1),
                                   (lull, 3), (lift, 1), (wind, 3), (wind_fill, 1), (wind, 3), (wind_fill, 1)))
    s["sections"] = ["1-8: the gale theme - held notes and triplet gusts (Dm9-G/D-C-Am7, Lydian Bb, E7/G# threat)",
                     "9-16: wide second theme with rushing second-violin gusts over F-G-Am, peak on the Lydian E",
                     "17-20: the hollow - thin plucks, fragments of the theme, a lifting gust",
                     "21-28: theme returns with counter-gusts in contrary motion and a higher peak"]
    return finish(s)


# =================================================================== 5. Iskaldra

def iskaldra():
    s = new_score(THEMES[4], "Iskaldra, the Rime Tyrant", 76, 18,
                  "C# minor with Lydian D# over A and a Neapolitan D-major chill",
                  "Ice boss: a music-box bell ostinato, glassy high violins, crystalline plucks and a slow pulse.",
                  "loop_theme", {"dragon": "Iskaldra, the Rime Tyrant", "tonic": "C#", "element": "ice",
                                 "motif": "G#-C#-D#-E (5-1-2-3) in high violin, answered by a cold bell ostinato",
                                 "relation_to_thorns": "Thorns' strings thinned to a high, low-vibrato halo with bells "
                                                       "replacing the pad; 76 BPM, C# minor, sparse pulse."})
    p = s["patches"]
    p["violin_1"].update(vibrato_cents=3.5, vibrato_hz=5.4, bow_noise=.0024, lowpass_hz=4200,
                         attack_seconds=.09, release_seconds=.30, wet=.32)
    p["violin_2"].update(vibrato_cents=3, lowpass_hz=3800, tremolo_division=8, tremolo_depth=.5,
                         attack_seconds=.12, release_seconds=.35, wet=.34)
    p["viola"].update(vibrato_cents=3, lowpass_hz=3000, tremolo_division=8, tremolo_depth=.5,
                      attack_seconds=.12, release_seconds=.35)
    p["lantern_mallet"] = bell_patch(gain=.125, pan=-.22, wet=.38, lowpass_hz=3200)
    p["thread_pluck"].update(lowpass_hz=2800, pan=.32, wet=.30)
    p["drums"].update(lowpass_hz=900, wet=.16)
    p["hollow_bass"].update(wet=.03)
    s["mix"] = mix_plan(viola=-.5, lantern_mallet=["thread_pluck", 4.0], thread_pluck=1.0,
                        hollow_bass=-2.5, drums=-1.0)
    T = {"C#m": ("C#m(add9)", "C#2", None, ["C#6", "G#5", "D#6", "E5"], "C#m"),
         "Amaj7": ("Amaj7(#11)", "A1", None, ["A5", "E5", "G#5", "C#6"], "A"),
         "F#m9": ("F#m9", "F#1", None, ["F#5", "C#6", "G#5", "A5"], "F#m"),
         "G#sus": ("G#7sus4", "G#1", None, ["G#5", "D#6", "C#6", "F#5"], "G#"),
         "G#7": ("G#7(b9)", "G#1", None, ["G#5", "D#6", "B#5", "F#5"], "G#"),
         "Dmaj7": ("Dmaj7(#11) (Neapolitan)", "D2", None, ["D6", "A5", "C#6", "F#5"], "D"),
         "C#m/G#": ("C#m/G#", "G#1", None, ["G#5", "C#6", "E6", "D#6"], "C#m"),
         "Amaj7/G#": ("Amaj7/G#", "G#1", None, ["G#5", "C#6", "E6", "A5"], "A"),
         "F#m9/G#": ("F#m9/G#", "G#1", None, ["G#5", "A5", "C#6", "F#5"], "F#m")}
    seg = progression(s, T, ["C#m", "Amaj7", "F#m9", "G#sus G#7@2", "C#m", "Dmaj7", "F#m9", "G#7",
                             "C#m/G#", "Amaj7/G#", "F#m9/G#", "G#7",
                             "C#m", "Amaj7", "Dmaj7", "G#sus G#7@2", "C#m", "G#sus"])
    motif, answer = "0:G#5:1.4 1.5:C#6:.45 2:D#6:.95 3:E6:.95", "0:D#6:2.9 3:C#6:.95"
    line(s, "violin_1", [
        motif, answer, "0:G#5:1.9 2:A5:.95 3:B5:.95", "0:C#6:1.9 2:B#5:1.9",
        motif, "0:E6:1.4 1.5:D6:.45 2:C#6:1.9", "0:A5:1.9 2:G#5:.95 3:F#5:.95", "0:B#5:1.9 2:A5:.95 3:G#5:.95",
        "0:E6:3.9:v66", "0:D#6:3.9:v66", "0:D6:1.9:v68 2:C#6:1.9:v66", "0:B#5:3.9:v70",
        motif, answer, "0:E6:1.4 1.5:D6:.45 2:A5:1.9", "0:C#6:1.9 2:B#5:1.9", "",
        "2:D#5:.95:v58 3:E5:.5:v62 3.5:F#5:.5:v66",
    ], 74)
    line(s, "violin_2", [
        "0:E5:3.9", "0:C#5:3.9", "0:C#5:3.9", "0:F#5:1.9 2:D#5:1.9", "0:E5:3.9", "0:F#5:3.9", "0:C#5:3.9",
        "0:D#5:1.9 2:B#4:1.9", "0:C#5:4:tr", "0:C#5:4:tr", "0:A4:4:tr", "0:A4:3.9:tr",
        "0:E5:3.9", "0:C#5:3.9", "0:F#5:3.9", "0:F#5:1.9 2:D#5:1.9", "0:E5:3.9:v50", "0:D#5:4:v56",
    ], 60)
    line(s, "viola", [
        "0:G#3:1.9 2:E4:1.9", "0:E4:1.9 2:C#4:1.9", "0:A3:1.9 2:C#4:1.9", "0:C#4:1.9 2:B#3:1.9",
        "0:G#3:1.9 2:E4:1.9", "0:F#4:1.9 2:A3:1.9", "0:A3:1.9 2:C#4:1.9", "0:B#3:1.9 2:D#4:1.9",
        "0:E4:4:tr", "0:E4:4:tr", "0:F#4:4:tr", "0:F#4:3.9:tr",
        "0:G#3:1.9 2:E4:1.9", "0:E4:1.9 2:C#4:1.9", "0:F#4:1.9 2:A3:1.9", "0:C#4:1.9 2:B#3:1.9",
        "0:G#3:3.9:v50", "0:C#4:4:v56",
    ], 56)
    box = {"C#m": "0:C#5:.9 1:G#4:.9 2:D#5:.9 3:G#4:.9", "Amaj7": "0:E5:.9 1:A4:.9 2:D#5:.9 3:A4:.9",
           "F#m9": "0:C#5:.9 1:F#4:.9 2:G#4:.9 3:A4:.9", "G#sus": "0:C#5:.9 1:G#4:.9 2:B#4:.9 3:D#5:.9",
           "Dmaj7": "0:F#5:.9 1:A4:.9 2:C#5:.9 3:A4:.9", "G#7": "0:B#4:.9 1:G#4:.9 2:D#5:.9 3:F#5:.9"}
    line(s, "lantern_mallet", [box[k] for k in ["C#m", "Amaj7", "F#m9", "G#sus", "C#m", "Dmaj7", "F#m9", "G#7"]]
         + ["0:G#4:1.9", "0:G#4:1.9", "0:G#4:1.9", "0:G#4:.9 1:A4:.9 2:G#4:1.9"]
         + [box[k] for k in ["C#m", "Amaj7", "Dmaj7", "G#sus"]]
         + ["0:G#5:.9 1:C#6:.9 2:D#6:.45 2.5:E6:1.4", "0:D#6:.9 1:C#6:.9 2:G#5:1.9"], 66)
    long, split, pedal = [(0, 3.8, 0, 70)], [(0, 1.9, 0, 70), (2, 1.8, 0, 64)], [(0, 1.9, 0, 72), (2, 1.9, 0, 62)]
    groove(s, "hollow_bass", seg, T, seq((long, 3), (split, 1), (long, 4), (pedal, 4),
                                         (long, 3), (split, 1), (long, 1), ([(0, 1.9, 0, 66), (2, 1.95, 0, 68)], 1)))
    drip = [(0, .2, 0, 46), (.75, .2, 1, 40), (1.5, .2, 2, 44), (2.5, .2, 1, 40), (3.25, .2, 3, 42)]
    frost = [(0, .2, 0, 44), (.5, .2, 1, 38), (.75, .2, 2, 40), (1.5, .2, 1, 38), (2, .2, 3, 42),
             (2.25, .2, 2, 38), (3, .2, 1, 40), (3.5, .2, 0, 38)]
    thaw = [(0, .2, 0, 40), (2.5, .2, 1, 36)]
    groove(s, "thread_pluck", seg, T, seq((drip, 8), (frost, 4), (drip, 4), (thaw, 2)))
    pulse = [(0, 36, 68), (2, 36, 52), (3.5, 41, 40)]
    pulse_fill = [(0, 36, 68), (2, 36, 52), (3, 41, 40), (3.5, 41, 46)]
    freeze = [(0, 36, 72), (1.5, 41, 42), (2, 36, 60), (2.75, 42, 34), (3, 41, 46), (3.5, 41, 50)]
    groove(s, "drums", seg, T, seq((pulse, 3), (pulse_fill, 1), (pulse, 3), (pulse_fill, 1), (freeze, 4),
                                   (pulse, 3), (pulse_fill, 1), ([(0, 36, 56)], 1), (pulse_fill, 1)))
    s["sections"] = ["1-8: the rime motif over a bell ostinato (C#m-Amaj7#11-F#m9-G#7, Neapolitan D)",
                     "9-12: frost spreads - G# pedal, tremolo inner strings, a chromatic high descent",
                     "13-16: the motif returns and turns through the Neapolitan to the dominant",
                     "17-18: the motif on bells alone, a frozen music box before the loop"]
    return finish(s)


# =================================================================== 6. Noctyrax

def noctyrax():
    s = new_score(THEMES[5], "Noctyrax, the Last Eclipse", 96, 24,
                  "B-flat minor / Phrygian (C-flat), chromatic build through G, A-flat and A dim7",
                  "Final boss: a tolling Phrygian intro, the Thorns motif eclipsed, a chromatic build and a grand climax.",
                  "loop_theme", {"dragon": "Noctyrax, the Last Eclipse", "tonic": "Bb", "element": "shadow",
                                 "motif": "Bb-F-Db-Cb | Db-Bb: Thorns' C-G-Eb-D | Eb-C in augmentation, lowered, "
                                          "with the Phrygian C-flat replacing Thorns' D",
                                 "relation_to_thorns": "Deliberate distorted quotation: Thorns' opening melody and its "
                                                       "C-G-D-G low pluck figure recur a tone lower, twice as slow, with "
                                                       "a flattened second; progression i-i-bVI-V mirrors Thorns' Cm-Cm-Ab-G7."})
    p = s["patches"]
    p["violin_1"].update(lowpass_hz=3000, vibrato_cents=9, vibrato_hz=4.7, attack_seconds=.06, release_seconds=.20)
    p["violin_2"].update(tremolo_division=8, tremolo_depth=.55)
    p["viola"].update(tremolo_division=8, tremolo_depth=.55)
    p["drums"].update(lowpass_hz=1100, wet=.13)
    p["bowed_veil"].update(lowpass_hz=1400, wet=.34)
    p["lantern_mallet"] = bell_patch(gain=.125, pan=.18, wet=.42, lowpass_hz=1400)
    s["mix"] = mix_plan(violin_1=.75, drums=1.5, bowed_veil=1.5, hollow_bass=.5, violin_2=.5, viola=.5,
                        lantern_mallet=["thread_pluck", 3.0])
    T = {"Bbm": ("Bbm", "Bb1", "Db4", ["Bb2", "F3", "Cb4", "Db3"], "Bbm"),
         "Cb/Bb": ("Cb/Bb (Phrygian bII over pedal)", "Bb1", "Eb4", ["Bb2", "Gb3", "Cb4", "Eb3"], "Cb"),
         "Gb": ("Gbmaj7", "Gb1", "Db4", ["Gb2", "Db3", "F3", "Bb2"], "Gb"),
         "F7b9": ("F7(b9)", "F1", "Gb3", ["F2", "C3", "Gb3", "A2"], "F"),
         "Ebm": ("Ebm", "Eb2", "Gb3", ["Eb3", "Bb3", "F4", "Gb3"], "Ebm"),
         "Cb": ("Cb (Neapolitan)", "Cb2", "Eb4", ["Cb3", "Gb3", "Db4", "Eb3"], "Cb"),
         "Eb/G": ("Eb/G", "G1", "Bb3", ["G2", "Eb3", "Bb3", "G3"], "Eb"),
         "Ab": ("Ab", "Ab1", "C4", ["Ab2", "Eb3", "Bb3", "C3"], "Ab"),
         "Adim7": ("A dim7", "A1", "C4", ["A2", "Eb3", "Gb3", "C3"], "Adim")}
    seg = progression(s, T, ["Bbm", "Cb/Bb", "Bbm", "Cb/Bb",
                             "Bbm", "Bbm", "Gb", "F7b9", "Bbm", "Ebm", "Cb", "F7b9",
                             "Gb", "Eb/G", "Ab", "Adim7",
                             "Bbm", "Gb", "Cb", "F7b9", "Ebm", "Cb", "Gb", "F7b9"])
    line(s, "violin_1", ["", "", "", "",
        "0:Bb4:.95:v74 1:F4:.95:v70 2:Db5:.95:v74 3:Cb5:.95:v72", "0:Db5:1.9:v74 2:Bb4:1.9:v70",
        "0:F4:.95:v72 1:Bb4:.95:v72 2:Cb5:.95:v74 3:Db5:.95:v74", "0:F5:2.9:v78 3:Eb5:.95:v72",
        "0:Db5:1.4:v74 1.5:Bb4:.45:v70 2:Ab4:.95:v72 3:Gb4:.95:v70", "0:F4:1.9:v72 2:Gb4:.95:v72 3:Bb4:.95:v74",
        "0:Eb5:1.9:v76 2:Db5:.95:v72 3:Cb5:.95:v72", "0:A4:1.4:v74 1.5:C5:.45:v74 2:Eb5:.95:v76 3:Gb5:.95:v78",
        # 13-16: chromatic ascent F-Gb-G-Ab-A
        "0:F5:2.9:v72 3:Gb5:.95:v74", "0:G5:2.9:v78 3:Ab5:.95:v80", "0:Ab5:2.9:v84 3:A5:.95:v86",
        "0:Gb5:.95:v86 1:A5:.95:v88 2:C6:.95:v90 3:Eb6:.95:v92",
        # 17-22: the eclipsed Thorns motif an octave higher, at full force
        "0:Bb5:.95 1:F5:.95 2:Db6:.95 3:Cb6:.95", "0:Db6:1.9 2:Bb5:1.9",
        "0:Gb5:.95 1:Bb5:.95 2:Cb6:.95 3:Db6:.95", "0:C6:.95 1:Eb6:.95 2:F6:1.9",
        "0:Eb6:1.4 1.5:Db6:.45 2:Bb5:.95 3:Gb5:.95", "0:Ab5:1.9 2:Gb5:.95 3:Eb5:.95",
        "0:F5:.95:v82 1:Eb5:.95:v78 2:Db5:.95:v76 3:Cb5:.95:v72", "0:A4:2.9:v70",
    ], 90)
    line(s, "violin_2", [
        "0:F4:4:tr:v46", "0:Gb4:4:tr:v48", "0:F4:4:tr:v50", "0:Gb4:3.9:tr:v54",
        "0:F4:3.9:v60", "0:F4:1.9:v60 2:Gb4:1.9:v58", "0:Db4:1.9:v60 2:Eb4:1.9:v58", "0:A4:1.9:v62 2:C5:1.9:v60",
        "0:F4:3.9:v60", "0:Bb4:1.9:v62 2:Eb4:1.9:v60", "0:Gb4:1.9:v62 2:Ab4:1.9:v60", "0:Eb4:1.9:v64 2:A4:1.9:v62",
        "0:Bb4:4:tr:v60", "0:Bb4:4:tr:v64", "0:C5:4:tr:v68", "0:C5:3.9:tr:v74",
        "0:Bb4:.95 1:F4:.95 2:Db5:.95 3:Cb5:.95", "0:Bb5:1.9 2:Gb5:1.9",
        "0:Gb4:.95 1:Bb4:.95 2:Cb5:.95 3:Db5:.95", "0:A5:.95 1:C6:.95 2:A5:1.9",
        "0:Gb5:1.4 1.5:F5:.45 2:Gb5:.95 3:Eb5:.95", "0:Eb5:1.9 2:Db5:.95 3:Gb4:.95",
        "0:Db5:.95:v68 1:Cb5:.95:v66 2:Bb4:.95:v64 3:Ab4:.95:v62", "0:F4:3.9:v58",
    ], 76)
    line(s, "viola", [
        "0:Db4:3.9:v52", "0:Eb4:3.9:v52", "0:Db4:3.9:v54", "0:Eb4:3.9:v56",
        "0:Db4:3.9:v56", "0:F3:1.9:v56 2:Gb3:1.9:v54", "0:Bb3:1.9:v56 2:Db4:1.9:v54", "0:C4:1.9:v58 2:A3:1.9:v56",
        "0:F3:1.9:v56 2:Db4:1.9:v54", "0:Gb3:1.9:v56 2:Bb3:1.9:v54", "0:Eb4:1.9:v58 2:Gb3:1.9:v56", "0:A3:1.9:v60 2:C4:1.9:v58",
        "0:Db4:4:tr:v58", "0:Eb4:4:tr:v62", "0:Eb4:4:tr:v66", "0:Eb4:3.9:tr:v70",
        "0:F4:1.9 2:Db4:1.9", "0:Db4:3.9", "0:Eb4:1.9 2:Gb4:1.9", "0:C4:1.9 2:Eb4:1.9",
        "0:Bb3:1.9 2:Gb3:1.9", "0:Gb3:1.9 2:Eb4:1.9", "0:Bb3:1.9:v62 2:Gb3:1.9:v60", "0:C4:1.9:v58 2:A3:1.9:v56",
    ], 70)
    line(s, "lantern_mallet", ["0:Bb3:1.9", "0:Cb4:1.9", "0:Bb3:1.9", "0:A3:1.9"], 64)
    pad(s, seg, T, 60)
    toll, march = [(0, 3.8, 0, 70)], [(0, 1.4, 0, 78), (1.5, .4, 0, 56), (2, 1.4, 0, 72), (3.5, .4, 12, 58)]

    def climb(lift):
        return [(i * .5, .4, 12 * (i % 2), v + lift) for i, v in enumerate([74, 58, 68, 58, 72, 60, 70, 62])]
    grand = [(0, 1.4, 0, 96), (1.5, .4, 12, 74), (2, 1.4, 0, 90), (3.5, .4, 12, 76)]
    groove(s, "hollow_bass", seg, T, seq((toll, 4), (march, 8), (climb(0), 1), (climb(5), 1), (climb(10), 1),
                                         (climb(15), 1), (grand, 6), (march, 2)))
    thorn = [0, 1, 2, 1, 0, 1, 3, 1]

    def figure(velocities):
        return [(i * .5, .3, k, v) for i, (k, v) in enumerate(zip(thorn, velocities))]
    groove(s, "thread_pluck", seg, T, seq((figure([44, 34, 38, 34, 42, 34, 36, 34]), 4),
                                          (figure([52, 40, 44, 40, 50, 40, 46, 40]), 8),
                                          (figure([56, 44, 48, 44, 54, 44, 50, 44]), 2),
                                          (figure([60, 48, 52, 48, 58, 48, 54, 48]), 2),
                                          (figure([64, 50, 54, 50, 62, 50, 58, 50]), 6),
                                          (figure([56, 44, 48, 44, 50, 40, 44, 38]), 2)))
    n_intro = [(0, 36, 62), (3.5, 41, 34)]
    n_intro_fill = [(0, 36, 64), (3, 41, 40), (3.25, 41, 46), (3.5, 41, 52), (3.75, 41, 58)]
    n_march = [(0, 36, 72), (2, 36, 62), (3, 41, 44), (3.5, 41, 40)]
    n_march_fill = [(0, 36, 72), (2, 36, 62), (3, 41, 46), (3.25, 41, 50), (3.5, 41, 54), (3.75, 41, 60)]

    def n_build(lift):
        return [(0, 36, 76 + lift), (1, 41, 42 + lift), (2, 36, 70 + lift), (3, 41, 48 + lift), (3.5, 41, 54 + lift)]
    n_roll = [(0, 36, 86), (2, 36, 80)] + [(i * .25, 41, 44 + i * 2) for i in range(16)]
    n_grand = [(0, 36, 96), (0, 41, 64), (1, 41, 52), (2, 36, 88), (2, 38, 60), (3, 41, 60), (3.5, 41, 56)]
    n_grand_fill = [(0, 36, 96), (0, 41, 64), (1, 41, 52), (2, 36, 88), (2, 38, 60), (3, 41, 62),
                    (3.25, 41, 66), (3.5, 41, 70), (3.75, 41, 76)]
    n_fall = [(0, 36, 90), (0, 41, 62), (2, 36, 72), (3, 41, 50)]
    groove(s, "drums", seg, T, seq((n_intro, 3), (n_intro_fill, 1), (n_march, 3), (n_march_fill, 1),
                                   (n_march, 3), (n_march_fill, 1), (n_build(0), 1), (n_build(6), 1),
                                   (n_build(12), 1), (n_roll, 1),
                                   (n_grand, 3), (n_grand_fill, 1), (n_grand, 2), (n_fall, 1),
                                   ([(0, 36, 78), (2, 36, 64)], 1)))
    s["sections"] = ["1-4: eclipse - Bb pedal, tolling bell, creeping F/G-flat tremolo, the distorted Thorns pluck figure",
                     "5-12: the Thorns motif eclipsed (Bb-F-Db-Cb) over Bbm-Gb-F7b9, then Ebm and the Neapolitan C-flat",
                     "13-16: chromatic build G-flat, E-flat/G, A-flat, A dim7 with tremolo and a tom roll",
                     "17-22: grand climax - the motif an octave higher in octaves/thirds, peak F6 on F7(b9)",
                     "23-24: Phrygian collapse back to the pedal"]
    return finish(s)


# =================================================================== stingers

def stinger(slug, title, bpm, bars, key, mood, identity):
    s = new_score(slug, title, bpm, bars, key, mood, "stinger", identity)
    s["patches"]["hollow_bass"].update(wet=.04)
    return s


def level_up():
    s = stinger(STINGERS[0], "Level Up", 120, 2, "D major (IV-V-I)",
                "Warm rising flourish: IV-V-I with a chromatic G-G#-A lift into a bright D chord.",
                {"use": "character level up", "gesture": "rising scale into a sustained D major arrival"})
    p = s["patches"]
    p["violin_1"].update(lowpass_hz=3200, vibrato_cents=9)
    p["lantern_mallet"] = bell_patch(gain=.125, pan=.24, wet=.30, lowpass_hz=4000)
    p["thread_pluck"].update(lowpass_hz=2000)
    s["mix"] = mix_plan(violin_1=1.0, hollow_bass=-1.0, thread_pluck=2.0, drums=-3.0,
                        lantern_mallet=["thread_pluck", 3.0])
    s["reverb"] = {"rt60_seconds": 1.5, "wet": .22}
    T = {"G": ("G/B", "G2", None, [], "G"), "A": ("A", "A2", None, [], "A"), "D": ("D", "D2", None, [], "D")}
    progression(s, T, ["G A@1 D@2", "D"])
    line(s, "violin_1", ["0:D5:.5 .5:E5:.5 1:F#5:.5 1.5:G5:.25 1.75:G#5:.25 2:A5:2", ""], 80)
    line(s, "violin_2", ["0:B4:1 1:C#5:1 2:F#5:2", ""], 70)
    line(s, "viola", ["0:D4:1 1:E4:1 2:A4:2", ""], 66)
    line(s, "hollow_bass", ["0:B2:.95:v74 1:A2:.95:v76 2:D2:2.1:v84", ""], 80)
    line(s, "thread_pluck", ["0:G3:.2 .25:B3:.2 .5:D4:.2 .75:G4:.2 1:A3:.2 1.25:C#4:.2 1.5:E4:.2 1.75:A4:.2 "
                             "2:D4:.2 2.25:F#4:.2 2.5:A4:.2 2.75:D5:.3", ""], 58)
    line(s, "lantern_mallet", ["2:F#5:.45 2.5:A5:.45 3:D6:1.2", ""], 62)
    line(s, "drums", ["1.5:41:.2:v40 1.75:41:.2:v48 2:36:.28:v66", ""], 60)
    s["sections"] = ["0-1 s: rising IV-V run with arpeggiated pluck", "1 s: D major arrival, bell sparkle, natural tail"]
    return finish(s)


def rare_reward():
    s = stinger(STINGERS[1], "Rare Reward", 132, 2, "E-flat Lydian (Ebmaj7#11)",
                "Mysterious treasure shimmer: a bell cascade through the Lydian A natural over tremolo harmonics.",
                {"use": "rare/epic/legendary find", "gesture": "ascending bell cascade and unresolved #11 shimmer"})
    p = s["patches"]
    p["lantern_mallet"] = bell_patch(gain=.125, pan=-.12, wet=.34, lowpass_hz=4500)
    for lane in ["violin_1", "violin_2"]:
        p[lane].update(tremolo_division=8, tremolo_depth=.5, lowpass_hz=4200, attack_seconds=.25, release_seconds=.5)
    p["viola"].update(attack_seconds=.3, release_seconds=.5)
    p["thread_pluck"].update(lowpass_hz=3200, wet=.34)
    s["mix"] = mix_plan(lantern_mallet=["thread_pluck", 6.0], violin_1=-3.0, violin_2=-3.0, viola=-4.0,
                        hollow_bass=-4.0, thread_pluck=1.0)
    s["reverb"] = {"rt60_seconds": 1.3, "wet": .28}
    T = {"Eb": ("Ebmaj7(#11)", "Eb2", None, [], "Eb")}
    progression(s, T, ["Eb", "Eb"])
    line(s, "lantern_mallet", ["0:Bb4:.25 .25:D5:.25 .5:F5:.25 .75:A5:.25 1:Bb5:.25 1.25:D6:.25 1.5:F6:.5 "
                               "2.25:A5:.45 2.75:D6:.8", ""], 66)
    line(s, "violin_1", [".5:D6:2.6:tr:v50", ""], 50)
    line(s, "violin_2", [".5:A5:2.6:tr:v48", ""], 48)
    line(s, "viola", [".5:G4:2.6:v46", ""], 46)
    line(s, "hollow_bass", ["0:Eb2:3:v58", ""], 58)
    line(s, "thread_pluck", ["1.25:G5:.2 1.75:D6:.2 2.25:A5:.2 2.75:F5:.2 3.25:D6:.2", ""], 44)
    s["sections"] = ["0-0.8 s: bell cascade Bb-D-F-A-Bb-D-F", "0.8-2.5 s: #11 shimmer and ringing tail"]
    return finish(s)


def boss_defeated():
    s = stinger(STINGERS[2], "Boss Defeated", 84, 3, "C major (Aeolian bVI-bVII-I)",
                "Grand victory cadence: A-flat and B-flat triads hammer into a C major arrival with bells and a final leap.",
                {"use": "boss defeated", "gesture": "bVI-bVII-I parallel triads, heavy drums, C major Picardy arrival"})
    p = s["patches"]
    p["violin_1"].update(lowpass_hz=3400, vibrato_cents=11)
    p["lantern_mallet"] = bell_patch(gain=.125, pan=.22, wet=.36, lowpass_hz=3000)
    p["drums"].update(lowpass_hz=1300, wet=.12)
    s["mix"] = mix_plan(drums=3.0, hollow_bass=1.0, violin_1=1.0, violin_2=1.0, viola=1.0,
                        lantern_mallet=["thread_pluck", 3.0])
    s["reverb"] = {"rt60_seconds": 2.0, "wet": .24}
    T = {"Ab": ("Ab (bVI)", "Ab1", None, [], "Ab"), "Bb": ("Bb (bVII)", "Bb1", None, [], "Bb"),
         "C": ("C major", "C2", None, [], "C")}
    progression(s, T, ["Ab Bb@1.5 C@3", "C", "C"])
    line(s, "violin_1", ["0:Eb5:1.45 1.5:F5:1.1 8/3:F5:1/3 3:G5:1.9 5:C6:1.8", "", ""], 86)
    line(s, "violin_2", ["0:C5:1.45 1.5:D5:1.45 3:E5:3.8", "", ""], 78)
    line(s, "viola", ["0:Ab4:1.45 1.5:Bb4:1.45 3:C5:3.8", "", ""], 74)
    line(s, "hollow_bass", ["0:Ab1:1.45:v92 1.5:Bb1:1.45:v90 3:C2:3.8:v96", "", ""], 90)
    line(s, "thread_pluck", ["0:Ab3:.12 .125:C4:.12 .25:Eb4:.12 .375:Ab4:.3 1.5:Bb3:.12 1.625:D4:.12 "
                             "1.75:F4:.12 1.875:Bb4:.3 3:C4:.12 3.125:E4:.12 3.25:G4:.12 3.375:C5:.12 3.5:E5:.5",
                             "", ""], 64)
    line(s, "lantern_mallet", ["3:G5:.9 4:C6:.9 5:E6:1.3", "", ""], 66)
    line(s, "drums", ["0:36:.28:v100 0:41:.2:v72 1.5:36:.28:v92 1.5:41:.2:v66 2.5:41:.2:v58 2.75:41:.2:v66 "
                      "3:36:.28:v104 3:41:.2:v78 5:41:.2:v54", "", ""], 90)
    s["sections"] = ["0-1.1 s: A-flat hit", "1.1-2.1 s: B-flat hit and tom pickup",
                     "2.1-5.2 s: C major arrival, bells, leap to C6", "5.2 s+: natural hall tail"]
    return finish(s)


BUILDERS = {THEMES[0]: zekarion, THEMES[1]: tharokh, THEMES[2]: vyraketh, THEMES[3]: vaeloryx,
            THEMES[4]: iskaldra, THEMES[5]: noctyrax,
            STINGERS[0]: level_up, STINGERS[1]: rare_reward, STINGERS[2]: boss_defeated}


def compositions(only=None):
    return [BUILDERS[slug]() for slug in SLUGS if not only or slug in only]
