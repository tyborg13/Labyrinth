#!/usr/bin/env python3
"""Measure shipped sample onset and fixed-clock production SFX presentation traces."""
from __future__ import annotations

import argparse
from collections import Counter
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

# Make direct CLI execution and module imports share the sound-lab measures.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.sfx_lab.sync_metrics import envelope_times, onset_cap, short_loudness, PEAK_LATE_LIMIT_MS, RULES, peak_levels

ROOT = Path(__file__).resolve().parents[1]
BASELINE = Path("spec/peer_benchmark/staged/sfx/sync_baseline.json")
REPORT = Path("output/sfx/sync_audit.json")
ONSET_LIMIT_MS = RULES["first_sample_limit_ms"]
LEADING_LIMIT_MS = RULES["leading_limit_ms"]
THRESHOLD_DBFS = RULES["first_sample_threshold_dbfs"]
ROUTER = "scripts/sfx_cue_router.gd"
RUN_SCENE = "scripts/run_scene.gd"
TRACE_INPUTS = ("scripts/sfx_sync_rules.gd", "scripts/sfx_peak_alignment.gd", ROUTER, RUN_SCENE, "scripts/sfx_bank.gd", "data/sfx_cues.json",
                "tests/sfx_sync_audio_lengths.gd", "tests/sfx_sync_harness.gd", "tests/sfx_sync_clock.gd", "tests/sfx_sync_pacing.gd",
                "tests/sfx_sync_sources.gd", "tests/sfx_sync_support.gd", "tests/sfx_sync_visuals.gd", "tests/sfx_sync_coverage.gd")
# Public compatibility entry point with no production caller. The actual
# ambience sites in RunScene are measured for all seven inherited beds.
DORMANT = {(ROUTER, "ambience"): "Public compatibility helper; production enters beds through RunScene._update_ambient_sfx_for_context."}
NO_CUE = [
    {"visual": "Blink arrival", "source": "scripts/run_scene.gd:_player_blink_effect",
     "reason": "No separate arrival cue exists in the approved registry."},
    {"visual": "Intent redirected/cancelled callout", "source": "scripts/intent_callouts.gd:play",
     "reason": "No cue (out of scope: do not add sounds to silent visuals)."},
    {"visual": "Targeting/attack preview", "source": "scripts/run_scene.gd:_preview_effect_for_action",
     "reason": "No cue; previews do not commit an action."},
]




def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_sites(root: Path, sources: dict | None = None) -> list[dict]:
    """Inventory concrete cue-producing statements, not a hand-maintained cue list.

    Both terminal router requests and their RunScene call sites are retained.
    A new call site cannot inherit a passing timing measurement from another.
    """
    sites = []
    registry = json.loads((sources or {}).get("data/sfx_cues.json", (root / "data/sfx_cues.json").read_text()))["cues"]
    literal_cue = re.compile(r'\b(?:play|request|schedule_area)\(\s*"(?:' + "|".join(re.escape(cue) for cue in registry) + r')"')
    for path in sorted((root / "scripts").rglob("*.gd")):
        relative = path.relative_to(root).as_posix()
        function = ""
        for number, line in enumerate((sources or {}).get(relative, path.read_text()).splitlines(), 1):
            declaration = re.match(r"(?:static )?func (\w+)\(", line)
            if declaration:
                function = declaration[1]
            code = line.split("#", 1)[0]
            if relative == ROUTER:
                relevant = bool(re.search(r"(?<!func )\brequest\(|bank\.schedule_area\(", code))
            else:
                relevant = bool(re.search(r"_sfx_router\.(?!baseline|begin_|bind_map_hover|weapon_for_card|ambience_for_run)(\w+)\(|_sfx_bank\.play(?:_entry)?\(", code))
                relevant = relevant or bool(literal_cue.search(code))
            if not relevant or (relative == RUN_SCENE and function == "_play_sfx"):
                continue
            sites.append({"file": relative, "line": number, "function": function,
                          "code": code.strip(), "dormant": DORMANT.get((relative, function))})
    return sites


def site_identity(site: dict) -> tuple[str, str, str]:
    """Stable across unrelated source edits and line shifts."""
    return site["file"], site["function"], " ".join(site["code"].split())


def coverage_regressions(result: dict, baseline: dict) -> list[str]:
    errors = playback_failures(result["observations"])
    current = compact_baseline(result)
    for index, run in enumerate(baseline["runs"]):
        for kind in ["request_counts", "primary_play_counts", "optional_play_counts"]:
            for key, counts in baseline[kind].items():
                current_index = current["runs"].index(run) if run in current["runs"] else -1
                actual = current[kind].get(key, [0] * len(current["runs"]))
                if current_index < 0 or actual[current_index] < counts[index]:
                    errors.append(f"{kind} shrank: {run} / {key}")
    pairs = {tuple(row) for row in current["cue_site_pairs"]}
    for row in baseline["cue_site_pairs"]:
        if tuple(row) not in pairs:
            errors.append("Cue × call-site coverage shrank: " + " | ".join(row))
    return errors


def playback_failures(observations: list[dict]) -> list[str]:
    errors = []
    for event in observations:
        result, request = event["result"], event.get("request", {})
        if result == "played": continue
        role = request.get("role", "primary")
        if result == "priority" and role == "optional_layer": continue
        if result == "cooldown" and 0 <= request.get("since_success_ms", -1) < request.get("cooldown_ms", 0): continue
        if result == "silent" and event["cue"].startswith("ambience."): continue
        errors.append(f"Required primary did not play: {event['scenario']} / {event['cue']} ({result}; {role})")
    return errors


def normalize_stack(stack: list[dict]) -> list[dict]:
    result = []
    for frame in stack:
        source = frame["source"]
        source = RUN_SCENE if source.startswith("gdscript://") else source.removeprefix("res://")
        if source.startswith("tests/sfx_sync_instrumented_"):
            source = "scripts/" + source.removeprefix("tests/sfx_sync_instrumented_")
        if source.startswith("scripts/"):
            result.append({"file": source, "line": frame["line"], "function": frame["function"]})
    return result


def ffmpeg_true_peak(path: Path, rate: int) -> float:
    """Independent floating-point 4x reconstruction using FFmpeg's resampler."""
    from tools.sfx_lab.common import command
    output = command(["ffmpeg", "-nostdin", "-hide_banner", "-threads", "2", "-i", str(path),
                      "-af", f"aformat=sample_fmts=dbl,aresample={rate * 4}:osf=dbl,astats=metadata=0:reset=0",
                      "-threads", "2", "-f", "null", "-"], text=True).stderr
    values = re.findall(r"Peak level dB: (-?[0-9.]+)", output)
    if not values: raise RuntimeError("Missing independent true-peak measurement: " + path.name)
    return float(values[-1])


def sample_measurements(root: Path, cues: dict, revision: str | None = None, audio_dir: Path | None = None) -> dict:
    # The existing sound-lab environment supplies these approved dependencies.
    from tools.sfx_lab.common import decode
    from tools.sfx_lab.sync import leading_ms
    samples = {}
    overlay = root / "assets/audio/sfx/sfx-04-provenance.json"
    provenance = {"res://assets/audio/sfx/cues/" + entry["path"]: entry for entry in json.loads(overlay.read_text())["outputs"]} if overlay.exists() else {}
    for cue in cues.values():
        source = cue
        visited = set()
        while "variants_from" in source:
            parent = source["variants_from"]
            if parent in visited:
                raise ValueError(f"Cyclic variants_from: {parent}")
            visited.add(parent)
            source = cues[parent]
        for resource in source.get("variants") or source.get("fallback", []):
            if resource not in samples:
                path = root / resource.removeprefix("res://")
                if revision:
                    path = audio_dir / resource.removeprefix("res://")
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(git_file(root, revision, resource.removeprefix("res://")))
                audio, rate = decode(path)
                samples[resource] = {"leading_ms": leading_ms(audio, rate), **envelope_times(audio, rate),
                                     "short_loudness_lufs": short_loudness(path), "sample_rate": rate,
                                     "duration_seconds": len(audio) / rate, **peak_levels(audio),
                                     "sha256": digest(path)}
                samples[resource]["true_peak_dbtp"] = max(samples[resource]["true_peak_dbtp"], ffmpeg_true_peak(path, rate))
                built = provenance.get(resource, {})
                if built and samples[resource]["sha256"] == built["output_sha256"]:
                    samples[resource]["peak_aligned"] = built.get("constraints", {}).get("max_peak_ms") is not None
                    samples[resource]["reference_short_loudness_lufs"] = built.get("constraints", {}).get("reference_loudness_lufs", samples[resource]["short_loudness_lufs"])
                    samples[resource]["peak_cap_dbfs"] = built.get("constraints", {}).get("peak_cap_dbfs", -1.0)
    return samples


def cue_samples(cue_id: str, cues: dict) -> list[str]:
    source = cues[cue_id]
    while "variants_from" in source:
        source = cues[source["variants_from"]]
    return source.get("variants") or source.get("fallback", [])


def expected_cues(site: dict, cues: dict) -> set[str]:
    """Require each alternative at a shared sink, not merely one visit to it."""
    if site["file"] != ROUTER or site["dormant"]:
        return set()
    code, function = site["code"], site["function"]
    literals = {value for value in re.findall(r'"([^"\n]+)"', code) if value in cues}
    families = {"death": "death.", "surface": "surface.", "status": "status.",
                "crate": "crate.", "pickup": "pickup.", "omen": "omen."}
    if function in families:
        selected = {cue for cue in cues if cue.startswith(families[function])}
        if function == "status": selected.discard("status.shatter")
        return selected
    if function == "hit" and ("request(cue," in code or "schedule_area(cue," in code):
        return {cue for cue in cues if cue.startswith(("hit.", "spell."))} | {"status.shatter", "push.collision"}
    if function == "release" and "request(cue," in code:
        return {"cast.arcane", "shot.bow", "shot.crossbow"}
    if 'request(field + ".gain")' in code:
        return {"block.gain", "stoneskin.gain"}
    return literals


def analyze(root: Path, trace: dict, cues: dict, samples: dict, sources: dict | None = None) -> dict:
    sites = source_sites(root, sources)
    by_location = {(site["file"], site["line"]): site for site in sites}
    observations = []
    groups = defaultdict(list)
    observed_sites = set()
    for event in trace["rows"]:
        stack = normalize_stack(event["stack"])
        anchor = normalize_stack(event["anchor_stack"])
        locations = {(frame["file"], frame["line"]) for frame in stack}
        matched = [by_location[location] for location in sorted(locations) if location in by_location]
        observed_sites.update(locations)
        observation = {**{key: event[key] for key in ("scenario", "cue", "result", "delay_ms", "pitch")},
                       **{key: event.get(key) for key in ("climax_applicable", "climax_kind", "climax_after_trigger_ms", "sample", "gain_db", "alignment")},
                       "speed": event.get("speed", 1.0), "frame_profile": event.get("frame_profile", "fixed_60"),
                       "request": event.get("request", {}), "visual_climax": normalize_stack(event.get("climax_stack", [])),
                       "call_sites": matched, "visual_anchor": anchor, "route": stack}
        observations.append(observation)
        for site in matched:
            groups[(event["cue"], site["file"], site["line"])].append(observation)
    rows = []
    for (cue, file, line), events in groups.items():
        entry = cues[cue]
        paths = cue_samples(cue, cues)
        leading = [samples[path]["leading_ms"] for path in paths]
        minimum_pitch = float(entry.get("pitch_scale", 1)) * (1 - float(entry.get("pitch_jitter", 0)))
        maximum_pitch = float(entry.get("pitch_scale", 1)) * (1 + float(entry.get("pitch_jitter", 0)))
        played = [event for event in events if event["result"] == "played"]
        delays = [event["delay_ms"] for event in played if event["delay_ms"] is not None]
        missing_anchor = any(event["delay_ms"] is None for event in played)
        minimum = min(delays) if delays else None
        maximum = max(delays) if delays else None
        cap = onset_cap(cue, entry)
        onsets, perceived_times, peak_times, relative_peaks = [], [], [], []
        ordinary_onsets, ordinary_leads = [], []
        early_aligned_peak = False
        alignment_failures = []
        for event in played:
            delay = event["delay_ms"]
            if delay is None: continue
            alignment = event.get("alignment") or {}
            variants = [(alignment["metrics"], event["pitch"])] if alignment else [
                (samples[path], pitch) for path in paths for pitch in (minimum_pitch, maximum_pitch)]
            for sample, pitch in variants:
                first = delay + sample.get("leading_ms", 0) / pitch
                onsets.append(first)
                perceived_times.append((0 if alignment else delay) + sample["perceived_onset_ms"] / pitch)
                peak_times.append(delay + sample["peak_ms"] / pitch)
                if not alignment:
                    ordinary_onsets.append(first)
                    ordinary_leads.append(sample["leading_ms"])
                if event["climax_after_trigger_ms"] is not None:
                    relative = delay + sample["peak_ms"] / pitch - event["climax_after_trigger_ms"]
                    relative_peaks.append(relative)
                    if alignment and abs(relative - RULES["target_lag_ms"]) > RULES["aligned_tolerance_ms"]:
                        alignment_failures.append("Aligned peak outside climax +15 ±1 ms")
                    if (alignment or sample.get("peak_aligned", False)) and relative < 0: early_aligned_peak = True
            if alignment:
                if not alignment.get("fade_and_tail_verified", False): alignment_failures.append("3 ms PCM fade / whole-tail assertion failed")
                if alignment["metrics"]["peak_ms"] / event["pitch"] < RULES["minimum_pre_peak_ms"] - 1000 / alignment["rate"] / event["pitch"]:
                    alignment_failures.append("Less than 15 ms retained before the peak")
        onset_min, onset_max = (min(onsets), max(onsets)) if onsets else (None, None)
        perceived_min, perceived_max = (min(perceived_times), max(perceived_times)) if perceived_times else (None, None)
        peak_min, peak_max = (min(peak_times), max(peak_times)) if peak_times else (None, None)
        climaxes = [event["climax_after_trigger_ms"] for event in events if event["climax_after_trigger_ms"] is not None]
        missing_climax = any(event["climax_applicable"] is not False and event["climax_after_trigger_ms"] is None for event in played)
        ordinary_violation = any(value < 0 or value > ONSET_LIMIT_MS for value in ordinary_onsets) or any(value > LEADING_LIMIT_MS for value in ordinary_leads)
        loudness_deltas = [samples[path]["short_loudness_lufs"] - samples[path].get("reference_short_loudness_lufs", samples[path]["short_loudness_lufs"]) for path in paths]
        loudness_violation = any(not RULES["loudness_delta_lu"][0] <= delta <= RULES["loudness_delta_lu"][1] for delta in loudness_deltas)
        causes = list(dict.fromkeys(alignment_failures))
        if missing_anchor:
            causes.append("No visual anchor observed")
        if any(event["delay_ms"] is not None and event["delay_ms"] > ONSET_LIMIT_MS and not event.get("alignment") for event in played):
            if any(frame["function"] == "hit" and "schedule_area" in frame.get("code", "") for event in events for frame in event["call_sites"]):
                causes.append("Area voice stagger queue")
            else:
                causes.append("Cue follows its visual anchor")
        if minimum is not None and minimum < 0:
            causes.append("Cue precedes its visual anchor")
        if ordinary_leads and max(ordinary_leads) > LEADING_LIMIT_MS:
            causes.append("Sample leading silence exceeds 10 ms")
        if ordinary_violation and not causes:
            causes.append("Visual-to-play delay plus sample onset exceeds 20 ms")
        if cap is not None and perceived_max is not None and perceived_max > cap:
            causes.append(f"Perceived onset exceeds {cap:g} ms cap")
        if cap is not None and relative_peaks and max(relative_peaks) > PEAK_LATE_LIMIT_MS:
            causes.append("Sample RMS peak trails visual climax by more than 30 ms")
        if cap is not None and missing_climax:
            causes.append("No visual climax observed")
        if early_aligned_peak:
            causes.append("Rebuilt RMS peak precedes visual climax")
        if loudness_violation:
            causes.append("100 ms short-window loudness outside −1.0…+0.5 LU")
        if not played:
            verdict = "dropped" if all(event["result"] in {"cooldown", "priority"} for event in events) else "unmeasured"
            if verdict == "dropped":
                causes.append("Dropped immediately (" + ", ".join(sorted({event["result"] for event in events})) + "); no delayed playback")
        elif missing_anchor or onset_min is None or (cap is not None and missing_climax):
            verdict = "unmeasured"
        elif alignment_failures or (cap is not None and (ordinary_violation
                                 or perceived_max > cap or (relative_peaks and max(relative_peaks) > PEAK_LATE_LIMIT_MS) or early_aligned_peak)):
            verdict = "violation"
        elif maximum != 0 and entry.get("loop", False):
            verdict = "violation"
        elif loudness_violation:
            verdict = "loudness exception"
        else:
            verdict = "pass"
        anchors = {(frame["file"], frame["line"], frame["function"])
                   for event in events for frame in event["visual_anchor"]}
        rows.append({"cue": cue, "call_site": by_location[(file, line)],
                     "visual_anchors": [{"file": f, "line": n, "function": fn} for f, n, fn in sorted(anchors)],
                     "scenarios": sorted({event["scenario"] for event in events}),
                     "delay_min_ms": minimum, "delay_max_ms": maximum,
                     "per_call_peak_alignment": any(event.get("alignment") for event in played),
                     "leading_silence_ms": {path: samples[path]["leading_ms"] for path in paths},
                     "onset_min_ms": onset_min, "onset_max_ms": onset_max,
                     "perceived_onset_min_ms": perceived_min, "perceived_onset_max_ms": perceived_max, "perceived_onset_cap_ms": cap,
                     "peak_min_ms": peak_min, "peak_max_ms": peak_max,
                     "climax_min_ms": min(climaxes) if climaxes else None, "climax_max_ms": max(climaxes) if climaxes else None,
                     "climax_kinds": sorted({event["climax_kind"] or "missing" for event in events}),
                     "visual_climaxes": sorted({location(frame) for event in events for frame in event["visual_climax"]}),
                     "peak_relative_climax_min_ms": min(relative_peaks) if relative_peaks else None,
                     "peak_relative_climax_max_ms": max(relative_peaks) if relative_peaks else None,
                     "short_loudness_delta_lu": {path: delta for path, delta in zip(paths, loudness_deltas)},
                     "queueing_or_sequencing": causes or (["Per-call pitch-adjusted peak alignment; onset cap starts at scheduled playback"] if any(event.get("alignment") for event in played) else ["None; immediate play or same-frame voice steal"]),
                     "verdict": verdict, "loop": bool(entry.get("loop", False)),
                     "results": sorted({event["result"] for event in events})})
    rank = {"violation": 0, "unmeasured": 1, "loudness exception": 2, "dropped": 3, "pass": 4}
    rows.sort(key=lambda row: (rank[row["verdict"]], row["cue"], row["call_site"]["file"], row["call_site"]["line"]))
    missing = [site for site in sites if (site["file"], site["line"]) not in observed_sites and not site["dormant"]]
    missing_pairs = [{"cue": cue, "call_site": site} for site in sites for cue in sorted(expected_cues(site, cues))
                     if (cue, site["file"], site["line"]) not in groups]
    covered = {event["cue"] for event in observations}
    return {"rows": rows, "observations": observations, "silences": trace.get("silences", []), "samples": samples, "call_site_inventory": sites,
            "uncovered_call_sites": missing, "uncovered_cues": sorted(set(cues) - covered),
            "uncovered_cue_call_site_pairs": missing_pairs,
            "harness_failures": trace["failures"], "frame_usec": trace["frame_usec"],
            "source_sha256": {path: hashlib.sha256((sources or {}).get(path, (root / path).read_text()).encode()).hexdigest()
                              for path in TRACE_INPUTS if (root / path).exists()},
            "summary": {"cues": len(covered), "registry_cues": len(cues), "cue_call_site_rows": len(rows), "observations": len(observations),
                        "violations": sum(row["verdict"] == "violation" for row in rows),
                        "unmeasured": sum(row["verdict"] == "unmeasured" for row in rows),
                        "uncovered_call_sites": len(missing), "uncovered_cue_call_site_pairs": len(missing_pairs)}}


def area_loudness_proof(root: Path, trace: dict) -> dict:
    """Render exactly the voices emitted by the single/three-target fixtures."""
    from fractions import Fraction
    import numpy as np
    import soundfile as sf
    from scipy.signal import resample_poly
    from tools.sfx_lab.common import decode
    result = {}
    with tempfile.TemporaryDirectory(prefix="sfx-04-area-") as directory:
        for scenario in ("area/single", "area/same_frame"):
            voices = [row for row in trace["rows"] if row.get("speed", 1.0) == 1.0 and row.get("frame_profile", "fixed_60") == "fixed_60" and row["scenario"] == scenario
                      and row["cue"] == "spell.fire" and row["result"] == "played"]
            if not voices:
                return {"error": "Missing area loudness fixture: " + scenario}
            mixed = np.zeros((0, 2))
            for voice in voices:
                audio, rate = decode(root / voice["sample"].removeprefix("res://"))
                if audio.shape[1] == 1:
                    audio = np.repeat(audio, 2, axis=1)
                ratio = Fraction(48000 / (rate * voice["pitch"])).limit_denominator(10000)
                audio = resample_poly(audio, ratio.numerator, ratio.denominator) * 10 ** (voice["gain_db"] / 20)
                if len(mixed) < len(audio):
                    mixed = np.pad(mixed, ((0, len(audio) - len(mixed)), (0, 0)))
                mixed[:len(audio)] += audio
            path = Path(directory) / (scenario.replace("/", "_") + ".wav")
            sf.write(path, mixed, 48000, subtype="FLOAT")
            result[scenario] = {"voices": len(voices), "short_loudness_lufs": short_loudness(path)}
    result["delta_lu"] = result["area/same_frame"]["short_loudness_lufs"] - result["area/single"]["short_loudness_lufs"]
    result["pass"] = result["area/same_frame"]["voices"] == 1 and abs(result["delta_lu"]) <= 0.5
    return result


def number(value: float | None) -> str:
    return "unmeasured" if value is None else f"{value:.3f}"


def location(site: dict) -> str:
    return f"{site['file']}:{site['line']} ({site['function']})"


def git_file(root: Path, revision: str, path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{revision}:{path}"], cwd=root)


def rounded(value):
    if isinstance(value, float): return round(value, 6)
    if isinstance(value, dict): return {key: rounded(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)): return [rounded(item) for item in value]
    return value


def compact_text(document: dict) -> str:
    """One measured sample, site, or count row per line keeps diffs reviewable."""
    lines = ["{"]
    for section_index, (key, value) in enumerate(document.items()):
        suffix = "," if section_index < len(document) - 1 else ""
        dump = lambda item: json.dumps(rounded(item), sort_keys=True, ensure_ascii=False, separators=(",", ":"))
        if isinstance(value, dict):
            entries = ["    " + json.dumps(name) + ":" + dump(item) for name, item in sorted(value.items())]
            lines += ["  " + json.dumps(key) + ":{", ",\n".join(entries), "  }" + suffix]
        elif isinstance(value, list):
            lines += ["  " + json.dumps(key) + ":[", ",\n".join("    " + dump(item) for item in value), "  ]" + suffix]
        else: lines += ["  " + json.dumps(key) + ":" + dump(value) + suffix]
    return "\n".join(lines) + "\n}\n"


def compact_baseline(result: dict) -> dict:
    speeds = sorted({event.get("speed", 1.0) for event in result["observations"]})
    runs = sorted({(event.get("frame_profile", "fixed_60"), event.get("speed", 1.0)) for event in result["observations"]})
    counts = {kind: {} for kind in ["request_counts", "primary_play_counts", "optional_play_counts", "allowed_drop_counts"]}
    for event in result["observations"]:
        key = event["scenario"] + "|" + event["cue"]
        index = runs.index((event.get("frame_profile", "fixed_60"), event.get("speed", 1.0)))
        role = event.get("request", {}).get("role", "primary")
        counts["request_counts"].setdefault(key, [0] * len(runs))[index] += 1
        if event["result"] == "played":
            kind = "primary_play_counts" if role == "primary" else "optional_play_counts"
        else:
            kind = "allowed_drop_counts"
            key += "|" + role + "|" + event["result"]
        counts[kind].setdefault(key, [0] * len(runs))[index] += 1
    silences = {row["scenario"]: row for row in result["silences"]}
    fields = {"sha256", "leading_ms", "perceived_onset_ms", "peak_ms", "short_loudness_lufs", "sample_rate",
              "duration_seconds", "peak_dbfs", "true_peak_dbtp", "peak_cap_dbfs", "reference_short_loudness_lufs", "peak_aligned"}
    return rounded({"schema_version": 2, "speeds": speeds, "runs": runs,
            "samples": {path: {key: value for key, value in sample.items() if key in fields} for path, sample in result["samples"].items()},
            "cue_site_pairs": sorted({(row["cue"], *site_identity(row["call_site"])) for row in result["rows"]}),
            **counts, "silences": list(silences.values()),
            "area_loudness": result.get("area_loudness", {}), "summary": result["summary"],
            "loudness_exceptions": result.get("loudness_exceptions", [])})


def markdown(result: dict, provenance: dict) -> str:
    lines = ["# SFX sync audit", "", "Current measurement policy", "",
             "Alignment uses the earliest local maximum within 2 dB of the strongest centered 5 ms RMS peak. "
             "Asset cuts measure instantaneous max-channel amplitude before fading and move to a point at least 20 dB below the selected RMS peak, retain at least 15 ms before it, and use a 3 ms linear fade. "
             "An already-short source head is kept whole rather than padded. The asset's complete tail is retained. The lossless parent recipe and its hash are recorded in the compact provenance.", "",
             "Blink (including relay and swaps), cast.arcane, and animated roars plan each call at its actual selected pitch. "
             "The same per-call rule covers hit.blunt.heavy and illusion.spawn because their quiet asset cuts retain more pre-peak time than the contact window permits. "
             "Runtime head skips use the separate minimum-pre-peak and fade rule; the quiet-cut rule applies to lossless asset rebuilds. "
             "The actual submitted climax sets an absolute presentation-clock deadline; due calls dispatch in that process tick, without extrapolating frame intervals. "
             "Late dispatch skips the corresponding pitch-adjusted head, bounded by the 15 ms minimum pre-peak lead, with the 3 ms fade and whole tail preserved. "
             "Presentation deadlines freeze during pause or hit-stop. "
             "Aligned peaks must land at climax +15 ±1 ms; their onset cap is measured from scheduled playback. "
             "Other one-shots retain the 0–20 ms first-sample, ≤10 ms leading-silence, and 40/60 ms perceived-onset limits. "
             "All tunables live in data/sfx_cues.json rules.sync.", "",
             "Every scenario runs at 1×, 1.5× and 2× with fixed 60 Hz, periodic 33 ms spikes, steady 30 fps, 144 Hz and seeded ±4 ms jitter. "
             "Coverage baselines requests, successful primaries and successful optional layers separately for each run. "
             "Primary priority drops always fail; cooldown drops require a preceding successful play within the authored cooldown. "
             "Optional-layer priority drops and intentionally empty ambient beds are recorded explicitly.", "",
             "Gain restoration respects the original build's category/sample cap and −1 dBTP. "
             "Maximum BS.1770 loudness over 100 ms windows at 25 ms hops may change by −1.0…+0.5 LU. "
             "Same-frame contacts collapse only identical cues; distinct contacts remain audible. Additional contacts retain −6 dB layering.", "",
             "Current results", "", "`" + json.dumps(result["summary"], sort_keys=True) + "`", "",
             "| Cue | Call site | Onset ms | Perceived ms | Peak − climax ms | Result |",
             "|---|---|---:|---:|---:|---|"]
    for row in result["rows"]:
        site = row["call_site"]
        lines.append(f"| {row['cue']} | {site['file']}::{site['function']} | {number(row['onset_max_ms'])} | {number(row['perceived_onset_max_ms'])} | {number(row['peak_relative_climax_min_ms'])}…{number(row['peak_relative_climax_max_ms'])} | {row['verdict']} |")
    lines += ["", "Re-trimmed files", "", "| File | Previous removed samples | Current removed samples | Loudness Δ LU |", "|---|---:|---:|---:|"]
    for row in provenance["outputs"]:
        if row.get("previous_removed_samples") != row.get("removed_samples"):
            lines.append(f"| {row['path']} | {row.get('previous_removed_samples', 0)} | {row.get('removed_samples', 0)} | {number(row.get('after', {}).get('loudness_delta_lu'))} |")
    lines += ["", "Listening checklist", "", "Audition every revised file, with special attention to first-transient shape, clicks at the cut, and the intact tail. "
              "The checklist includes every rebuilt file, covering both peer-flagged sets (17 + 15) conservatively. Reconstructed flags are annotated; exact membership of the peer lists was not supplied.", ""]
    for row in provenance["outputs"]:
        reasons = row.get("listening_flags", [])
        lines.append("- [ ] `" + row["path"] + "`: " + ("; ".join(reasons) or "verify first transient, quiet cut, loudness and tail"))
    lines += ["", "Follow-ups", ""]
    failures = result.get("harness_failures", []) + result.get("coverage_regressions", []) + result.get("length_failures", []) + result.get("peak_failures", [])
    for row in result["rows"]:
        if row["verdict"] in {"violation", "unmeasured"}:
            failures.append(row["cue"] + " / " + row["call_site"]["function"] + ": " + "; ".join(row["queueing_or_sequencing"]))
    for row in provenance["outputs"]:
        delta = row.get("after", {}).get("loudness_delta_lu", 0)
        if not RULES["loudness_delta_lu"][0] <= delta <= RULES["loudness_delta_lu"][1]:
            failures.append(row["path"] + f": capped loudness outside window ({delta:+.3f} LU)")
    lines += ["- " + item for item in dict.fromkeys(failures)] or ["No measured timing, coverage, peak, length, or loudness violations remain."]
    lines += ["", "Reproduce from the task worktree with the sound-lab Python environment activated:", "", "```sh",
              "python tools/sfx_lab/sync.py", "python tools/sfx_sync_audit.py --report output/sfx/sync_audit.json --check",
              "python3 tools/godot_task_runner.py --task-id sfx-04 --stream -- godot --headless --path . --script tests/sfx_sync_bank_test.gd",
              "```", "", "The first command is idempotent. A changed source requires the approved local sound library in .godot/sfx_lab; "
              "use --features and --sources to relocate it. Full traces, PCM copies, and reports stay under gitignored output/sfx/. "
              "Use --refresh-baseline only after inspecting the current measurements and coverage. "
              "The harness exercises every scenario at 1×, 1.5×, and 2×. It observes production state submissions with a deterministic 60 Hz clock; "
              "it does not claim audio-device or speaker latency measurements.", ""]
    if result.get("verification"):
        lines += ["Verification", ""] + ["- " + item for item in result["verification"]] + [""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, default=REPORT)
    parser.add_argument("--trace", type=Path, help="Analyze an existing current-source trace")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--refresh-baseline", action="store_true")
    args = parser.parse_args()
    report = (ROOT / args.report).resolve()
    if not report.is_relative_to(ROOT / "output/sfx"):
        parser.error("Full reports must stay in gitignored output/sfx/")
    report.parent.mkdir(parents=True, exist_ok=True)
    cues = json.loads((ROOT / "data/sfx_cues.json").read_text())["cues"]
    samples = sample_measurements(ROOT, cues)
    samples_path = report.parent / "samples.json"
    samples_path.write_text(json.dumps(samples, sort_keys=True))
    trace_path = args.trace or report.parent / "trace.json"
    if args.trace is None:
        command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "sfx-04", "--stream", "--",
                   "godot", "--headless", "--path", ".", "--script", "tests/sfx_sync_harness.gd", "--",
                   "--output=res://" + trace_path.relative_to(ROOT).as_posix(),
                   "--samples=res://" + samples_path.relative_to(ROOT).as_posix()]
        if args.check: command.append("--assert-onsets")
        completed = subprocess.run(command, cwd=ROOT, check=False)
        if completed.returncode and not trace_path.exists():
            raise RuntimeError("Sync harness failed before writing a trace")
    trace = json.loads(trace_path.read_text())
    from tools.sfx_lab.common import decode
    from tools.sfx_lab.sync import leading_ms
    for event in trace["rows"]:
        alignment = event.get("alignment", {})
        if alignment:
            pcm_path = Path(alignment.pop("pcm_path"))
            if not pcm_path.is_absolute(): pcm_path = ROOT / pcm_path
            pcm, rate = decode(pcm_path)
            measured = envelope_times(pcm, rate)
            measured["leading_ms"] = leading_ms(pcm, rate)
            for key in ("peak_ms", "perceived_onset_ms"):
                if abs(measured[key] - alignment["metrics"][key]) > 1000 / rate:
                    trace["failures"].append(f"Independent PCM metric differs: {event['scenario']} / {key}")
            alignment["metrics"] = measured
            alignment["pcm_sha256"] = digest(pcm_path)
    for path in TRACE_INPUTS:
        if trace.get("source_sha256", {}).get(path) != digest(ROOT / path):
            trace["failures"].append("Trace lacks current source provenance: " + path)
    result = analyze(ROOT, trace, cues, samples)
    result["playback_failures"] = playback_failures(result["observations"])
    result["area_loudness"] = area_loudness_proof(ROOT, trace)
    baseline = json.loads((ROOT / BASELINE).read_text())
    result["coverage_regressions"] = coverage_regressions(result, baseline) if args.check else []
    result["length_failures"] = trace.get("length_failures", [])
    result["loudness_exceptions"] = [
        {"path": path, "delta_lu": sample["short_loudness_lufs"] - sample["reference_short_loudness_lufs"]}
        for path, sample in samples.items() if "reference_short_loudness_lufs" in sample and
        not RULES["loudness_delta_lu"][0] <= sample["short_loudness_lufs"] - sample["reference_short_loudness_lufs"] <= RULES["loudness_delta_lu"][1]]
    result["summary"]["loudness_exceptions"] = len(result["loudness_exceptions"])
    result["peak_failures"] = [path for path, sample in samples.items() if "peak_cap_dbfs" in sample and
        (sample["peak_dbfs"] > sample["peak_cap_dbfs"] + 0.001 or sample["true_peak_dbtp"] > RULES["true_peak_ceiling_dbtp"] + 0.001)]
    report.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    provenance = json.loads((ROOT / "assets/audio/sfx/sfx-04-provenance.json").read_text())
    report.with_suffix(".md").write_text(markdown(result, provenance))
    errors = any(result.get(key) for key in ["harness_failures", "playback_failures", "coverage_regressions", "uncovered_cues", "uncovered_call_sites", "uncovered_cue_call_site_pairs", "length_failures", "peak_failures"])
    errors |= bool(result["summary"]["unmeasured"] or result["summary"]["violations"] or not result["area_loudness"].get("pass", False))
    if args.refresh_baseline:
        if errors: raise RuntimeError("Refusing to refresh a failing baseline; inspect the full report")
        (ROOT / BASELINE).write_text(compact_text(compact_baseline(result)))
        (ROOT / BASELINE.with_name("sync_audit.md")).write_text(markdown(result, provenance))
    print("SFX_SYNC_REPORT=" + report.relative_to(ROOT).as_posix())
    print(f"SFX SYNC AUDIT: {'FAIL' if errors else 'PASS'} {json.dumps(result['summary'], sort_keys=True)}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
