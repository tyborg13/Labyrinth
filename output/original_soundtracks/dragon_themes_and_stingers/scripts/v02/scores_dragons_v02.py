"""Authored v02 scores: Noctyrax (final boss) takes A and B, and three dark-fantasy stingers.

Reuses the v01 score scaffolding (imported, unchanged). Tokens read
``beat:pitch[+pitch...]:duration[:flags]``; flags are ``vNN`` (velocity), ``tr`` (bowed
tremolo), ``roll`` (timpani roll), ``sw``/``sfz``/``fd`` (swell, sforzando, fade shapes)
and ``oo``/``oh``/``ah``/``ahh`` (choir vowel). ``+`` stacks a chord in one lane.
"""
from __future__ import annotations

import copy
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import dragon_scores as v1  # noqa: E402  (v01 scaffolding and the approved engine chain)

v01 = v1.v01
THEMES = ["06a_noctyrax_the_last_eclipse_take_a", "06b_noctyrax_the_last_eclipse_take_b"]
STINGERS = ["07_stinger_level_up", "08_stinger_rare_reward", "09_stinger_boss_defeated"]
SLUGS = THEMES + STINGERS
PERCUSSION = {"drums", "taiko", "timpani"}
STRING_LANES = {"violin_1", "violin_2", "viola", "cello", "contrabass"}
SHAPES = {"sw": "swell", "sfz": "sfz", "fd": "fade"}
VOWELS = {"oo": "oo", "oh": "oh", "ah": "ah", "ahh": "ah_high"}


# ----------------------------------------------------------------- scaffolding

def line(s, part, bars, velocity, start_bar=0):
    for bar, text in enumerate(bars, start_bar):
        for i, token in enumerate(text.split()):
            fields = token.split(":")
            vel, extra = velocity - 3 * (i % 2), {}
            for flag in fields[3:]:
                if flag == "tr":
                    extra["articulation"] = "tremolo"
                elif flag == "roll":
                    extra["articulation"] = "roll"
                elif flag in SHAPES:
                    extra["shape"] = SHAPES[flag]
                elif flag in VOWELS:
                    extra["vowel"] = VOWELS[flag]
                elif flag.startswith("v"):
                    vel = int(flag[1:])
                else:
                    raise ValueError(f"Unknown flag in {token}")
            for pitch in fields[1].split("+"):
                v01.add(s, part, bar, v1.num(fields[0]), v1.num(fields[2]), v1.pitch_of(pitch), min(127, vel))
                s["notes"][-1].update(extra)


def hits(s, part, plan, gate=.2):
    """Percussion plan: one list of (beat, MIDI note, velocity) per bar."""
    for bar, events in enumerate(plan):
        for beat, note, vel in events:
            v01.add(s, part, bar, beat, gate, note, min(127, vel))


def ostinato(s, part, harmony, figures, velocities, accents, step, gate, shift=0, bars=None):
    """Repeated authored figures (one per chord) with an accent map; velocities per bar (None = rest)."""
    for bar, (chord, velocity) in enumerate(zip(harmony, velocities)):
        if velocity is None or (bars is not None and bar not in bars):
            continue
        for i, (pitch, accent) in enumerate(zip(figures[chord].split(), accents)):
            v01.add(s, part, bar, i * step, gate, v1.pitch_of(pitch) + shift, max(1, min(127, velocity + accent)))


def shifted(bars, semitones):
    out = []
    for text in bars:
        tokens = []
        for token in text.split():
            fields = token.split(":")
            fields[1] = "+".join(v1.name(v1.pitch_of(p) + semitones) for p in fields[1].split("+"))
            tokens.append(":".join(fields))
        out.append(" ".join(tokens))
    return out


def ramp(start, stop, count):
    return [round(start + (stop - start) * i / max(count - 1, 1)) for i in range(count)]


def v02_score(slug, title, bpm, bars, key, mood, kind, identity, lead="violin_1"):
    s = v1.new_score(slug, title, bpm, bars, key, mood, kind, identity)
    s.update(version="v02", lead_instrument=lead,
             palette="Thorns v02 string ensemble extended for the final boss: low strings in octaves, "
                     "formant choir, low brass, taiko, timpani and a tolling bell")
    p = s["patches"]
    p["cello"] = v1.cello_patch(hall=.3)
    p["contrabass"] = v1.cello_patch(program=43, lowpass_hz=1500, attack_seconds=.09, vibrato_cents=3,
                                     pan=.04, bow_noise=.004, hall=.25)
    for lane in ["violin_1", "violin_2", "viola"]:
        p[lane]["hall"] = .32
    p["thread_pluck"]["hall"] = .2
    p["hollow_bass"]["hall"] = 0.0
    p["choir_low"] = {"synth": "choir", "program": 52, "voices": 6, "vowel": "oh", "pan": -.18, "spread": .7,
                      "attack_seconds": .3, "release_seconds": .7, "vibrato_cents": 16, "detune_cents": 7,
                      "breath": .02, "wet": .16, "hall": .55, "lowpass_hz": 5200}
    p["choir_high"] = dict(p["choir_low"], vowel="ah_high", pan=.18, attack_seconds=.22)
    p["brass"] = {"synth": "brass", "program": 57, "voices": 3, "pan": .1, "attack_seconds": .07,
                  "release_seconds": .3, "wet": .12, "hall": .42, "lowpass_hz": 5000}
    p["taiko"] = {"synth": "taiko", "program": 0, "percussion": True, "pan": 0.0, "wet": .05, "hall": .35}
    p["timpani"] = {"synth": "timpani", "program": 47, "pan": -.12, "wet": .06, "hall": .3}
    p["toll"] = {"synth": "toll", "program": 14, "pan": .2, "ring_seconds": 6.0, "wet": .12, "hall": .5}
    s["reverb"] = {"rt60_seconds": 2.6, "return": .55}
    return s


def finish(s):
    s = v1.finish(s)
    for n in s["notes"]:
        n["velocity"] = max(1, min(127, n["velocity"]))
    return s


# =================================================================== Noctyrax take A

def noctyrax_a():
    s = v02_score(THEMES[0], "Noctyrax, the Last Eclipse (take A: Eclipse Requiem)", 88, 32,
                  "B-flat minor / Phrygian (C-flat), chromatic build through G, A-flat and A dim7",
                  "Final boss, processional take: an impact that hushes into a tolling eclipse, a relentless "
                  "low-string ostinato, the Thorns motif in low brass and choir, and a full-ensemble summit.",
                  "loop_theme", {"dragon": "Noctyrax, the Last Eclipse", "tonic": "Bb", "element": "shadow",
                                 "take": "A", "motif": "Bb-F-Db-Cb | Db-Bb (Thorns' C-G-Eb-D | Eb-C eclipsed: lower, "
                                 "augmented, Phrygian flat second), carried by low brass then choir",
                                 "relation_to_thorns": "Distorted quotation of Thorns' opening and its pluck figure; "
                                 "i-i-bVI-V mirrors Cm-Cm-Ab-G7. Bigger forces: choir, brass, taiko, timpani, bell."},
                  lead="brass")
    s["mix"] = v1.mix_plan(violin_1=1.0, violin_2=0.0, viola=.5, thread_pluck=-1.0, hollow_bass=-2.0,
                           cello=["violin_1", -1.5], contrabass=["hollow_bass", -3.5],
                           choir_low=["violin_2", 1.5], choir_high=["violin_1", -.5], brass=["violin_1", .5],
                           taiko=["drums", 5.5], timpani=["drums", 1.5], toll=["thread_pluck", 6.0])
    T = {"Bbm": ("Bbm", "Bb1", None, ["Bb2", "F3", "Cb4", "Db3"], "Bbm"),
         "Cb/Bb": ("Cb/Bb (Phrygian bII over pedal)", "Bb1", None, ["Bb2", "Gb3", "Cb4", "Eb3"], "Cb"),
         "Gb": ("Gbmaj7", "Gb1", None, ["Gb2", "Db3", "F3", "Bb2"], "Gb"),
         "F7b9": ("F7(b9)", "F1", None, ["F2", "C3", "Gb3", "A2"], "F"),
         "F": ("F (major dominant)", "F1", None, ["F2", "C3", "A2", "F3"], "F"),
         "Ebm": ("Ebm", "Eb2", None, ["Eb3", "Bb3", "F4", "Gb3"], "Ebm"),
         "Cb": ("Cb (Neapolitan)", "Cb2", None, ["Cb3", "Gb3", "Db4", "Eb3"], "Cb"),
         "Eb/G": ("Eb/G", "G1", None, ["G2", "Eb3", "Bb3", "G3"], "Eb"),
         "Ab": ("Ab", "Ab1", None, ["Ab2", "Eb3", "Bb3", "C3"], "Ab"),
         "Adim7": ("A dim7", "A1", None, ["A2", "Eb3", "Gb3", "C3"], "Adim")}
    H = ["Bbm", "Cb/Bb", "Bbm", "Cb/Bb",
         "Bbm", "Bbm", "Gb", "F7b9", "Bbm", "Ebm", "Cb", "F7b9",
         "Gb", "Eb/G", "Ab", "Adim7",
         "Bbm", "Gb", "Cb", "F7b9", "Ebm", "Cb", "Gb", "F7b9",
         "Bbm", "Gb", "Ebm", "F",
         "Bbm", "Cb", "Adim7", "F7b9"]
    seg = v1.progression(s, T, H)
    # Relentless low-string ostinato: root, Phrygian upper neighbour, a third/fifth kick at the bar end.
    OST = {"Bbm": "Bb2 Bb2 Cb3 Bb2 Bb2 Bb2 Db3 Cb3", "Cb/Bb": "Bb2 Bb2 Cb3 Bb2 Bb2 Bb2 Eb3 Cb3",
           "Cb": "Cb3 Cb3 Db3 Cb3 Cb3 Cb3 Eb3 Db3", "Gb": "Gb2 Gb2 Ab2 Gb2 Gb2 Gb2 Bb2 Ab2",
           "F7b9": "F2 F2 Gb2 F2 F2 F2 A2 Gb2", "F": "F2 F2 Gb2 F2 F2 F2 A2 C3",
           "Ebm": "Eb2 Eb2 Fb2 Eb2 Eb2 Eb2 Gb2 Fb2", "Eb/G": "G2 G2 Ab2 G2 G2 G2 Bb2 Ab2",
           "Ab": "Ab2 Ab2 Bb2 Ab2 Ab2 Ab2 C3 Bb2", "Adim7": "A2 A2 Bb2 A2 A2 A2 C3 Bb2"}
    accents = [10, -6, 4, -6, 8, -6, 4, -2]
    drive = [None] * 4 + [64] * 8 + ramp(70, 84, 4) + [94] * 8 + [None] * 4 + ramp(58, 88, 4)
    ostinato(s, "cello", H, OST, drive, accents, .5, .4)
    ostinato(s, "contrabass", H, OST, drive, accents, .5, .4, shift=-12)
    ostinato(s, "viola", H, OST, [None] * 16 + [86] * 8 + [None] * 8, accents, .5, .4, shift=12)
    line(s, "contrabass", ["0:Bb1:2:fd:v110 2:Bb1:13.9:v62"], 62)
    line(s, "contrabass", ["0:Bb1:7.9:v60", "", "0:Eb2:3.9:v60", "0:A1:3.9:v62"], 60, 24)
    line(s, "cello", ["0:Bb2:3.5:fd:v108"], 100)
    motif = ["0:Bb3:.95 1:F3:.95 2:Db4:.95 3:Cb4:.95", "0:Db4:1.9 2:Bb3:1.9",
             "0:F3:.95 1:Bb3:.95 2:Cb4:.95 3:Db4:.95", "0:F4:2.9 3:Eb4:.95",
             "0:Db4:1.4 1.5:Bb3:.45 2:Ab3:.95 3:Gb3:.95", "0:F3:1.9 2:Gb3:.95 3:Bb3:.95",
             "0:Eb4:1.9 2:Db4:.95 3:Cb4:.95", "0:A3:1.4 1.5:C4:.45 2:Eb4:.95 3:Gb4:.95"]
    line(s, "brass", ["0:Bb1+F2+Bb2:3.5:fd:v124", "", "", "0:F2+C3:3.9:sw:v84"], 100)
    line(s, "brass", motif, 100, 4)
    line(s, "brass", ["0:Bb2:7.9:v92", "", "0:Gb2:3.9:v92", "0:F2:3.9:v94", "0:Bb2:3.9:v94", "0:Eb2:3.9:v94",
                      "0:Cb2:3.9:v96", "0:F2:3.9:v98"], 100, 4)
    line(s, "brass", ["0:Gb2+Db3+Bb3:3.9:sw:v80", "0:G2+Eb3+Bb3:3.9:sw:v88", "0:Ab2+Eb3+C4:3.9:sw:v96",
                      "0:A2+Eb3+Gb3+C4:3.9:sw:v106",
                      "0:Bb2+F3+Db4:3.9:sfz:v120", "0:Gb2+Db3+Bb3:3.9:v112", "0:Cb3+Gb3+Eb4:3.9:sfz:v118",
                      "0:F2+C3:3.9:sw:v116 0:A3:1.9:sw:v112 2:Eb4:1.9:sw:v118",
                      "0:Eb2+Bb2+Gb3:3.9:sfz:v124", "0:Cb2+Gb2+Eb3:3.9:v116", "0:Gb2+Db3+Bb3:3.9:v112",
                      "0:F2+C3+A3:1.9:v118 2:F2+A3:1.9:sw:v122 2:Eb4:1.9:sw:v120",
                      "", "", "", "",
                      "0:Bb2+F3+Db4:3.9:sw:v72", "0:Cb3+Gb3+Eb4:3.9:sw:v84", "0:A2+Eb3+C4:3.9:sw:v96",
                      "0:F2+C3+A3+Eb4:3.9:sw:v112"], 100, 12)
    line(s, "choir_low", ["1:Bb2+F3:2.9:oo:v66", "0:Bb2+Gb3:3.9:oo:v68", "0:Bb2+F3:3.9:oo:v70", "0:Bb2+Gb3:3.9:oo:v74",
                          "0:Bb2+F3:7.9:v68", "", "0:Gb2+Db3:3.9:v70", "0:F2+C3:3.9:v72", "0:Bb2+F3:3.9:v72",
                          "0:Eb3+Bb3:3.9:v72", "0:Cb3+Gb3:3.9:v74", "0:F2+C3:3.9:v76",
                          "0:Gb2+Db3:3.9:ah:v80", "0:G2+Eb3:3.9:ah:v86", "0:Ab2+Eb3:3.9:ah:v92", "0:A2+Eb3:3.9:ah:v100"]
         + [f"0:{c}:3.9:ah:v{v}" for c, v in [("Bb2+F3", 118), ("Gb2+Db3", 114), ("Cb3+Gb3", 118), ("F2+C3", 118),
                                             ("Eb3+Bb3", 122), ("Cb3+Gb3", 118), ("Gb2+Db3", 114), ("F2+C3", 116)]]
         + ["0:Bb2+F3:3.9:v76", "0:Bb2+Gb3:3.9:v74", "0:Bb2+Gb3:3.9:v76", "0:A2+F3:3.9:v80",
            "0:Bb2+F3:3.9:v66", "0:Cb3+Gb3:3.9:v76", "0:A2+Eb3:3.9:ah:v88", "0:F2+C3:3.9:ah:v104"], 70)
    soprano = (["", "", "", "", "", "", "", ""]
               + shifted(motif[4:], 12)
               + ["0:F5:3.9:v76", "0:G5:3.9:v84", "0:Ab5:3.9:v92", "0:A5:1.9:v100 2:Gb5:1.9:v104"]
               + ["0:Bb4:1.9 2:Db5:1.9", "0:Db5:3.9", "0:Eb5:1.9 2:Cb5:1.9", "0:C5:1.9 2:Eb5:1.9", "0:Gb5:3.9",
                  "0:Eb5:1.9 2:Cb5:1.9", "0:Bb4:1.9 2:Gb4:1.9", "0:F4:3.9"]
               + [f"{t}" for t in shifted(motif[:3], 12)] + ["0:C5:1.9 2:A4:1.9"]
               + ["0:Bb4:3.9:v64", "0:Cb5:3.9:v74", "0:C5:3.9:v86", "0:Eb5:3.9:v100"])
    line(s, "choir_high", soprano[:8], 74)
    line(s, "choir_high", soprano[8:12], 74, 8)
    line(s, "choir_high", soprano[12:16], 80, 12)
    line(s, "choir_high", soprano[16:24], 118, 16)
    line(s, "choir_high", soprano[24:28], 92, 24)
    line(s, "choir_high", soprano[28:], 80, 28)
    line(s, "choir_high", ["0:Db5:3.9:v74", "0:Eb5:3.9:v82", "0:Eb5:3.9:v90", "0:Eb5:3.9:v98",
                           "0:F4:3.9", "0:Bb4:3.9", "0:Gb4:3.9", "0:A4:3.9", "0:Bb4:3.9", "0:Gb4:3.9", "0:Db4:3.9",
                           "0:C4:1.9 2:A3:1.9"], 112, 12)
    line(s, "choir_high", ["0:Db4:3.9", "0:Gb4:3.9", "0:Eb4:3.9", "0:F4:1.9 2:Eb4:1.9",
                           "0:F4:3.9:v62", "0:Gb4:3.9:v70", "0:Gb4:3.9:v80", "0:A4:3.9:v94"], 86, 24)
    summit = ["0:Bb5:1.45 1.5:F5:.45 2:Db6:.95 3:Cb6:.95", "0:Db6:2.9 3:Bb5:.95",
              "0:Eb6:1.45 1.5:Db6:.45 2:Cb6:.95 3:Bb5:.95", "0:A5:1.9 2:C6:.95 3:Eb6:.95", "0:Gb6:2.9 3:F6:.95",
              "0:Eb6:1.45 1.5:Db6:.45 2:Cb6:1.9", "0:Bb5:1.45 1.5:Ab5:.45 2:Gb5:.95 3:F5:.95", "0:Gb5:.95 1:F5:2.9"]
    line(s, "violin_1", ["0:Db6:1.5:fd:v104", "0:F6:3.9:tr:v54", "0:F6:3.9:tr:v56", "0:Gb6:3.9:tr:v60",
                         "", "", "", "", "0:F5:3.9:tr:v50", "0:Gb5:3.9:tr:v52", "0:Gb5:3.9:tr:v54", "0:A5:3.9:tr:v58",
                         "0:Db6:3.9:tr:v62", "0:Eb6:3.9:tr:v70", "0:Eb6:3.9:tr:v78",
                         "0:Gb5:.95:v86 1:A5:.95:v88 2:C6:.95:v92 3:Eb6:.95:v96"]
         + summit + ["", "", "", "",
                     "0:F5:3.9:tr:v54", "0:Gb5:3.9:tr:v64", "0:A5:3.9:tr:v76", "0:C6:1.9:tr:v88 2:Eb6:1.9:tr:v100"], 98)
    line(s, "violin_2", ["0:Bb5:1.5:fd:v100", "0:Bb5:3.9:tr:v52", "0:Bb5:3.9:tr:v54", "0:Cb6:3.9:tr:v58",
                         "", "", "", "", "0:Db5:3.9:tr:v48", "0:Eb5:3.9:tr:v50", "0:Eb5:3.9:tr:v52", "0:Eb5:3.9:tr:v56",
                         "0:Bb5:3.9:tr:v60", "0:Bb5:3.9:tr:v68", "0:C6:3.9:tr:v76", "0:C6:3.9:tr:v88",
                         "0:Bb4:1.45 1.5:F4:.45 2:Db5:.95 3:Cb5:.95", "0:Bb5:2.9 3:Gb5:.95",
                         "0:Eb5:1.45 1.5:Db5:.45 2:Cb5:.95 3:Bb4:.95", "0:F5:1.9 2:A5:.95 3:C6:.95",
                         "0:Eb6:2.9 3:Db6:.95", "0:Gb5:1.45 1.5:F5:.45 2:Eb5:1.9",
                         "0:Gb5:1.45 1.5:F5:.45 2:Db5:.95 3:Db5:.95", "0:Eb5:.95 1:C5:2.9",
                         "", "", "", "",
                         "0:Db5:3.9:tr:v52", "0:Eb5:3.9:tr:v62", "0:Gb5:3.9:tr:v74", "0:A5:3.9:tr:v90"], 92)
    line(s, "viola", ["0:F4:1.5:fd:v96", "", "", "", "0:Db4:7.9:v52", "", "0:Db4:3.9:v54", "0:C4:3.9:v56",
                      "0:Db4:3.9:v56", "0:Gb3:3.9:v56", "0:Eb4:3.9:v58", "0:Eb4:3.9:v60",
                      "0:Db4:3.9:tr:v62", "0:Eb4:3.9:tr:v70", "0:Eb4:3.9:tr:v78", "0:Eb4:3.9:tr:v88"], 60)
    line(s, "viola", ["0:F4:3.9:tr:v54", "0:Gb4:3.9:tr:v62", "0:Gb4:3.9:tr:v72", "0:A4:3.9:tr:v86"], 60, 28)
    line(s, "timpani", ["0:Bb2:.5:v124", "0:Bb2:.5:v64", "0:Bb2:.5:v66", "0:Bb2:.5:v68 2:F2:1.9:roll:v96",
                        "0:Bb2:.5:v90", "", "0:Gb2:.5:v88", "0:F2:.5:v92", "0:Bb2:.5:v92", "0:Eb2:.5:v88",
                        "0:Gb2:.5:v88", "0:F2:.5:v92 2:F2:1.9:roll:v92",
                        "0:Gb2:.5:v92", "0:G2:.5:v96", "0:Ab2:.5:v100", "0:A2:3.9:roll:v112",
                        "0:Bb2:.5:v120 2:F2:.5:v104", "0:Gb2:.5:v116 2:Db3:.5:v100", "0:Gb2:.5:v118 2:Eb3:.5:v100",
                        "0:F2:.5:v120 2:F2:.5:v104", "0:Eb3:.5:v120 2:Bb2:.5:v104", "0:Gb2:.5:v116 2:Eb3:.5:v100",
                        "0:Gb2:.5:v114 2:Db3:.5:v100", "0:F2:.5:v120 2:F2:1.9:roll:v110",
                        "0:Bb2:.5:v74", "0:Gb2:.5:v70", "0:Eb3:.5:v74", "0:F2:.5:v78",
                        "0:Bb2:.5:v74", "0:Gb2:.5:v82", "0:F2:7.9:roll:v118", ""], 100)
    line(s, "toll", ["0:Bb3:4:v120", "", "0:Cb4:4:v80"] + [""] * 13 + ["0:Bb3:4:v112"] + [""] * 7
         + ["0:Bb3:4:v92", "", "0:Gb3:4:v84"], 100)
    impact = [(0, 35, 127), (0, 43, 112)]
    heart = [(0, 35, 72), (.5, 35, 56)]
    heart_fill = heart + [(3, 43, 50), (3.25, 43, 56), (3.5, 43, 64), (3.75, 43, 72)]
    march = [(0, 35, 104), (1, 43, 70), (2, 35, 96), (3, 43, 74), (3.5, 43, 60), (3.75, 43, 66)]
    march_fill = [(0, 35, 104), (1, 43, 70), (2, 35, 96), (2.5, 43, 64), (3, 43, 76), (3.25, 43, 80),
                  (3.5, 47, 84), (3.75, 47, 90)]

    def rise(k):
        return [(0, 35, 100 + k), (1, 43, 70 + k), (1.5, 43, 60 + k), (2, 35, 96 + k), (3, 43, 74 + k), (3.5, 43, 70 + k)]
    roll = [(0, 35, 116), (2, 35, 110)] + [(i * .25, 43 if i < 8 else 47, 62 + i * 3) for i in range(16)]
    summit_kit = [(0, 35, 124), (0, 43, 100), (1, 43, 84), (1.5, 43, 70), (2, 35, 118), (2, 43, 96), (2.75, 43, 74),
                  (3, 43, 88), (3.5, 47, 80), (3.75, 47, 90)]
    summit_fill = summit_kit[:7] + [(3, 43, 92), (3.25, 47, 90), (3.5, 47, 96), (3.75, 47, 104)]
    gather = [[(0, 35, 74), (2, 35, 70)], [(0, 35, 82), (1, 43, 60), (2, 35, 80), (3, 43, 66)],
              [(0, 35, 92), (.5, 43, 64), (1, 43, 70), (1.5, 43, 74), (2, 35, 96), (2.5, 43, 78), (3, 43, 82),
               (3.5, 43, 86)],
              [(0, 35, 112), (2, 35, 116)] + [(i * .25, 43 if i < 8 else 47, 70 + i * 3) for i in range(16)]]
    hits(s, "taiko", [impact, heart, heart, heart_fill] + [march] * 3 + [march_fill] + [march] * 3 + [march_fill]
         + [rise(0), rise(6), rise(12), roll] + [summit_kit] * 3 + [summit_fill] + [summit_kit] * 3 + [summit_fill]
         + [[(0, 35, 66), (2, 35, 54)], [(0, 35, 62), (2, 35, 52)], [(0, 35, 66), (2, 35, 54)],
            [(0, 35, 70), (2, 35, 58), (3.5, 43, 56)]] + gather)
    figure = [0, 1, 2, 1, 0, 1, 3, 1]
    v1.groove(s, "thread_pluck", seg, T, [[]] * 4 + [[(i * .5, .3, k, v) for i, (k, v) in
                                                       enumerate(zip(figure, [52, 40, 44, 40, 50, 40, 46, 40]))]] * 8
              + [[]] * 20)
    v1.groove(s, "hollow_bass", seg, T, [[(0, 3, 0, 110)], [], [], []] + [[(0, 3.8, 0, 70)]] * 8
              + [[(0, 3.8, 0, v)] for v in ramp(74, 88, 4)] + [[(0, 3.8, 0, 96)]] * 8 + [[]] * 4
              + [[(0, 3.8, 0, v)] for v in ramp(66, 92, 4)])
    s["sections"] = ["1-4: impact, then the eclipse - Bb pedal, tolling bell, choir hum, creeping high tremolo",
                     "5-12: procession - low-string ostinato and taiko; low brass sings the eclipsed Thorns motif, "
                     "choir joins (Bbm-Gb-F7b9, Ebm, Neapolitan Cb)",
                     "13-16: chromatic rise Gb, Eb/G, Ab, A dim7 - brass swells, tremolo, timpani roll",
                     "17-24: summit - full ensemble: high violins and choir melody, ostinato in three octaves, "
                     "brass chorale, taiko and timpani, peak Gb6 over Ebm",
                     "25-28: requiem - choir almost alone sings the motif over a drone and bells",
                     "29-32: the gathering storm - ostinato, brass and choir crescendo into the loop's impact"]
    return finish(s)


# =================================================================== Noctyrax take B

def noctyrax_b():
    s = v02_score(THEMES[1], "Noctyrax, the Last Eclipse (take B: Black Sun Onslaught)", 132, 48,
                  "E Phrygian (F natural), with a tritone B-flat and a B7 dominant",
                  "Final boss, relentless take: churning sixteenth-note low strings, syncopated taiko, choir "
                  "chants, the Thorns motif eclipsed in the violins and a brass/choir anthem at full force.",
                  "loop_theme", {"dragon": "Noctyrax, the Last Eclipse", "tonic": "E", "element": "shadow",
                                 "take": "B", "motif": "E-B-G-F-G-E | B-E-F-G-B-A: Thorns' opening rhythm and contour "
                                 "with its second degree flattened (Phrygian), then the 'Black Sun' anthem",
                                 "relation_to_thorns": "Thorns' first two bars return almost verbatim in rhythm, a "
                                 "major third higher in E Phrygian; everything around them is louder and faster."})
    s["mix"] = v1.mix_plan(violin_1=1.0, violin_2=0.0, viola=3.5, thread_pluck=-1.0, hollow_bass=-2.5,
                           cello=["viola", 4.0], contrabass=["hollow_bass", -4.0],
                           choir_low=["violin_2", 1.5], choir_high=["violin_1", -.5], brass=["violin_1", 1.0],
                           taiko=["drums", 5.0], timpani=["drums", 1.0], toll=["thread_pluck", 5.0])
    s["patches"]["choir_low"].update(attack_seconds=.06, release_seconds=.35)
    s["patches"]["choir_high"].update(attack_seconds=.08, release_seconds=.4)
    for lane in ["viola", "cello"]:
        s["patches"][lane].update(attack_seconds=.028, release_seconds=.09)
    T = {"Em": ("Em", "E1", None, ["E3", "B3", "G3", "F3"], "Em"),
         "F": ("F (Phrygian bII)", "F1", None, ["F3", "C4", "A3", "F4"], "F"),
         "G": ("G", "G1", None, ["G3", "D4", "B3", "G4"], "G"),
         "Dm": ("Dm", "D2", None, ["D3", "A3", "F3", "D4"], "Dm"),
         "C": ("C", "C2", None, ["C3", "G3", "E3", "C4"], "C"),
         "Am": ("Am", "A1", None, ["A2", "E3", "C3", "A3"], "Am"),
         "Bb": ("Bb (tritone)", "Bb1", None, ["Bb2", "F3", "D3", "Bb3"], "Bb"),
         "B7sus": ("B7sus4", "B1", None, ["B2", "F#3", "E3", "A3"], "B"),
         "B7": ("B7(b9)", "B1", None, ["B2", "F#3", "D#3", "C4"], "B")}
    H = (["Em"] * 4 + ["Em", "Em", "F", "Em", "Em", "Em", "F", "G"]
         + ["Em", "F", "G", "F", "Em", "Dm", "C", "F"] + ["Em", "Em", "C", "C", "Am", "Bb", "B7sus", "B7"]
         + ["Em", "F", "G", "F", "Em", "Dm", "C", "F"] + ["Am", "Bb", "B7", "B7"]
         + ["Em", "F", "Em", "F", "C", "Bb", "B7", "B7"])
    seg = v1.progression(s, T, H)
    OST = {"Em": "E3 E3 F3 E3 G3 E3 F3 E3 E3 E3 F3 E3 Bb3 A3 G3 F3",
           "F": "F3 F3 G3 F3 A3 F3 G3 F3 F3 F3 G3 F3 C4 Bb3 A3 G3",
           "G": "G3 G3 A3 G3 B3 G3 A3 G3 G3 G3 A3 G3 D4 C4 B3 A3",
           "Dm": "D3 D3 E3 D3 F3 D3 E3 D3 D3 D3 E3 D3 A3 G3 F3 E3",
           "C": "C3 C3 D3 C3 E3 C3 D3 C3 C3 C3 D3 C3 G3 F3 E3 D3",
           "Am": "A3 A3 Bb3 A3 C4 A3 Bb3 A3 A3 A3 Bb3 A3 E4 D4 C4 Bb3",
           "Bb": "Bb3 Bb3 C4 Bb3 D4 Bb3 C4 Bb3 Bb3 Bb3 C4 Bb3 F4 Eb4 D4 C4",
           "B7sus": "B3 B3 C4 B3 E4 B3 C4 B3 B3 B3 C4 B3 F#4 E4 D4 C4",
           "B7": "B3 B3 C4 B3 D#4 B3 C4 B3 B3 B3 C4 B3 F#4 E4 D#4 C4"}
    accents = [12, -8, -4, 6, -8, -4, 10, -8, 8, -8, -4, 6, 4, 0, -2, -4]
    viola = [70] * 20 + [48, 50, 52, 54] + ramp(58, 74, 4) + [84] * 20
    cello = [70] * 20 + [None] * 4 + ramp(58, 74, 4) + [86] * 20
    ostinato(s, "viola", H, OST, viola, accents, .25, .2)
    ostinato(s, "cello", H, OST, cello, accents, .25, .2, shift=-12)
    bass_roots = {"Em": "E1", "F": "F1", "G": "G1", "Dm": "D2", "C": "C2", "Am": "A1", "Bb": "Bb1", "B7sus": "B1", "B7": "B1"}
    contrabass = []
    for bar, chord in enumerate(H):
        r = bass_roots[chord]
        if 20 <= bar < 24:
            contrabass.append(f"0:{r}:3.9:v50")
        else:
            v = 96 if bar >= 28 else 82
            contrabass.append(f"0:{r}:1.9:sfz:v{v} 2:{r}:1.9:sfz:v{v - 8}")
    line(s, "contrabass", contrabass, 80)
    eclipse = ["0:E5:.5 .5:B4:.35 1:G5:.5 1.5:F5:.5 2:G5:.85 3:E5:.7",
               "0:B4:.45 .5:E5:.45 1:F5:.5 1.5:G5:.5 2:B5:1.25 3.5:A5:.35",
               "0:G5:.75 1:E5:.35 1.5:D5:.5 2:C5:1 3:B4:.7",
               "0:B4:.75 1:E5:.5 1.5:F5:.5 2:E5:1.5",
               "0:E5:.5 .5:B4:.35 1:G5:.5 1.5:F5:.5 2:G5:.85 3:E5:.7",
               "0:B4:.45 .5:E5:.45 1:F5:.5 1.5:G5:.5 2:B5:1.25 3.5:C6:.35",
               "0:A5:.75 1:G5:.35 1.5:F5:.5 2:E5:.75 3:C5:.7",
               "0:B4:.75 1:D5:.5 1.5:F5:.5 2:D5:1.1 3.5:B4:.4"]
    anthem = ["0:E3:1.9 2:B3:1.9", "0:C4:2.9 3:B3:.95", "0:D4:1.9 2:G4:1.9", "0:F4:3.9",
              "0:E4:1.9 2:G4:1.4 3.5:F4:.45", "0:F4:1.9 2:D4:1.9", "0:E4:1.9 2:C4:.95 3:G3:.95", "0:C4:2.9 3:B3:.95"]
    stabs = {"Em": "E2+B2+E3", "F": "F2+C3+F3", "G": "G2+D3+G3", "C": "C2+G2+C3+E3", "Bb": "Bb1+F2+Bb2+D3"}

    def stab_bar(chord, vel, three=True, top=""):
        notes = stabs[chord] + top
        out = f"0:{notes}:.45:sfz:v{vel} 1.5:{notes}:.45:sfz:v{vel - 10}"
        return out + (f" 3:{notes}:.45:sfz:v{vel - 6}" if three else "")
    line(s, "brass", ["0:E1+E2:7.9:sw:v96", "", "0:E1+E2+B2:7.9:sw:v108", ""]
         + [stab_bar(c, 106, i % 2 == 1) for i, c in enumerate(H[4:12])], 100)
    line(s, "brass", anthem, 110, 12)
    line(s, "brass", ["0:E2:3.9", "0:F2:3.9", "0:G2:3.9", "0:F2:3.9", "0:E2:3.9", "0:D2:3.9", "0:C2:3.9", "0:F2:3.9"],
         100, 12)
    line(s, "brass", ["0:B1+F#2+B2:3.9:sw:v90", "0:B1+F#2+D#3+A3:3.9:sw:v110"], 100, 26)
    line(s, "brass", ["0:E4:1.9 2:B3:1.9", "0:G4:1.9 2:F4:1.9", "0:G4:3.9", "0:F4:1.9 2:E4:1.9",
                      "0:E4:3.9:sfz", "0:F4:1.9 2:D4:1.9", "0:E4:1.9 2:G4:1.9", "0:F4:3.9"], 118, 28)
    line(s, "brass", ["0:E2:3.9", "0:F2:3.9", "0:G2:3.9", "0:F2:3.9", "0:E2:3.9", "0:D2:3.9", "0:C2:3.9", "0:F2:3.9",
                      "0:A2+E3+C4:3.9:sw:v112", "0:Bb2+F3+D4:3.9:sw:v116", "0:B1+F#2+D#3+A3:3.9:sw:v120",
                      "0:B1+F#2+D#3+A3:3.9:sw:v124"], 112, 28)
    line(s, "brass", [stab_bar(c, 122, True, "+G3" if c == "Em" else "+A3" if c == "F" else "")
                      for c in H[40:46]] + ["0:B1+F#2+B2+D#3:7.9:sw:v124", ""], 120, 40)
    chant = {"Em": "E2+B2+E3", "F": "F2+C3+F3", "G": "G2+D3+G3", "C": "C3+G3+C4", "Bb": "Bb2+F3+Bb3"}
    line(s, "choir_low", [f"0:{chant[c]}:.5:ah:v{100 if i % 2 else 94} 1.5:{chant[c]}:.5:ah:v90"
                          + (f" 3:{chant[c]}:.5:ah:v96" if i % 2 else "") for i, c in enumerate(H[4:12])], 96, 4)
    line(s, "choir_low", ["0:E2+B2:3.9", "0:F2+C3:3.9", "0:G2+D3:3.9", "0:F2+C3:3.9", "0:E2+B2:3.9", "0:D3+A3:3.9",
                          "0:C3+G3:3.9", "0:F2+C3:3.9",
                          "0:E3+F3:7.9:oo:v56", "", "0:E3+G3:7.9:oo:v58", "",
                          "0:A2+E3:3.9:oh:v66", "0:Bb2+F3:3.9:oh:v74", "0:B2+E3:3.9:ah:v86", "0:B2+F#3:3.9:ah:v100"],
         86, 12)
    line(s, "choir_low", [f"0:{c}:3.9:ah:v118" for c in ["E2+B2+E3", "F2+C3+F3", "G2+D3+G3", "F2+C3+F3", "E2+B2+E3",
                                                         "D3+A3", "C3+G3+C4", "F2+C3+F3", "A2+E3+A3", "Bb2+F3+Bb3",
                                                         "B2+F#3+B3", "B2+F#3+A3"]], 118, 28)
    line(s, "choir_low", [f"0:{chant[c]}:.5:ah:v120 1.5:{chant[c]}:.5:ah:v112 3:{chant[c]}:.5:ah:v116"
                          for c in H[40:46]] + ["0:B2+F#3+B3:7.9:ah:v118", ""], 118, 40)
    sop = ["0:E4:1.9 2:B4:1.9", "0:C5:2.9 3:B4:.95", "0:D5:1.9 2:G5:1.9", "0:F5:3.9",
           "0:E5:1.9 2:G5:1.4 3.5:F5:.45", "0:F5:1.9 2:D5:1.9", "0:E5:1.9 2:C5:.95 3:G4:.95", "0:C5:2.9 3:B4:.95"]
    line(s, "choir_high", sop, 96, 12)
    line(s, "choir_high", ["0:B4:7.9:oo:v50", "", "0:C5:7.9:oo:v52", "", "0:C5:3.9:v64", "0:D5:3.9:v72",
                           "0:E5:3.9:v84", "0:D#5:3.9:v98"], 70, 20)
    line(s, "choir_high", sop + ["0:E5:3.9", "0:F5:3.9", "0:F#5:3.9", "0:D#5:3.9"], 118, 28)
    line(s, "choir_high", ["0:G4:3.9", "0:A4:3.9", "0:B4:3.9", "0:A4:3.9", "0:G4:3.9", "0:F4:3.9", "0:E4:3.9",
                           "0:A4:3.9", "0:C5:3.9", "0:D5:3.9", "0:B4:3.9", "0:B4:3.9"], 110, 28)
    high = {"Em": "E4+G4+B4", "F": "F4+A4+C5", "C": "E4+G4+C5", "Bb": "F4+Bb4+D5"}
    line(s, "choir_high", [f"0:{high[c]}:.5:v112 1.5:{high[c]}:.5:v104 3:{high[c]}:.5:v108" for c in H[40:46]]
         + ["0:F#4+B4+D#5:7.9:v116", ""], 112, 40)
    line(s, "violin_1", [""] * 4 + eclipse, 86)
    line(s, "violin_1", ["0:B5:3.9:tr", "0:C6:3.9:tr", "0:D6:3.9:tr", "0:C6:3.9:tr", "0:B5:3.9:tr", "0:A5:3.9:tr",
                         "0:G5:3.9:tr", "0:A5:3.9:tr", "0:E6:7.9:v44", "", "0:F6:7.9:v46", "",
                         "0:E5:3.9:tr:v60", "0:F5:3.9:tr:v68", "0:F#5:3.9:tr:v78", "0:A5:3.9:tr:v92"], 64, 12)
    climax = ["0:E5:1.9 2:B5:1.9", "0:C6:2.9 3:B5:.95", "0:D6:1.9 2:G6:1.9", "0:F6:3.9", "0:E6:1.9 2:G6:1.4 3.5:F6:.45",
              "0:F6:1.9 2:D6:1.9", "0:E6:1.9 2:C6:.95 3:G5:.95", "0:C6:2.9 3:B5:.95",
              "0:C6:1.9 2:E6:1.9", "0:D6:1.9 2:F6:1.9", "0:D#6:1.9 2:F#6:1.9", "0:B5:3.9"]
    line(s, "violin_1", climax, 104, 28)
    coda = [eclipse[0], eclipse[1], eclipse[4], eclipse[6], "0:G5:.4 1.5:G5:.4 3:E5:.4", "0:F5:.4 1.5:F5:.4 3:D5:.4",
            "0:D#6:7.9:tr:v104", ""]
    line(s, "violin_1", coda, 102, 40)
    line(s, "violin_2", shifted(eclipse, -12), 80, 4)
    line(s, "violin_2", ["0:G5:3.9:tr", "0:A5:3.9:tr", "0:B5:3.9:tr", "0:A5:3.9:tr", "0:G5:3.9:tr", "0:F5:3.9:tr",
                         "0:E5:3.9:tr", "0:F5:3.9:tr", "0:B5:7.9:v42", "", "0:C6:7.9:v44", "",
                         "0:C5:3.9:tr:v58", "0:D5:3.9:tr:v66", "0:E5:3.9:tr:v76", "0:F#5:3.9:tr:v90"], 62, 12)
    line(s, "violin_2", shifted(climax[:8], -12) + ["0:A5:1.9 2:C6:1.9", "0:Bb5:1.9 2:D6:1.9", "0:B5:1.9 2:D#6:1.9",
                                                    "0:F#5:3.9"], 98, 28)
    line(s, "violin_2", shifted(coda[:4], -12) + ["0:E5:.4 1.5:E5:.4 3:C5:.4", "0:D5:.4 1.5:D5:.4 3:Bb4:.4",
                                                  "0:B5:7.9:tr:v100", ""], 98, 40)
    line(s, "toll", ["0:E3:4:v96"] + [""] * 19 + ["0:E3:4:v70"] + [""] * 7 + ["0:E3:4:v124"], 100)
    tim = {"Em": "E2", "F": "F2", "G": "G2", "Dm": "D2", "C": "C2", "Am": "A2", "Bb": "Bb2", "B7": "B2", "B7sus": "B2"}
    timpani = ["0:E2:.5:v96", "", "0:E2:.5:v96", ""] + [f"0:{tim[c]}:.5:v90" if i % 2 == 0 or c != "Em" else ""
                                                        for i, c in enumerate(H[4:12])]
    timpani += [f"0:{tim[c]}:.5:v96" for c in H[12:20]]
    timpani += ["0:E2:.5:v56", "", "0:E2:.5:v56", "", "0:A2:.5:v70", "0:Bb2:.5:v76", "0:B2:7.9:roll:v116", ""]
    timpani += [f"0:{tim[c]}:.5:v118 2:{tim[c]}:.5:v100" for c in H[28:40]]
    timpani += [f"0:{tim[c]}:.4:v120 1.5:{tim[c]}:.4:v110 3:{tim[c]}:.4:v116" for c in H[40:46]] + ["0:B2:7.9:roll:v118", ""]
    line(s, "timpani", timpani, 100)
    drive = [(0, 35, 110), (.75, 43, 66), (1.5, 43, 80), (2, 35, 100), (2.75, 43, 66), (3, 43, 86), (3.5, 47, 72),
             (3.75, 47, 78)]
    drive_fill = drive[:5] + [(3, 43, 90), (3.25, 47, 84), (3.5, 47, 92), (3.75, 47, 100)]
    roll = [(0, 35, 112), (2, 35, 108)] + [(i * .25, 43 if i < 8 else 47, 64 + i * 3) for i in range(16)]
    big = [(0, 35, 124), (0, 43, 100), (.5, 43, 70), (.75, 47, 74), (1, 35, 96), (1.5, 43, 90), (2, 35, 120),
           (2.5, 43, 80), (2.75, 47, 80), (3, 35, 100), (3, 43, 96), (3.5, 47, 88), (3.75, 47, 96)]
    big_fill = big[:9] + [(3, 43, 98), (3.25, 47, 96), (3.5, 47, 104), (3.75, 47, 112)]
    tutti = [(0, 35, 124), (0, 43, 104), (1.5, 35, 114), (1.5, 43, 98), (3, 35, 118), (3, 43, 102)]
    hits(s, "taiko", [drive, drive, drive, drive_fill] + ([drive] * 3 + [drive_fill]) * 2
         + ([[(b, n, min(127, v + 6)) for b, n, v in drive]] * 3 + [drive_fill]) * 2
         + [[(0, 35, 64)], [(0, 35, 60)], [(0, 35, 66)], [(0, 35, 68), (2, 35, 60)],
            [(0, 35, 72), (2, 35, 66)], [(0, 35, 80), (1, 43, 60), (2, 35, 80), (3, 43, 66)],
            [(0, 35, 92), (1, 43, 70), (2, 35, 96), (2.5, 43, 74), (3, 43, 80), (3.5, 43, 86)], roll]
         + ([big] * 3 + [big_fill]) * 3 + [tutti] * 6 + [roll, roll])
    figure = [0, 1, 2, 1, 0, 1, 3, 1]
    v1.groove(s, "thread_pluck", seg, T, [[]] * 20 + [[(i * .5, .25, k, v) for i, (k, v) in
                                                        enumerate(zip(figure, [50, 38, 42, 38, 48, 38, 44, 38]))]] * 8
              + [[]] * 20)
    v1.groove(s, "hollow_bass", seg, T, [[(0, 3.8, 0, 86)]] * 20 + [[(0, 3.8, 0, 56)]] * 4
              + [[(0, 3.8, 0, v)] for v in ramp(64, 84, 4)] + [[(0, 3.8, 0, 96)]] * 20)
    s["sections"] = ["1-4: the onslaught begins - churning sixteenths in viola and cello over an E pedal, taiko, "
                     "brass swells from the depths",
                     "5-12: choir chants on the accents; violins hurl the eclipsed Thorns motif",
                     "13-20: the Black Sun anthem in low brass and choir over the ostinato (Em-F-G-F | Em-Dm-C-F)",
                     "21-28: breakdown - viola alone, whispered choir cluster, glassy harmonics, then a "
                     "rising Am-Bb-B7 build with timpani roll",
                     "29-40: climax - anthem in violins two octaves up, choir fortissimo, brass chorale on the motif, "
                     "low strings in octaves, full taiko; Am-Bb-B7 pushes higher",
                     "41-48: coda - tutti 3+3+2 hits, the motif once more, B7 roll back into the loop"]
    return finish(s)


# =================================================================== stingers

def v02_stinger(slug, title, bpm, bars, key, mood, identity, reverb):
    s = v02_score(slug, title, bpm, bars, key, mood, "stinger", identity)
    s["reverb"] = reverb
    s["patches"]["toll"]["ring_seconds"] = 2.4
    s["patches"]["timpani"]["ring_seconds"] = 1.8
    s["patches"]["taiko"]["decay_scale"] = .5
    s["patches"]["hollow_bass"].update(wet=.04)
    for patch in s["patches"].values():  # the hall alone supplies space; tempo-synced echo taps would overrun the brief
        patch["wet"] = 0.0
    return s


def level_up():
    s = v02_stinger(STINGERS[0], "Level Up (v02)", 80, 2, "D (open fifth) from B-flat: bVI to I without a third",
                    "Power earned at a cost: low strings swell on B-flat and settle onto a bare D-A fifth, with a deep "
                    "bell toll, timpani and a brass/choir bloom.",
                    {"use": "character level up", "gesture": "solemn low swell into an open fifth with a tolling bell"},
                    {"rt60_seconds": 1.3, "wet": .3})
    s["patches"]["toll"]["ring_seconds"] = 1.9
    s["patches"]["timpani"]["ring_seconds"] = 1.2
    s["mix"] = v1.mix_plan(violin_1=-1.0, violin_2=-1.0, viola=0.0, cello=["violin_1", 0.0],
                           contrabass=["hollow_bass", -3.0], brass=["violin_1", -1.0], choir_low=["violin_2", 0.0],
                           toll=["thread_pluck", 7.0], timpani=["drums", 2.0], taiko=["drums", 2.0])
    T = {"Bb": ("Bb (bVI)", "Bb1", None, [], "Bb"), "D5": ("D open fifth", "D2", None, [], "D")}
    v1.progression(s, T, ["Bb D5@1.25", "D5"])
    line(s, "contrabass", ["0:Bb1:1.2:sw:v76 1.25:D2:1.8:v100", ""], 90)
    line(s, "cello", ["0:F2:1.2:sw:v76 1.25:A2:1.8:v100", ""], 90)
    line(s, "viola", ["0:D3:1.2:sw:v70 1.25:D3:1.8:v94", ""], 90)
    line(s, "violin_2", ["0:F4:1.2:sw:v64 1.25:A4:1.8:v88", ""], 80)
    line(s, "violin_1", ["0:Bb4:1.2:sw:v66 1.25:A4:1.8:v86", ""], 80)
    line(s, "brass", ["1.25:D2+A2+D3:1.8:sw:v100", ""], 100)
    line(s, "choir_low", ["1.25:D3+A3:1.8:oh:v80", ""], 80)
    line(s, "toll", ["1.25:D4:2:v112", ""], 100)
    line(s, "timpani", ["1.25:D2:.5:v108", ""], 100)
    hits(s, "taiko", [[(0, 35, 70), (1.25, 35, 104)], []])
    s["sections"] = ["0-0.9 s: B-flat swell in the low strings over a soft taiko",
                     "0.9 s: D-A open fifth - bell toll, timpani, brass and choir bloom; the violins sink B-flat to A"]
    return finish(s)


def rare_reward():
    s = v02_stinger(STINGERS[1], "Rare Reward (v02)", 80, 2, "A minor drone colour with a raised fourth D# and a flat-ninth B-flat (unresolved)",
                    "Arcane and dangerous: glassy string harmonics shimmer over a low drone; a whispered choir adds the "
                    "flat ninth and nothing resolves.",
                    {"use": "rare/epic/legendary find", "gesture": "harmonic shimmer over a drone, unresolved b9/#11"},
                    {"rt60_seconds": 1.2, "wet": .32})
    p = s["patches"]
    for lane in ["violin_1", "violin_2"]:
        p[lane].update(vibrato_cents=1.5, bow_noise=.007, lowpass_hz=7000, attack_seconds=.04, release_seconds=.5,
                       tremolo_division=8, tremolo_depth=.35)
    p["viola"].update(vibrato_cents=2, attack_seconds=.12, release_seconds=.5)
    p["choir_high"].update(attack_seconds=.25, breath=.05)
    s["mix"] = v1.mix_plan(violin_1=1.0, violin_2=0.0, viola=-2.0, cello=["violin_2", -3.0],
                           contrabass=["hollow_bass", -4.0], choir_high=["violin_2", -1.0])
    T = {"A": ("A minor shimmer, #4 D#, b9 B-flat", "A1", None, [], "Am")}
    v1.progression(s, T, ["A", "A"])
    line(s, "contrabass", ["0:A1:2.2:v66", ""], 66)
    line(s, "cello", ["0:E2:2.2:v58", ""], 58)
    line(s, "violin_1", ["0:E6:2:tr:v62", ""], 62)
    line(s, "violin_2", ["0:C6:2:tr:v56", ""], 56)
    line(s, "viola", [".5:D#5:1.5:v54", ""], 54)
    line(s, "choir_high", [".75:Bb4:1.25:oo:v58", ""], 58)
    s["sections"] = ["0 s: glassy E6/C6 tremolo harmonics over an A-E drone",
                     "0.4-0.6 s: a raised-fourth D# and a whispered flat-ninth B-flat enter; the chord never resolves"]
    return finish(s)


def boss_defeated():
    s = v02_stinger(STINGERS[2], "Boss Defeated (v02)", 60, 3, "C minor to a C open fifth (i - bVI - V - I5, Picardy hint)",
                    "Grim triumph: a crushing C minor impact, an A-flat swell, a G-major dominant and a hard-won bare "
                    "C fifth with a faint Picardy E in the choir, then a long dark tail.",
                    {"use": "boss defeated", "gesture": "impact - bVI swell - V - open fifth with tolling bell"},
                    {"rt60_seconds": 2.0, "wet": .32})
    s["patches"]["toll"]["ring_seconds"] = 2.0
    s["mix"] = v1.mix_plan(violin_1=0.0, violin_2=-1.0, viola=0.0, cello=["violin_1", 0.0],
                           contrabass=["hollow_bass", -2.0], brass=["violin_1", 1.0], choir_low=["violin_2", 1.0],
                           choir_high=["violin_2", -6.0], toll=["thread_pluck", 6.0], timpani=["drums", 3.0],
                           taiko=["drums", 5.0])
    T = {"Cm": ("Cm", "C2", None, [], "Cm"), "Ab": ("Ab (bVI)", "Ab1", None, [], "Ab"),
         "G": ("G (V)", "G1", None, [], "G"), "C5": ("C open fifth (Picardy E in the choir)", "C2", None, [], "C")}
    v1.progression(s, T, ["Cm Ab@1.25 G@2.25 C5@3", "C5", "C5"])
    line(s, "contrabass", ["0:C2:1.2:sfz:v116 1.25:Ab1:.95:v104 2.25:G1:.7:v106 3:C2:1.75:fd:v116", "", ""], 110)
    line(s, "cello", ["0:G2:1.2:sfz:v112 1.25:Ab2:.95:v100 2.25:G2:.7:v104 3:C3:1.75:fd:v112", "", ""], 110)
    line(s, "viola", ["0:Eb3:1.2:sfz:v104 1.25:Eb3:.95:v96 2.25:D3:.7:v100 3:G3:1.75:fd:v106", "", ""], 104)
    line(s, "violin_2", ["0:G4:1.2:sfz:v100 1.25:C5:.95:v94 2.25:B4:.7:v98 3:C5:1.75:fd:v104", "", ""], 100)
    line(s, "violin_1", ["0:Eb5:1.2:sfz:v104 1.25:Eb5:.95:v96 2.25:D5:.7:v100 3:C5:1.75:fd:v108", "", ""], 104)
    line(s, "brass", ["0:C2+G2+C3+Eb3:1.2:sfz:v124 1.25:Ab2+Eb3+C4:.95:sw:v112 2.25:G2+D3+B3:.7:sw:v118 "
                      "3:C2+G2+C3+G3:1.75:sfz:v124", "", ""], 120)
    line(s, "choir_low", ["0:C3+G3:1.2:ah:v112 1.25:Ab2+Eb3:.95:ah:v104 2.25:G2+D3:.7:ah:v108 "
                          "3:C3+G3:1.75:oh:v112", "", ""], 110)
    line(s, "choir_high", ["3:E4:1.75:oo:v70", "", ""], 70)
    line(s, "toll", ["0:C4:2:v120 3:C4:2:v104", "", ""], 110)
    line(s, "timpani", ["0:C2:.5:v126 2.25:G2:.5:v104 3:C2:.5:v118", "", ""], 110)
    hits(s, "taiko", [[(0, 35, 127), (0, 43, 116), (2.25, 43, 92), (3, 35, 118), (3, 43, 100)], [], []])
    s["sections"] = ["0 s: C minor impact - taiko, timpani, brass sforzando, full strings, choir, bell",
                     "1.25 s: A-flat swell; 2.25 s: G major dominant",
                     "3 s: bare C fifth with a faint Picardy E, second bell toll, long dark tail"]
    return finish(s)


BUILDERS = {THEMES[0]: noctyrax_a, THEMES[1]: noctyrax_b,
            STINGERS[0]: level_up, STINGERS[1]: rare_reward, STINGERS[2]: boss_defeated}


def compositions(only=None):
    return [BUILDERS[slug]() for slug in SLUGS if not only or slug in only]
