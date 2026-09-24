#!/usr/bin/env python3
"""Three new combat scores using the reviewed dark-fantasy audition renderer."""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "project.godot").exists())
CASE = Path(__file__).resolve().parents[1]
PREVIOUS = ROOT / "output/original_soundtracks/umbra_three_sketches"
sys.path.insert(0, str(PREVIOUS / "scripts"))
import build_v02 as engine  # noqa: E402
import mido  # noqa: E402
import numpy as np  # noqa: E402

v01 = engine.v01
SLUGS = ["01_iron_procession", "02_thorns_in_the_dark", "03_the_hollow_gate"]


def score(slug, title, bpm, bars, key, mood, lead, bell=False):
    patches = copy.deepcopy(v01.PATCHES)
    patches.pop("reed")
    if not bell:
        patches.pop("lantern_mallet")
        patches["answer_viol"] = {"gain": .115, "pan": -.25, "wet": .28, "program": 41,
            "bank_id": "hollow_viola", "legato": True, "lowpass_hz": 1200,
            "attack_seconds": .09, "release_seconds": .25, "vibrato_cents": 2.5}
    else:
        patches["lantern_mallet"].update({"gain": .125, "pan": -.22, "wet": .34, "lowpass_hz": 850})
    patches[lead] = {"gain": .28, "pan": .08, "wet": .25, "program": 42,
        "bank_id": "grave_cello", "legato": True, "lowpass_hz": 1250,
        "attack_seconds": .060, "release_seconds": .18, "vibrato_cents": 3.2}
    patches["bowed_veil"].update({"gain": .065, "wet": .30, "lowpass_hz": 1600})
    patches["thread_pluck"].update({"gain": .085, "wet": .23, "lowpass_hz": 1150})
    patches["hollow_bass"]["gain"] = .23
    patches["drums"].update({"gain": .28, "wet": .09, "lowpass_hz": 1300})
    return {"schema_version": 1, "version": "v01", "slug": slug, "title": title,
        "bpm": bpm, "bars": bars, "beats_per_bar": 4, "key": key, "mood": mood,
        "source_kind": "original_authored_symbolic_composition", "lead_instrument": lead,
        "patches": patches, "notes": [], "harmony": [], "sections": [],
        "articulation": "Explicit sustained and detached note gates, purposeful rests, and accompaniment continuity."}


def melody(s, part, bars, velocity=78, start_bar=0):
    """Each token is beat:pitch:duration; no automatic gate extension is applied."""
    for bar, line in enumerate(bars, start_bar):
        for i, token in enumerate(line.split()):
            beat, pitch, duration = token.split(":")
            v01.add(s, part, bar, float(beat), float(duration), pitch, velocity - i % 3 * 3)


def replies(s, entries, part="answer_viol", velocity=58):
    for bar, line in entries.items():
        melody(s, part, [line], velocity, bar)


def accompaniment(s, chords, style, thin_bars=()):
    for bar, (label, root, inner, arp) in enumerate(chords):
        s["harmony"].append({"bar": bar + 1, "chord": label})
        if bar == 0 or chords[bar - 1] != chords[bar]:
            span = 1
            while bar + span < len(chords) and chords[bar + span] == chords[bar]:
                span += 1
            for pitch in inner:
                v01.add(s, "bowed_veil", bar, 0, span * 4 - .10, pitch, 59)
        thin = bar in thin_bars
        if style == "march":
            bass = [(0, 1.6, 0, 79), (2, 1.5, 7, 70)]
            plucks = [(0.5, 0), (2.5, 1)] if thin else [(0.5, 0), (1.5, 1), (2.5, 2), (3.5, 1)]
            drums = [(0, 36, 76), (2, 36, 68), (3.25, 41, 52)]
        elif style == "urgent":
            bass = [(0, .85, 0, 74), (1, .8, 7, 63), (2, .85, 0, 72), (3, .7, 7, 61)]
            plucks = [(t / 2, i) for t, i in enumerate([0, 1, 2, 1, 0, 1, 3, 1])]
            drums = [(0, 36, 72), (1.5, 41, 49), (2, 36, 66), (3.5, 41, 54)]
        else:
            bass = [(0, 1.4, 0, 82), (1.5, .36, 0, 53), (2, 1.4, 7, 69), (3.5, .36, 0, 55)]
            plucks = [(0.75, 0), (2.75, 1)]
            drums = [(0, 36, 81), (1.5, 41, 53), (2.5, 36, 65), (3.5, 41, 49)]
        if thin:
            bass = [(0, 1.75, 0, 66), (2, 1.75, 7, 58)]
            plucks = plucks[::2]
            drums = [(0, 36, 58), (2, 41, 42)]
        for beat, dur, interval, vel in bass:
            v01.add(s, "hollow_bass", bar, beat, dur, v01.pitch(root) + interval, vel)
        for i, (beat, index) in enumerate(plucks):
            v01.add(s, "thread_pluck", bar, beat, .25 if style == "urgent" else .36,
                    arp[index], 45 if thin else 57 - i % 2 * 7)
        for beat, note, vel in drums:
            # Short tom gates leave room for the phrase-end pickup on the same MIDI pitch.
            v01.add(s, "drums", bar, beat, .20 if note == 41 else .28, note, vel)
        if bar % 4 == 3 and not thin:
            v01.add(s, "drums", bar, 3.75, .20, 41, 45)


def iron_procession():
    s = score(SLUGS[0], "Iron Procession", 88, 20, "G minor",
              "Measured war march: low strings, deliberate steps, and a rising tragic refrain.", "grave_lead")
    G = ("Gm", "G1", ["Bb3", "D4"], ["G3", "D3", "Bb3", "A3"])
    E = ("Ebmaj7", "Eb2", ["Bb3", "D4"], ["Eb3", "Bb3", "G3", "D4"])
    C = ("Cm7", "C2", ["G3", "Bb3"], ["C3", "G3", "Eb3", "Bb3"])
    A = ("Abmaj7", "Ab1", ["G3", "C4"], ["Ab3", "Eb3", "C4", "G3"])
    D = ("D7", "D2", ["F#3", "C4"], ["D3", "A3", "F#3", "C4"])
    DS = ("D7sus4", "D2", ["G3", "C4"], ["D3", "A3", "G3", "C4"])
    accompaniment(s, [G,G,E,D, G,C,E,D, C,C,A,D, G,E,C,D, G,E,DS,D], "march", [8,9])
    melody(s, "grave_lead", [
        "0:G3:1.25 1.5:Bb3:.45 2:A3:.75 3:G3:.75",
        "0:D4:1.5 1.5:C4:.75 2.5:Bb3:1.25",
        "0:G3:.7 1:Bb3:.7 2:D4:1.5 3.5:C4:.4",
        "0:A3:1.4 1.5:F#3:.4 2:D3:1.25",
        "0:G3:1.25 1.5:Bb3:.45 2:D4:.75 3:Eb4:.75",
        "0:Eb4:1 1:D4:.65 2:C4:1.25 3.5:G3:.4",
        "0:Bb3:1 1:D4:.7 2:Eb4:1.5 3.5:D4:.4",
        "0:C4:.8 1:A3:.75 2:F#3:1.4",
        "0:G3:1 1:C4:.75 2:Eb4:1.25 3.5:D4:.4",
        "0:C4:1.75 2:G3:.75 3:Bb3:.75",
        "0:C4:1 1:Bb3:.65 2:Ab3:1 3:G3:.75",
        "0:F#3:.75 1:A3:.75 2:C4:1 3:A3:.4",
        "0:G3:1.25 1.5:Bb3:.45 2:A3:.75 3:G3:.75",
        "0:Bb3:1.5 1.5:D4:1 2.5:Eb4:1.25",
        "0:D4:1 1:Eb4:.7 2:C4:1.5",
        "0:A3:1.25 1.5:G3:.7 2.5:F#3:.9",
        "0:D4:1.5 1.5:Bb3:.7 2.5:G3:1.25",
        "0:G3:.7 1:Bb3:.7 2:D4:1.6",
        "0:A3:1.25 1.5:G3:.7 2.5:D3:1.25",
        "0:F#3:1.25 1.5:A3:.7 2.5:D3:.75",
    ], 80)
    replies(s, {3: "3:C4:.9", 7: "3.25:A3:.7", 11: "3.25:F#3:.7",
                15: "3.25:C4:.7", 19: "3.25:F#3:.65"})
    s["sections"] = ["1-4: march statement", "5-8: rising answer", "9-12: minor-subdominant/Neapolitan turn",
                     "13-16: stronger return", "17-20: compressed refrain and dominant pickup"]
    return s


def thorns():
    s = score(SLUGS[1], "Thorns in the Dark", 116, 24, "C minor",
              "Urgent pursuit: a close minor-key viol line over a repeating low pluck figure.", "shadow_lead")
    s["patches"]["shadow_lead"].update({"bank_id": "hollow_viola", "program": 41,
        "gain": .255, "lowpass_hz": 1250, "attack_seconds": .04, "release_seconds": .13})
    s["patches"]["answer_viol"].update({"bank_id": "grave_cello", "program": 42, "gain": .125})
    s["patches"]["thread_pluck"].update({"gain": .105, "lowpass_hz": 1050})
    s["patches"]["drums"].update({"gain": .25, "lowpass_hz": 1200})
    C = ("Cm(add9)", "C2", ["Eb3", "G3"], ["C3", "G3", "D4", "Eb3"])
    A = ("Abmaj7", "Ab1", ["C3", "G3"], ["Ab2", "Eb3", "G3", "C4"])
    F = ("Fm9", "F2", ["Ab3", "C4"], ["F3", "C4", "G3", "Ab3"])
    D = ("Dbmaj7", "Db2", ["F3", "C4"], ["Db3", "Ab3", "C4", "F3"])
    G = ("G7", "G1", ["B3", "F4"], ["G3", "D4", "F3", "B3"])
    GS = ("G7sus4", "G1", ["C4", "F4"], ["G3", "D4", "F3", "C4"])
    accompaniment(s, [C,C,A,G, C,F,D,G, F,F,D,G, A,F,GS,G, C,C,A,G, F,D,GS,G], "urgent", [8,9,10,11])
    melody(s, "shadow_lead", [
        "0:C4:.5 .5:G3:.35 1:Eb4:.5 1.5:D4:.5 2:Eb4:.85 3:C4:.7",
        "0:G3:.45 .5:C4:.45 1:D4:.5 1.5:Eb4:.5 2:G4:1.25 3.5:F4:.35",
        "0:Eb4:.75 1:C4:.35 1.5:Bb3:.5 2:Ab3:1 3:G3:.7",
        "0:B3:.75 1:D4:.5 1.5:F4:.5 2:Eb4:.5 2.5:D4:.65",
        "0:C4:.5 .5:G3:.35 1:Eb4:.5 1.5:D4:.5 2:C4:.85 3:G3:.7",
        "0:Ab3:.5 .5:C4:.35 1:Eb4:.5 1.5:F4:.5 2:Eb4:.85 3:C4:.7",
        "0:F4:.75 1:Eb4:.35 1.5:Db4:.5 2:C4:.75 3:Ab3:.7",
        "0:B3:.75 1:D4:.5 1.5:F4:.5 2:D4:1.1",
        "0:C4:1.75 2:Ab3:1.5",
        "0:G3:.75 1:Ab3:.75 2:C4:1.6",
        "0:F4:1.5 1.5:Eb4:.7 2.5:Db4:1.1",
        "0:D4:1.25 1.5:B3:.65 2.5:G3:.7",
        "0:C4:.75 1:Eb4:.5 1.5:G4:.5 2:Eb4:1 3:C4:.7",
        "0:Ab3:.5 .5:C4:.35 1:Eb4:.5 1.5:F4:.5 2:G4:.85 3:F4:.7",
        "0:F4:.75 1:D4:.35 1.5:C4:.5 2:A3:.75 3:G3:.7",
        "0:B3:.75 1:D4:.5 1.5:F4:.5 2:D4:.65 3:B3:.35",
        "0:C4:.5 .5:G3:.35 1:Eb4:.5 1.5:D4:.5 2:Eb4:.85 3:C4:.7",
        "0:G3:.45 .5:C4:.45 1:D4:.5 1.5:Eb4:.5 2:G4:1.25 3.5:F4:.35",
        "0:Eb4:.75 1:C4:.35 1.5:Bb3:.5 2:Ab3:1 3:G3:.7",
        "0:B3:.75 1:D4:.5 1.5:F4:.5 2:Eb4:.5 2.5:D4:.65",
        "0:C4:.75 1:Ab3:.35 1.5:G3:.5 2:F3:1 3:Ab3:.7",
        "0:Ab3:.5 .5:Db4:.35 1:F4:.5 1.5:Eb4:.5 2:Db4:.85 3:C4:.7",
        "0:D4:.75 1:F4:.35 1.5:D4:.5 2:C4:1 3:A3:.7",
        "0:B3:.75 1:D4:.65 2:G3:1.1",
    ], 77)
    replies(s, {3: "3.1:B3:.85", 7: "3.1:G3:.85", 11: "3.1:B3:.85",
                15: "3.35:G3:.6", 19: "3.1:B3:.85", 23: "3.1:B3:.85"}, velocity=60)
    s["sections"] = ["1-8: urgent question and altered reply", "9-12: longer melodic arcs over a thinner pulse",
                     "13-16: rising pressure", "17-24: varied return and short lower cadence"]
    return s


def hollow_gate():
    s = score(SLUGS[2], "The Hollow Gate", 72, 16, "B minor with Phrygian color",
              "Ominous siege: a low cello motif, distant stone-like mallets, and heavy paired drum strokes.", "grave_lead", bell=True)
    s["patches"]["grave_lead"].update({"lowpass_hz": 1100, "attack_seconds": .085,
        "release_seconds": .24, "wet": .31})
    s["patches"]["thread_pluck"].update({"gain": .060, "lowpass_hz": 950})
    s["patches"]["drums"].update({"gain": .30, "wet": .15, "lowpass_hz": 1100})
    B = ("Bm", "B1", ["D3", "F#3"], ["B2", "F#3", "D3", "A3"])
    C = ("Cmaj7(#11)", "C2", ["E3", "B3"], ["C3", "G3", "F#3", "B3"])
    E = ("Em", "E2", ["G3", "B3"], ["E3", "B3", "G3", "F#3"])
    G = ("Gmaj7", "G1", ["B3", "F#4"], ["G3", "D3", "B3", "F#3"])
    FS = ("F#7sus4", "F#1", ["B3", "E4"], ["F#3", "C#4", "B3", "E3"])
    F = ("F#7", "F#1", ["A#3", "E4"], ["F#3", "C#4", "A#3", "E3"])
    accompaniment(s, [B,B,C,C, E,E,FS,F, B,G,C,E, G,C,FS,F], "siege", [8,9])
    melody(s, "grave_lead", [
        "0:B2:.8 1:D3:.5 2:F#3:1.75",
        "0:A3:1.5 1.5:F#3:.75 2.5:E3:1.1",
        "0:G3:1 1:E3:1 2.25:C3:1.5",
        "0:B2:1.5 2:E3:.7 3:G3:.45",
        "0:B3:1.7 2:G3:.8 3:E3:.7",
        "0:F#3:1 1:G3:.6 2:E3:1.75",
        "0:C#3:.7 1:F#3:1 2:B3:1.2 3.5:A3:.35",
        "0:A#3:1 1:G#3:.5 2:F#3:1.25",
        "0:B2:.8 1:D3:.5 2:F#3:1 3:A3:.7",
        "0:B3:1 1:A3:.75 2:G3:1 3:F#3:.7",
        "0:G3:1 1:E3:.75 2:D3:.8 3:C3:.7",
        "0:E3:.75 1:G3:.7 2:F#3:.8 3:E3:.45",
        "0:D3:.7 1:F#3:.75 2:B3:1.75",
        "0:E3:.7 1:G3:.75 2:B3:1 3:A3:.7",
        "0:B3:1 1:A3:.75 2:F#3:1 3:C#3:.7",
        "0:A#2:.75 1:C#3:.75 2:F#3:1.1",
    ], 80)
    replies(s, {3: "3.25:E4:.6", 7: "3.1:C#4:.8", 11: "3.25:B3:.6", 15: "3.1:C#4:.8"},
            part="lantern_mallet", velocity=57)
    s["sections"] = ["1-4: low warning motif and semitone shadow", "5-8: climb into suspended dominant",
                     "9-12: thinner reprise", "13-16: fuller threat and return pickup"]
    return s


def compositions():
    result = [iron_procession(), thorns(), hollow_gate()]
    for s in result:
        s["notes"].sort(key=lambda n: (n["beat"], n["instrument"], n["pitch"]))
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output-dir", type=Path, default=CASE / "versions/v01")
    args = ap.parse_args()
    output = args.output_dir.resolve()
    if output.exists():
        raise SystemExit(f"Refusing to replace an audition directory: {output}. Use a fresh directory.")
    samples, waves = engine.load_bank()
    inputs = [Path(__file__), CASE / "scripts/verify_combat.py", CASE / "README.md", CASE / "PROVENANCE.md",
              CASE / "requirements.txt", PREVIOUS / "scripts/build.py", PREVIOUS / "scripts/build_v02.py",
              PREVIOUS / "scripts/verify.py", engine.BANK / "bank_manifest.json",
              *(engine.BANK / sample["path"] for sample in samples.values()),
              *(ROOT / "tools/classical_soundtrack_pipeline" / f for f in ["common.py", "render.py", "verify.py"])]
    output.mkdir(parents=True)
    v01.write_json(output / "SOURCES.json", {"source_kind": "original_authored_symbolic_composition",
        "version": "v01", "approval_status": "awaiting_user_audition",
        "renderer": "unchanged umbra_three_sketches/scripts/build_v02.py",
        "inputs_sha256": {str(p.relative_to(ROOT)): v01.sha256(p) for p in inputs},
        "python_version": sys.version.split()[0], "numpy_version": np.__version__,
        "mido_version": str(mido.version_info),
        "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]})
    for s in compositions():
        folder = output / s["slug"]
        folder.mkdir()
        v01.write_json(folder / "score.json", s)
        engine.midi(s, folder / "arrangement.mid")
        report = engine.render(s, folder, samples, waves)
        report.update({"version": "v01", "renderer_version": "umbra_three_sketches_v02",
                       "lead_articulation": s["articulation"]})
        report["artifacts_sha256"] = {p.name: v01.sha256(p) for p in sorted(folder.iterdir())}
        v01.write_json(folder / "render.json", report)
        print(f"{s['title']}: {report['duration_seconds']:.2f}s rendered", flush=True)
    print(output, flush=True)


if __name__ == "__main__":
    main()
