#!/usr/bin/env python3
"""Dragon themes v02: Noctyrax takes A/B and three dark stingers, rendered into versions/v02.

Builds on the v01 renderer by import (scripts/build.py is loaded read-only under another
module name). v01 sources and outputs are never modified, so a fresh v01 rebuild stays
byte-identical. New here: formant choir, brass, taiko, timpani and bell voices, string
dynamic shapes (swell/sforzando/fade), a circular hall send for loops, and a MIDI writer
that keeps percussion on channel 10.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np

HERE = Path(__file__).resolve().parent
SHARED = HERE.parent
sys.path.insert(0, str(SHARED))
import scores_dragons_v02 as scores  # noqa: E402
import instruments_dragons_v02 as instruments  # noqa: E402
import dragon_audio as audio  # noqa: E402


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


v1build = load_module("dragon_build_v01", SHARED / "build.py")
v1, v01 = scores.v1, scores.v01
thorns, engine, bowed, checks = v1build.thorns, v1build.engine, v1build.bowed, v1build.checks
import mido  # noqa: E402

RATE, ROOT, CASE = v01.RATE, v1.ROOT, SHARED.parent
LOOP_LUFS, LOOP_PEAK_LIMIT = -20.0, -1.5
SALT = "dragon-themes-and-stingers-v02"
GM_PERCUSSION_CHANNEL = 9


def frames_of(s):
    return round(s["bars"] * 240 / s["bpm"] * RATE)


def circular_add_stereo(stem, signal, start):
    cursor = 0
    while cursor < len(signal):
        dest = (start + cursor) % len(stem)
        count = min(len(signal) - cursor, len(stem) - dest)
        stem[dest:dest + count] += signal[cursor:cursor + count]
        cursor += count


def shape_envelope(notes, bpm, length):
    """Swell / sforzando / fade dynamics across a bowed phrase, smoothed to avoid steps."""
    env = np.ones(length)
    beat = 60 / bpm
    for index, n in enumerate(notes):
        shape = n.get("shape")
        if not shape:
            continue
        a = round((n["beat"] - notes[0]["beat"]) * beat * RATE)
        b = min(length, round((n["beat"] + n["duration"] - notes[0]["beat"]) * beat * RATE))
        x = np.linspace(0, 1, b - a)
        seconds = x * (b - a) / RATE
        if shape == "swell":
            curve = .3 + .7 * x ** 1.4
        elif shape == "sfz":
            curve = np.where(seconds < .3, 1 - .55 * np.sin(np.minimum(seconds / .3, 1) * np.pi / 2), .45 + .35 * x)
        else:
            curve = 1 - .8 * x
        env[a:b] *= curve
        if index == len(notes) - 1:
            env[b:] *= curve[-1]
    width = round(.01 * RATE)
    return np.convolve(np.pad(env, width, mode="edge"), np.ones(width) / width, mode="same")[width:-width]


def string_stem(s, name):
    patch = s["patches"][name]
    stem = np.zeros((frames_of(s), 2))
    groups = []
    for n in (n for n in s["notes"] if n["instrument"] == name):
        if not groups or n["beat"] > groups[-1][-1]["beat"] + groups[-1][-1]["duration"] + 1e-5:
            groups.append([])
        groups[-1].append(n)
    for notes in groups:
        wave = bowed.phrase(notes, s["bpm"], patch)
        if any(n.get("articulation") == "tremolo" for n in notes):
            wave = wave * v1build.tremolo_envelope(notes, s["bpm"], patch, len(wave))
        if any(n.get("shape") for n in notes):
            wave = wave * shape_envelope(notes, s["bpm"], len(wave))
        v01.circular_add(stem, wave, round(notes[0]["beat"] * 60 / s["bpm"] * RATE), patch["pan"])
    return engine.circular_lowpass(stem, patch["lowpass_hz"])


def synth_stem(s, name):
    patch = s["patches"][name]
    stem = np.zeros((frames_of(s), 2))
    voice = instruments.SYNTHS[patch["synth"]]
    for n in (n for n in s["notes"] if n["instrument"] == name):
        circular_add_stereo(stem, voice(n, s["bpm"], patch), round(n["beat"] * 60 / s["bpm"] * RATE))
    return engine.circular_lowpass(stem, patch["lowpass_hz"]) if patch.get("lowpass_hz") else stem


def lane_stem(s, name, samples, waves):
    patch = s["patches"][name]
    if "synth" in patch:
        return synth_stem(s, name)
    if "voice" in patch:
        return string_stem(s, name)
    return engine.make_stem(s, name, samples, waves)


def calibrated_stems(s, samples, waves, template, wav):
    wet, sends, gains, targets = {}, {}, {}, {}
    for name in sorted({n["instrument"] for n in s["notes"]}):
        patch = s["patches"][name]
        stem = lane_stem(s, name, samples, waves)
        stem = stem * min(1.0, .5 / max(np.max(np.abs(stem)), 1e-9))
        reference, offset = s["mix"][name]
        targets[name] = template[reference] + offset
        gains[name] = 10 ** ((targets[name] - thorns.measured(stem, wav)) / 20)
        dry = stem * gains[name]
        wet[name] = v01.circular_dark_echo(dry, patch["wet"], 60 / s["bpm"])
        sends[name] = dry * patch.get("hall", 0.0)
    return wet, sends, gains, targets


def hall_ir(rt60, seed):
    """The v01 stinger hall impulse response (seeded decaying noise, linear-filtered), exposed for loops."""
    length = round(min(3.0, rt60 * 1.3) * RATE)
    t = np.arange(length) / RATE
    ir = np.random.default_rng(seed).normal(size=(length, 2)) * np.exp(-6.9078 * t / rt60)[:, None]
    freqs = np.fft.rfftfreq(2 * length, 1 / RATE)
    tone = 1 / np.sqrt(1 + (freqs / 3800) ** 4) * (1 - np.exp(-(freqs / 180) ** 2))
    ir = np.fft.irfft(np.fft.rfft(ir, n=2 * length, axis=0) * tone[:, None], n=2 * length, axis=0)[:length]
    ir[:round(.012 * RATE)] = 0
    ir[-round(.05 * RATE):] *= np.cos(np.linspace(0, np.pi / 2, round(.05 * RATE)))[:, None] ** 2
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


def circular_hall(signal, rt60, seed):
    ir = hall_ir(rt60, seed)
    return np.fft.irfft(np.fft.rfft(signal, axis=0) * np.fft.rfft(ir, n=len(signal), axis=0), n=len(signal), axis=0)


def render_theme(s, folder, samples, waves, template):
    with tempfile.TemporaryDirectory(prefix="umbra-dragon-v02-") as td:
        wav = Path(td) / "measure.wav"
        wet, sends, gains, targets = calibrated_stems(s, samples, waves, template, wav)
        seed = int(hashlib.sha256((s["slug"] + "hall").encode()).hexdigest()[:8], 16)
        hall = circular_hall(sum(sends[n] for n in sorted(sends)), s["reverb"]["rt60_seconds"], seed)
        hall *= s["reverb"]["return"]
        mix = sum(wet[n] for n in sorted(wet)) + hall
        scale = .5 / np.max(np.abs(mix))
        master = scale * 10 ** ((LOOP_LUFS - thorns.measured(mix * scale, wav)) / 20)
        mix = mix * master
        adjacent = np.percentile(np.abs(np.diff(mix, axis=0)), 99.9, axis=0)
        wrap = np.abs(mix[0] - mix[-1])
        fade = round(.002 * RATE)
        boundary = np.ones(len(mix))
        boundary[:fade] = np.sin(np.linspace(0, np.pi / 2, fade)) ** 2
        boundary[-fade:] = boundary[:fade][::-1]
        mix *= boundary[:, None]
        peak = audio.db(np.max(np.abs(mix)))
        if peak > LOOP_PEAK_LIMIT:
            raise ValueError(f"{s['slug']}: peak {peak:.2f} dBFS; revise the mix rather than limiting")
        v01.write_stereo_wave(wav, mix, RATE)
        v1build.encode(wav, folder, s["slug"] + SALT)
        stems = {"calibration_gain": gains, "target_pre_master_lufs": targets,
                 "lufs_in_matched_mix": {n: round(thorns.measured(w * master, wav), 2) for n, w in wet.items()},
                 "hall_return_lufs_in_mix": round(thorns.measured(hall * master, wav), 2),
                 "post_master_peak_dbfs": {n: round(audio.db(np.max(np.abs(w * master))), 2) for n, w in wet.items()}}
    return {"master_gain": master, "pre_master_sample_peak_dbfs": peak, "stems": stems, "reverb": s["reverb"],
            "circular_continuity_before_taper": {"wrap_sample_delta": wrap.tolist(),
                                                 "p99_9_adjacent_delta": adjacent.tolist(),
                                                 "ratio": (wrap / adjacent).tolist()},
            "loop_method": "periodic overlap-add of every release/ring tail, circular echo, filters and hall "
                           "convolution, exact bar length, 2 ms endpoint taper (Thorns v02 convention)"}


def render_stinger(s, folder, samples, waves, template):
    """v01 stinger mastering (linear render, hall tail, -54 dB trim, -18 LUFS, -3 dBFS ceiling) with v02 voices."""
    with tempfile.TemporaryDirectory(prefix="umbra-dragon-v02-stinger-") as td:
        wav = Path(td) / "measure.wav"
        wet, sends, gains, targets = calibrated_stems(s, samples, waves, template, wav)
        dry = sum(wet[name] for name in sorted(wet))
        guard = round(.1 * RATE)
        canvas_tail = audio.db(np.max(np.abs(dry[-guard:]))) - audio.db(np.max(np.abs(dry)))
        if canvas_tail > -45:
            raise ValueError(f"{s['slug']}: canvas too short for its tail ({canvas_tail:.1f} dB)")
        dry[-guard:] = 0
        seed = int(hashlib.sha256((s["slug"] + SALT).encode()).hexdigest()[:8], 16)
        mix = v1build.hall(dry, s["reverb"]["rt60_seconds"], s["reverb"]["wet"], seed)
        level = np.abs(mix).max(axis=1)
        end = int(np.nonzero(level > np.max(level) * 10 ** (-54 / 20))[0][-1]) + round(.05 * RATE)
        mix = mix[:end]
        fade_in, fade_out = round(.003 * RATE), round(.35 * RATE)
        mix[:fade_in] *= np.sin(np.linspace(0, np.pi / 2, fade_in))[:, None] ** 2
        mix[-fade_out:] *= np.cos(np.linspace(0, np.pi / 2, fade_out))[:, None] ** 2
        pre_gain = 1 / (np.max(np.abs(mix)) * 1.2)
        v01.write_stereo_wave(wav, mix * pre_gain, RATE)
        loud_gain = pre_gain * 10 ** ((v1build.STINGER_LUFS - audio.ebur128(wav)["integrated_lufs"]) / 20)
        ceiling_gain = 10 ** (v1build.STINGER_PEAK_CEILING / 20) / np.max(np.abs(mix))
        gain = min(loud_gain, ceiling_gain)
        mix *= gain
        v01.write_stereo_wave(wav, mix, RATE)
        v1build.encode(wav, folder, s["slug"] + SALT)
        return {"master_gain": float(gain), "limited_by": "peak ceiling" if ceiling_gain < loud_gain else "loudness target",
                "target_integrated_lufs": v1build.STINGER_LUFS,
                "sample_peak_ceiling_dbfs": v1build.STINGER_PEAK_CEILING, "reverb": s["reverb"],
                "canvas_final_100ms_rel_peak_db": canvas_tail,
                "stems": {"calibration_gain": gains, "target_pre_master_lufs": targets,
                          "post_master_peak_dbfs": {n: round(audio.db(np.max(np.abs(w * gain))), 2) for n, w in wet.items()}},
                "tail_method": "v01 method: linear render, synthetic hall tail, trimmed 50 ms after falling 54 dB "
                               "below peak, 3 ms fade-in, 350 ms cosine fade over the already-quiet end"}


def midi(s, path):
    """Type-1 MIDI; percussion lanes on channel 10, melodic lanes on the other fifteen channels."""
    result = mido.MidiFile(type=1, ticks_per_beat=480)
    end = s["bars"] * 4 * 480
    result.tracks.append(mido.MidiTrack([mido.MetaMessage("track_name", name=s["title"]),
        mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(s["bpm"])),
        mido.MetaMessage("time_signature", numerator=4, denominator=4), mido.MetaMessage("end_of_track", time=end)]))
    melodic = iter(c for c in range(16) if c != GM_PERCUSSION_CHANNEL)
    for instrument in sorted({n["instrument"] for n in s["notes"]}):
        patch = s["patches"][instrument]
        channel = GM_PERCUSSION_CHANNEL if instrument == "drums" or patch.get("percussion") else next(melodic)
        track = mido.MidiTrack([mido.MetaMessage("track_name", name=instrument),
                                mido.Message("program_change", channel=channel, program=patch["program"])])
        events = []
        for n in s["notes"]:
            if n["instrument"] == instrument:
                events.extend([(round(n["beat"] * 480), 1, n), (round((n["beat"] + n["duration"]) * 480), 0, n)])
        previous = 0
        for tick, on, n in sorted(events, key=lambda e: (e[0], e[1], e[2]["pitch"])):
            track.append(mido.Message("note_on" if on else "note_off", channel=channel, note=n["pitch"],
                                      velocity=n["velocity"] if on else 0, time=tick - previous))
            previous = tick
        track.append(mido.MetaMessage("end_of_track", time=end - previous))
        result.tracks.append(track)
    result.save(path)


def source_paths(samples):
    paths = v1build.source_paths(samples)
    paths += sorted(HERE.glob("*.py"))
    paths += [CASE / p for p in ["V02_NOTES.md", "V02_PROVENANCE.md"]]
    return sorted(set(paths))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=CASE / "versions/v02")
    parser.add_argument("--only", nargs="*", help="development subset (the verifier requires the full set)")
    args = parser.parse_args()
    destination = args.output_dir.resolve()
    if destination.exists():
        raise SystemExit(f"Refusing to replace an audition directory: {destination}")
    samples, waves = engine.load_bank()
    template = v1build.load_template(samples, waves)
    inputs = {str(p.relative_to(ROOT)): v01.sha256(p) for p in source_paths(samples)}
    destination.mkdir(parents=True)
    outputs = {}
    for s in scores.compositions(args.only):
        folder = destination / s["slug"]
        folder.mkdir()
        v01.write_json(folder / "score.json", s)
        midi(s, folder / "arrangement.mid")
        render = (render_theme if s["kind"] == "loop_theme" else render_stinger)(s, folder, samples, waves, template)
        render.update({"version": "v02", "title": s["title"], "kind": s["kind"], "key": s["key"], "bpm": s["bpm"],
                       "bars": s["bars"], "sample_rate": RATE, "channels": 2,
                       "note_counts": dict(Counter(n["instrument"] for n in s["notes"])),
                       "thorns_v02_stem_template_lufs": template, "decoded": v1build.decoded_report(s, folder)})
        if s["kind"] == "loop_theme":
            render["loop_duration_seconds"] = s["bars"] * 240 / s["bpm"]
            render["section_loudness"] = audio.section_loudness(folder / "preview.flac", s)
        render["artifacts_sha256"] = {p.name: v01.sha256(p) for p in sorted(folder.iterdir())}
        v01.write_json(folder / "render.json", render)
        outputs.update({f"{s['slug']}/{p.name}": v01.sha256(p) for p in sorted(folder.iterdir())})
        flac = render["decoded"]["flac"]
        print(f"{s['title']}: {flac['duration_seconds']:.2f}s, {flac['integrated_lufs']:.2f} LUFS, "
              f"sample peak {flac['sample_peak_dbfs']:.2f} dBFS", flush=True)
    v01.write_json(destination / "SOURCES.json", {
        "version": "v02", "source_kind": "original_authored_symbolic_composition",
        "approval_status": "awaiting_user_audition", "subset": args.only or "complete",
        "v01_untouched": "v02 imports scripts/*.py read-only; v01 inputs and versions/v01 are unchanged",
        "inputs_sha256": inputs, "outputs_sha256": outputs,
        "python_version": sys.version.split()[0], "numpy_version": np.__version__,
        "mido_version": str(mido.version_info),
        "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]})
    print(destination, flush=True)


if __name__ == "__main__":
    main()
