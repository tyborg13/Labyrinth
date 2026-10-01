#!/usr/bin/env python3
"""Dragon boss themes and stingers v01: deterministic audition build.

Renders the authored scores in dragon_scores.py with the approved Thorns in the
Dark v02 renderer family (procedural bowed strings, v01/v02 synthesis, circular
dark echo), calibrating every stem against Thorns v02's own stem targets.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np

import dragon_scores as scores
import dragon_audio as audio

thorns = scores.thorns
strings, engine, v01 = thorns.strings, thorns.engine, thorns.v01
bowed = strings.bowed_strings
import mido  # noqa: E402

import verify as checks  # noqa: E402  (umbra_three_sketches verifier helpers, on the path via Thorns)

RATE, ROOT, CASE = v01.RATE, scores.ROOT, scores.CASE
LOOP_LUFS, LOOP_PEAK_LIMIT = -20.0, -3.0
STINGER_LUFS, STINGER_PEAK_CEILING = -18.0, -3.0
SERIAL_SALT = "dragon-themes-and-stingers-v01"


def thorns_template(samples, waves, wav):
    """The exact pre-master stem LUFS targets of the approved Thorns in the Dark v02 mix."""
    parent = json.loads((thorns.PARENTS[thorns.SLUG] / "score.json").read_text())
    old = {name: thorns.measured(engine.make_stem(parent, name, samples, waves), wav)
           for name in ["drums", "bowed_veil", "hollow_bass", "thread_pluck", "shadow_lead"]}
    template = {name: old[name] - (1.5 if name in ["drums", "bowed_veil"] else 1)
                for name in ["drums", "bowed_veil", "hollow_bass", "thread_pluck"]}
    template.update(violin_1=old["shadow_lead"] - 4, violin_2=old["shadow_lead"] - 7,
                    viola=old["shadow_lead"] - 8.5)
    return template


def tremolo_envelope(notes, bpm, patch, length):
    """Measured bowed tremolo: smooth bow-change dips at a tempo-locked stroke rate."""
    env = np.ones(length)
    beat = 60 / bpm
    period = beat / patch.get("tremolo_division", 4)
    depth = patch.get("tremolo_depth", .6)
    for n in notes:
        if n.get("articulation") != "tremolo":
            continue
        a = round((n["beat"] - notes[0]["beat"]) * beat * RATE)
        b = min(length, round((n["beat"] + n["duration"] - notes[0]["beat"]) * beat * RATE))
        t = np.arange(b - a) / RATE
        edges = np.clip(np.minimum(t, t[-1] - t) / .03, 0, 1)
        dip = (.5 + .5 * np.cos(2 * np.pi * t / period)) ** 6
        env[a:b] *= 1 - depth * edges * dip
    return env


def string_stem(s, name):
    """The approved string-ensemble stem (strings.string_stem) plus optional tremolo articulation."""
    patch = s["patches"][name]
    stem = np.zeros((round(s["bars"] * 240 / s["bpm"] * RATE), 2))
    groups = []
    for n in (n for n in s["notes"] if n["instrument"] == name):
        if not groups or n["beat"] > groups[-1][-1]["beat"] + groups[-1][-1]["duration"] + 1e-5:
            groups.append([])
        groups[-1].append(n)
    for notes in groups:
        wave = bowed.phrase(notes, s["bpm"], patch)
        if any(n.get("articulation") == "tremolo" for n in notes):
            wave = wave * tremolo_envelope(notes, s["bpm"], patch, len(wave))
        v01.circular_add(stem, wave, round(notes[0]["beat"] * 60 / s["bpm"] * RATE), patch["pan"])
    return engine.circular_lowpass(stem, patch["lowpass_hz"])


def calibrated_stems(s, samples, waves, template, wav):
    wet, gains, targets = {}, {}, {}
    for name in sorted({n["instrument"] for n in s["notes"]}):
        patch = s["patches"][name]
        stem = string_stem(s, name) if "voice" in patch else engine.make_stem(s, name, samples, waves)
        reference, offset = s["mix"][name]
        targets[name] = template[reference] + offset
        gains[name] = 10 ** ((targets[name] - thorns.measured(stem, wav)) / 20)
        wet[name] = v01.circular_dark_echo(stem * gains[name], patch["wet"], 60 / s["bpm"])
    return wet, gains, targets


def encode(wav, folder, slug):
    for suffix, codec in [("flac", ["-c:a", "flac", "-compression_level", "8"]),
                          ("ogg", ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "5"]),
                          ("mp3", ["-c:a", "libmp3lame", "-b:a", "192k"])]:
        subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-i", str(wav), "-map_metadata", "-1",
                        *codec, str(folder / f"preview.{suffix}")], check=True)
    v01.normalize_ogg_serial(folder / "preview.ogg", int(hashlib.sha256((slug + SERIAL_SALT).encode()).hexdigest()[:8], 16))


def balance(wet, gain, wav):
    """Absolute stem LUFS inside the -20 LUFS master (the Thorns v02 report convention)."""
    return {name: round(thorns.measured(stem * gain, wav), 2) for name, stem in wet.items()}


def render_theme(s, folder, samples, waves, template):
    with tempfile.TemporaryDirectory(prefix="umbra-dragon-") as td:
        wav = Path(td) / "measure.wav"
        wet, gains, targets = calibrated_stems(s, samples, waves, template, wav)
        mix = sum(wet[name] for name in sorted(wet))
        master = 10 ** ((LOOP_LUFS - thorns.measured(mix, wav)) / 20)
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
        encode(wav, folder, s["slug"])
        stems = {"calibration_gain": gains, "target_pre_master_lufs": targets,
                 "lufs_in_matched_mix": balance(wet, master, wav),
                 "post_master_peak_dbfs": {n: round(audio.db(np.max(np.abs(w * master))), 2) for n, w in wet.items()}}
        lead = s["lead_instrument"]
        middle = [n for n in ["violin_2", "viola"] if n in wet and n != lead]
        stems["lead_above_middle_lu"] = round(stems["lufs_in_matched_mix"][lead] - (
            thorns.measured(sum(wet[n] for n in middle) * master, wav)), 2) if middle else None
    return {"master_gain": master, "pre_master_sample_peak_dbfs": peak, "stems": stems,
            "circular_continuity_before_taper": {"wrap_sample_delta": wrap.tolist(),
                                                 "p99_9_adjacent_delta": adjacent.tolist(),
                                                 "ratio": (wrap / adjacent).tolist()},
            "loop_method": "periodic overlap-add of every release tail, circular echo/filters, exact bar length, "
                           "2 ms endpoint taper (Thorns v02 convention)"}


def hall(signal, rt60, wet, seed):
    """Synthetic diffuse tail: seeded decaying noise impulse response, linear convolution."""
    length = round(min(3.0, rt60 * 1.3) * RATE)
    t = np.arange(length) / RATE
    rng = np.random.default_rng(seed)
    ir = rng.normal(size=(length, 2)) * np.exp(-6.9078 * t / rt60)[:, None]
    # Zero-padded (linear) tone filtering: the zero-phase pre-ring must not wrap to the IR's end.
    freqs = np.fft.rfftfreq(2 * length, 1 / RATE)
    tone = 1 / np.sqrt(1 + (freqs / 3800) ** 4) * (1 - np.exp(-(freqs / 180) ** 2))
    ir = np.fft.irfft(np.fft.rfft(ir, n=2 * length, axis=0) * tone[:, None], n=2 * length, axis=0)[:length]
    ir[:round(.012 * RATE)] = 0
    ir[-round(.05 * RATE):] *= np.cos(np.linspace(0, np.pi / 2, round(.05 * RATE)))[:, None] ** 2
    ir /= np.sqrt(np.sum(ir ** 2) / 2)
    size = len(signal) + length
    out = np.fft.irfft(np.fft.rfft(signal, n=size, axis=0) * np.fft.rfft(ir, n=size, axis=0), n=size, axis=0)
    padded = np.vstack([signal, np.zeros((length, 2))])
    return padded + wet * out


def render_stinger(s, folder, samples, waves, template):
    with tempfile.TemporaryDirectory(prefix="umbra-dragon-stinger-") as td:
        wav = Path(td) / "measure.wav"
        wet, gains, targets = calibrated_stems(s, samples, waves, template, wav)
        dry = sum(wet[name] for name in sorted(wet))
        # The canvas is longer than every tail; its last 100 ms only holds the zero-phase
        # filters' wrapped pre-ring of the first attack, which is removed before the hall.
        guard = round(.1 * RATE)
        canvas_tail = audio.db(np.max(np.abs(dry[-guard:]))) - audio.db(np.max(np.abs(dry)))
        if canvas_tail > -45:
            raise ValueError(f"{s['slug']}: canvas too short for its tail ({canvas_tail:.1f} dB)")
        dry[-guard:] = 0
        seed = int(hashlib.sha256(s["slug"].encode()).hexdigest()[:8], 16)
        mix = hall(dry, s["reverb"]["rt60_seconds"], s["reverb"]["wet"], seed)
        level = np.abs(mix).max(axis=1)
        floor = np.max(level) * 10 ** (-54 / 20)
        end = int(np.nonzero(level > floor)[0][-1]) + round(.05 * RATE)
        mix = mix[:end]
        fade_in, fade_out = round(.003 * RATE), round(.35 * RATE)
        mix[:fade_in] *= np.sin(np.linspace(0, np.pi / 2, fade_in))[:, None] ** 2
        mix[-fade_out:] *= np.cos(np.linspace(0, np.pi / 2, fade_out))[:, None] ** 2
        v01.write_stereo_wave(wav, mix / (np.max(np.abs(mix)) * 1.2), RATE)
        measured = audio.ebur128(wav)
        pre_gain = 1 / (np.max(np.abs(mix)) * 1.2)
        loud_gain = pre_gain * 10 ** ((STINGER_LUFS - measured["integrated_lufs"]) / 20)
        ceiling_gain = 10 ** (STINGER_PEAK_CEILING / 20) / np.max(np.abs(mix))
        gain = min(loud_gain, ceiling_gain)
        mix *= gain
        v01.write_stereo_wave(wav, mix, RATE)
        encode(wav, folder, s["slug"])
        return {"master_gain": float(gain), "limited_by": "peak ceiling" if ceiling_gain < loud_gain else "loudness target",
                "target_integrated_lufs": STINGER_LUFS, "sample_peak_ceiling_dbfs": STINGER_PEAK_CEILING,
                "reverb": s["reverb"], "canvas_final_100ms_rel_peak_db": canvas_tail, "stems": {"calibration_gain": gains, "target_pre_master_lufs": targets,
                                                 "post_master_peak_dbfs": {n: round(audio.db(np.max(np.abs(w * gain))), 2)
                                                                           for n, w in wet.items()}},
                "tail_method": "linear (non-circular) render, synthetic hall tail, trimmed 50 ms after the tail "
                               "falls 54 dB below peak, 3 ms fade-in and 350 ms cosine fade over the already-quiet end"}


def decoded_report(s, folder):
    report = {}
    for suffix in ["flac", "ogg", "mp3"]:
        path = folder / f"preview.{suffix}"
        metrics = checks._decoded_metrics(path, RATE)
        frames = audio.decode(path)
        entry = {"duration_seconds": metrics["duration_seconds"], "sample_peak_dbfs": metrics["peak_dbfs"]}
        entry.update(audio.ebur128(path))
        if s["kind"] == "loop_theme":
            entry.update(checks.loudness(path))
            if suffix != "mp3":
                checks._validate_loop_seam(metrics, 1.5, str(path))
                entry["sample_seam_to_p99_9_ratio"] = metrics["seam_to_p99_9_ratio"]
                entry["seam_profile"] = audio.seam_profile(frames, audio.section_starts(s))
        else:
            entry["shape"] = audio.stinger_shape(frames)
        report[suffix] = entry
    return report


def load_template(samples, waves):
    with tempfile.TemporaryDirectory(prefix="umbra-dragon-template-") as td:
        return thorns_template(samples, waves, Path(td) / "t.wav")


def source_paths(samples):
    paths = sorted((CASE / "scripts").glob("*.py")) + [CASE / p for p in ["README.md", "PROVENANCE.md", "requirements.txt"]]
    paths += [thorns.CASE / "scripts" / p for p in ["build_thorns.py", "verify_thorns.py"]]
    paths += [strings.CASE / "scripts" / p for p in ["build_strings.py", "bowed_strings.py"]]
    paths += [thorns.OLD / "scripts" / p for p in ["build.py", "build_v02.py", "verify.py"]]
    paths += [engine.BANK / "bank_manifest.json", *(engine.BANK / s["path"] for s in samples.values())]
    paths += [ROOT / "tools/classical_soundtrack_pipeline" / p for p in ["common.py", "render.py", "verify.py"]]
    paths += [thorns.PARENTS[thorns.SLUG] / "score.json"]
    return paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=CASE / "versions/v01")
    parser.add_argument("--only", nargs="*", help="development subset (the verifier requires the full set)")
    args = parser.parse_args()
    destination = args.output_dir.resolve()
    if destination.exists():
        raise SystemExit(f"Refusing to replace an audition directory: {destination}")
    samples, waves = engine.load_bank()
    template = load_template(samples, waves)
    inputs = {str(p.relative_to(ROOT)): v01.sha256(p) for p in source_paths(samples)}
    destination.mkdir(parents=True)
    outputs = {}
    for s in scores.compositions(args.only):
        folder = destination / s["slug"]
        folder.mkdir()
        v01.write_json(folder / "score.json", s)
        engine.midi(s, folder / "arrangement.mid")
        render = (render_theme if s["kind"] == "loop_theme" else render_stinger)(s, folder, samples, waves, template)
        render.update({"version": "v01", "title": s["title"], "kind": s["kind"], "key": s["key"], "bpm": s["bpm"],
                       "bars": s["bars"], "sample_rate": RATE, "channels": 2,
                       "note_counts": dict(Counter(n["instrument"] for n in s["notes"])),
                       "thorns_v02_stem_template_lufs": template, "decoded": decoded_report(s, folder)})
        if s["kind"] == "loop_theme":
            render["loop_duration_seconds"] = s["bars"] * 240 / s["bpm"]
        render["artifacts_sha256"] = {p.name: v01.sha256(p) for p in sorted(folder.iterdir())}
        v01.write_json(folder / "render.json", render)
        outputs.update({f"{s['slug']}/{p.name}": v01.sha256(p) for p in sorted(folder.iterdir())})
        flac = render["decoded"]["flac"]
        print(f"{s['title']}: {flac['duration_seconds']:.2f}s, {flac['integrated_lufs']:.2f} LUFS, "
              f"sample peak {flac['sample_peak_dbfs']:.2f} dBFS", flush=True)
    v01.write_json(destination / "SOURCES.json", {
        "version": "v01", "source_kind": "original_authored_symbolic_composition",
        "approval_status": "awaiting_user_audition", "subset": args.only or "complete",
        "inputs_sha256": inputs, "outputs_sha256": outputs,
        "python_version": sys.version.split()[0], "numpy_version": np.__version__,
        "mido_version": str(mido.version_info),
        "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]})
    print(destination, flush=True)


if __name__ == "__main__":
    main()
