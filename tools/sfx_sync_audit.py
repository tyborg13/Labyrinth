#!/usr/bin/env python3
"""Measure shipped sample onset and fixed-clock production SFX presentation traces."""
from __future__ import annotations

import argparse
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
from tools.sfx_lab.sync_metrics import envelope_times, onset_cap, short_loudness, PEAK_LATE_LIMIT_MS

ROOT = Path(__file__).resolve().parents[1]
REPORT = Path("spec/peer_benchmark/staged/sfx/sync_audit.json")
ONSET_LIMIT_MS = 20.0
LEADING_LIMIT_MS = 10.0
THRESHOLD_DBFS = -45.0
ROUTER = "scripts/sfx_cue_router.gd"
RUN_SCENE = "scripts/run_scene.gd"
TRACE_INPUTS = (ROUTER, RUN_SCENE, "scripts/sfx_bank.gd", "data/sfx_cues.json",
                "tests/sfx_sync_harness.gd", "tests/sfx_sync_clock.gd", "tests/sfx_sync_pacing.gd",
                "tests/sfx_sync_sources.gd", "tests/sfx_sync_support.gd", "tests/sfx_sync_visuals.gd")
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
                                     "sha256": digest(path)}
                built = provenance.get(resource, {})
                alignment = built.get("processing", {}).get("sfx_04_alignment", {})
                if alignment and samples[resource]["sha256"] == built["output_sha256"]:
                    samples[resource]["peak_aligned"] = alignment["constraints"]["max_peak_ms"] is not None
                    samples[resource]["loudness_restore_gain_db"] = alignment["loudness_restore_gain_db"]
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
    if function == "release" and "request(cue)" in code:
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
                       **{key: event.get(key) for key in ("climax_applicable", "climax_kind", "climax_after_trigger_ms")},
                       "visual_climax": normalize_stack(event.get("climax_stack", [])),
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
        onset_min = minimum + min(leading) / maximum_pitch if minimum is not None and leading else None
        onset_max = maximum + max(leading) / minimum_pitch if maximum is not None and leading else None
        cap = onset_cap(cue, entry)
        perceived = [samples[path]["perceived_onset_ms"] for path in paths]
        peaks = [samples[path]["peak_ms"] for path in paths]
        perceived_min = minimum + min(perceived) / maximum_pitch if minimum is not None else None
        perceived_max = maximum + max(perceived) / minimum_pitch if maximum is not None else None
        peak_min = minimum + min(peaks) / maximum_pitch if minimum is not None else None
        peak_max = maximum + max(peaks) / minimum_pitch if maximum is not None else None
        climaxes = [event["climax_after_trigger_ms"] for event in events if event["climax_after_trigger_ms"] is not None]
        missing_climax = any(event["climax_applicable"] is not False and event["climax_after_trigger_ms"] is None for event in played)
        relative_peaks = [(event["delay_ms"] + peak / pitch - event["climax_after_trigger_ms"])
                          for event in played if event["delay_ms"] is not None and event["climax_after_trigger_ms"] is not None
                          for peak in peaks for pitch in (minimum_pitch, maximum_pitch)]
        early_aligned_peak = any(event["delay_ms"] + samples[path]["peak_ms"] / maximum_pitch < event["climax_after_trigger_ms"]
                                 for event in played if event["delay_ms"] is not None and event["climax_after_trigger_ms"] is not None
                                 for path in paths if samples[path].get("peak_aligned", False))
        loudness_deltas = [samples[path]["short_loudness_lufs"] - samples[path].get("reference_short_loudness_lufs", samples[path]["short_loudness_lufs"]) for path in paths]
        loudness_violation = any(abs(delta) > 0.5 for delta in loudness_deltas)
        causes = []
        if missing_anchor:
            causes.append("No visual anchor observed")
        if maximum is not None and maximum > ONSET_LIMIT_MS:
            if any(frame["function"] == "hit" and "schedule_area" in frame.get("code", "") for event in events for frame in event["call_sites"]):
                causes.append("Area voice stagger queue")
            else:
                causes.append("Cue follows its visual anchor")
        if minimum is not None and minimum < 0:
            causes.append("Cue precedes its visual anchor")
        if leading and max(leading) > LEADING_LIMIT_MS:
            causes.append("Sample leading silence exceeds 10 ms")
        if onset_max is not None and onset_max > ONSET_LIMIT_MS and not causes:
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
            causes.append("100 ms short-window loudness changed by more than 0.5 LU")
        if not played:
            verdict = "dropped" if all(event["result"] in {"cooldown", "priority"} for event in events) else "unmeasured"
            if verdict == "dropped":
                causes.append("Dropped immediately (" + ", ".join(sorted({event["result"] for event in events})) + "); no delayed playback")
        elif missing_anchor or onset_min is None or (cap is not None and missing_climax):
            verdict = "unmeasured"
        elif loudness_violation or (cap is not None and (onset_min < 0 or onset_max > ONSET_LIMIT_MS or max(leading) > LEADING_LIMIT_MS
                                 or perceived_max > cap or (relative_peaks and max(relative_peaks) > PEAK_LATE_LIMIT_MS) or early_aligned_peak)):
            verdict = "violation"
        elif maximum != 0 and entry.get("loop", False):
            verdict = "violation"
        else:
            verdict = "pass"
        anchors = {(frame["file"], frame["line"], frame["function"])
                   for event in events for frame in event["visual_anchor"]}
        rows.append({"cue": cue, "call_site": by_location[(file, line)],
                     "visual_anchors": [{"file": f, "line": n, "function": fn} for f, n, fn in sorted(anchors)],
                     "scenarios": sorted({event["scenario"] for event in events}),
                     "delay_min_ms": minimum, "delay_max_ms": maximum,
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
                     "queueing_or_sequencing": causes or ["None; immediate play or same-frame voice steal"],
                     "verdict": verdict, "loop": bool(entry.get("loop", False)),
                     "results": sorted({event["result"] for event in events})})
    rank = {"violation": 0, "unmeasured": 1, "dropped": 2, "pass": 3}
    rows.sort(key=lambda row: (rank[row["verdict"]], row["cue"], row["call_site"]["file"], row["call_site"]["line"]))
    missing = [site for site in sites if (site["file"], site["line"]) not in observed_sites and not site["dormant"]]
    missing_pairs = [{"cue": cue, "call_site": site} for site in sites for cue in sorted(expected_cues(site, cues))
                     if (cue, site["file"], site["line"]) not in groups]
    covered = {event["cue"] for event in observations}
    return {"rows": rows, "observations": observations, "samples": samples, "call_site_inventory": sites,
            "uncovered_call_sites": missing, "uncovered_cues": sorted(set(cues) - covered),
            "uncovered_cue_call_site_pairs": missing_pairs,
            "harness_failures": trace["failures"], "frame_usec": trace["frame_usec"],
            "source_sha256": {path: hashlib.sha256((sources or {}).get(path, (root / path).read_text()).encode()).hexdigest()
                              for path in TRACE_INPUTS if (root / path).exists()},
            "summary": {"cues": len(covered), "registry_cues": len(cues), "cue_call_site_rows": len(rows),
                        "violations": sum(row["verdict"] == "violation" for row in rows),
                        "unmeasured": sum(row["verdict"] == "unmeasured" for row in rows),
                        "uncovered_call_sites": len(missing), "uncovered_cue_call_site_pairs": len(missing_pairs)}}


def number(value: float | None) -> str:
    return "unmeasured" if value is None else f"{value:.3f}"


def location(site: dict) -> str:
    return f"{site['file']}:{site['line']} ({site['function']})"


def git_file(root: Path, revision: str, path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{revision}:{path}"], cwd=root)


def timing_changes(document: dict) -> list[dict]:
    if "before" not in document or "after" not in document:
        return []
    phases = {}
    for phase in ("before", "after"):
        grouped = defaultdict(list)
        for row in document[phase]["rows"]:
            grouped[row["cue"]].append(row)
        phases[phase] = {}
        for cue, rows in grouped.items():
            measured = [row for row in rows if row["delay_min_ms"] is not None]
            if not measured:
                continue
            phases[phase][cue] = {"delay_min_ms": min(row["delay_min_ms"] for row in measured),
                                  "delay_max_ms": max(row["delay_max_ms"] for row in measured),
                                  "onset_min_ms": min(row["onset_min_ms"] for row in measured),
                                  "onset_max_ms": max(row["onset_max_ms"] for row in measured),
                                  "leading_max_ms": max(max(row["leading_silence_ms"].values()) for row in measured),
                                  "call_sites": [row["call_site"] for row in rows],
                                  "causes": sorted({cause for row in rows for cause in row["queueing_or_sequencing"]
                                                    if cause != "None; immediate play or same-frame voice steal"})}
    changes = []
    for cue in sorted(set(phases["before"]) & set(phases["after"])):
        before, after = phases["before"][cue], phases["after"][cue]
        if any(abs(before[field] - after[field]) > 0.001 for field in ("delay_min_ms", "delay_max_ms", "leading_max_ms")):
            changes.append({"cue": cue, "before": before, "after": after})
    return changes


def visible_anchor_label(row: dict) -> str:
    anchors = row["visual_anchors"]
    direct = [site for site in anchors if site["file"] == RUN_SCENE and site["function"] not in {"_render_board_state", "_play_timed_animation_frames"}]
    selected = direct or anchors[:1]
    return "; ".join(location(site) for site in selected) or "unmeasured"


def feedback_changes(document: dict, cues: dict) -> list[dict]:
    if "feedback_1_before" not in document or "after" not in document:
        return []
    before, after = document["feedback_1_before"], document["after"]
    changes = []
    for cue in sorted(cues):
        rows = [row for row in after["rows"] if row["cue"] == cue]
        climaxes = [row["climax_min_ms"] for row in rows if row.get("climax_min_ms") is not None]
        for path in cue_samples(cue, cues):
            old, new = before["samples"][path], after["samples"][path]
            if old["sha256"] == new["sha256"]:
                continue
            changes.append({"cue": cue, "sample": path, "before": old, "after": new,
                            "call_sites": [row["call_site"] for row in rows],
                            "climax_min_ms": min(climaxes) if climaxes else None,
                            "climax_max_ms": max(row["climax_max_ms"] for row in rows if row.get("climax_max_ms") is not None) if climaxes else None,
                            "climax_kinds": sorted({kind for row in rows for kind in row.get("climax_kinds", [])})})
    return changes


def markdown(document: dict) -> str:
    lines = ["# SFX-04 sync audit", "", "Measured onset = fixed-clock play frame + decoded first sample above −45 dBFS. "
             "Bounds include every active variant and the slowest/fastest approved pitch jitter. "
             "Clock/timer instrumentation preserves production source lines; the production action, input, presentation, "
             "router and bank code execute headlessly. This measures presentation submissions, not audio-device latency.", "",
             "Feedback 1 also measures the entire file with a centered 5 ms RMS envelope (channel-mean power, one-sample hop, zero-padded edges). "
             "Perceived onset is its first crossing of −6 dB relative to the global envelope peak. Peak and onset columns include approved pitch/variant bounds. "
             "Visual climax is observed independently: origin departure for blink, release burst for cast, contact/status/death/appearance/input response for other discrete visuals. "
             "Continuous wind-ups/movement without a distinct climax have an onset cap only; ambient beds/loops are exempt. One-shot surfaces are included.", "",
             "Caps are 40 ms for impacts/statuses/deaths/UI and 60 ms for movement/casts/spells/wind-ups. Late peaks must be no later than climax + 30 ms; "
             "rebuilt aligned peaks must also be on or after the climax. The rebuild retains at least 15 ms before the peak and the entire tail, applies a 3 ms fade-in, "
             "and restores only the previous 100 ms short-window loudness (25 ms hops), within ±0.5 LU. The original leading-silence/trigger tests remain enforced.", "",
             "Rows cover both terminal router statements and their live trigger statements. "
             "Call stacks and per-scenario observations are retained in the JSON. No windowed capture is required.", ""]
    if document.get("feedback_1_changes"):
        changes = document["feedback_1_changes"]
        largest_loudness_delta = max(abs(change["after"]["short_loudness_lufs"] - change["before"]["short_loudness_lufs"]) for change in changes)
        lines += [f"Feedback 1 result: {document['feedback_1_before']['summary']['violations']} → {document['after']['summary']['violations']} violating cue/call-site rows; "
                  f"{len({change['sample'] for change in changes})} rebuilt files across {len({change['cue'] for change in changes})} cue identities (including inherited variants). "
                  f"Largest absolute 100 ms loudness change: {largest_loudness_delta:.3f} LU (limit 0.5 LU).", ""]
    for phase in ("before", "feedback_1_before", "after"):
        if phase not in document:
            continue
        result = document[phase]
        label = "Before feedback 1 trims" if phase == "feedback_1_before" else phase.capitalize()
        lines += [f"## {label}", "", f"`{json.dumps(result['summary'], sort_keys=True)}`", "",
                  "| Verdict | Cue | Call site | Visual anchor | Delay ms | Leading silence ms (max) | First-sample onset ms | Perceived onset ms | RMS peak ms | Visual climax ms | Peak − climax ms | Cause |",
                  "| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"]
        for row in result["rows"]:
            anchors = visible_anchor_label(row)
            delay = "not played" if row["verdict"] == "dropped" else f"{number(row['delay_min_ms'])}…{number(row['delay_max_ms'])}"
            onset = "not played" if row["verdict"] == "dropped" else f"{number(row['onset_min_ms'])}…{number(row['onset_max_ms'])}"
            lines.append("| " + " | ".join([row["verdict"], row["cue"], location(row["call_site"]), anchors or "unmeasured",
                delay,
                number(max(row["leading_silence_ms"].values(), default=0)),
                onset,
                f"{number(row.get('perceived_onset_min_ms'))}…{number(row.get('perceived_onset_max_ms'))}",
                f"{number(row.get('peak_min_ms'))}…{number(row.get('peak_max_ms'))}",
                f"{number(row.get('climax_min_ms'))}…{number(row.get('climax_max_ms'))}" if row.get("climax_min_ms") is not None else "n/a",
                f"{number(row.get('peak_relative_climax_min_ms'))}…{number(row.get('peak_relative_climax_max_ms'))}" if row.get("peak_relative_climax_min_ms") is not None else "n/a",
                "; ".join(row["queueing_or_sequencing"])]) + " |")
        if result["uncovered_call_sites"]:
            lines += ["", "Uncovered call sites (not a passing audit):", ""]
            lines += [f"- {location(site)}: `{site['code']}`" for site in result["uncovered_call_sites"]]
        if result.get("uncovered_cue_call_site_pairs"):
            lines += ["", "Uncovered cue alternatives (not a passing audit):", ""]
            lines += [f"- {entry['cue']}: {location(entry['call_site'])}" for entry in result["uncovered_cue_call_site_pairs"]]
    if document.get("timing_changes"):
        lines += ["", "## Director listening checklist", "", "Ranges include all measured call sites and approved pitch/variant bounds. "
                  "The JSON lists both old and new call sites for every entry.", "",
                  "| Cue | Call sites after | Play delay ms, before → after | Sample lead max ms, before → after | Cause |",
                  "| --- | --- | ---: | ---: | --- |"]
        for change in document["timing_changes"]:
            before, after = change["before"], change["after"]
            lines.append("| " + " | ".join([change["cue"], "; ".join(location(site) for site in after["call_sites"]),
                f"{number(before['delay_min_ms'])}…{number(before['delay_max_ms'])} → {number(after['delay_min_ms'])}…{number(after['delay_max_ms'])}",
                f"{number(before['leading_max_ms'])} → {number(after['leading_max_ms'])}", "; ".join(before["causes"])]) + " |")
    if document.get("feedback_1_changes"):
        lines += ["", "## Feedback 1 listening checklist", "",
                  "Sample onset/peak are at native speed; the tables above check every approved pitch and call site. Each row identifies a changed variant; inherited cues are listed too.", "",
                  "| Cue / variant | Call sites | Perceived onset ms, old → new | RMS peak ms, old → new | Visual climax ms after trigger | Loudness change LU | Restore gain dB |",
                  "| --- | --- | ---: | ---: | --- | ---: | ---: |"]
        for change in document["feedback_1_changes"]:
            old, new = change["before"], change["after"]
            climax = f"{number(change['climax_min_ms'])}…{number(change['climax_max_ms'])}" if change["climax_min_ms"] is not None else "n/a"
            lines.append("| " + " | ".join([change["cue"] + " / " + Path(change["sample"]).name,
                "; ".join(location(site) for site in change["call_sites"]),
                f"{number(old['perceived_onset_ms'])} → {number(new['perceived_onset_ms'])}",
                f"{number(old['peak_ms'])} → {number(new['peak_ms'])}",
                climax + "; " + "; ".join(change["climax_kinds"]),
                number(new["short_loudness_lufs"] - old["short_loudness_lufs"]),
                number(new.get("loudness_restore_gain_db", 0.0))]) + " |")
    lines += ["", "## No cue", ""]
    lines += [f"- {entry['visual']} — `{entry['source']}`: {entry['reason']}" for entry in NO_CUE]
    lines += ["", "## Chosen defaults", "", "Test-only: 60 Hz fixed clock (16,667 μs), seed 410, "
              "10 s initial clock, 5 s isolation between cases, 600-frame action budget, 12 startup frames. "
              "Fixture positions, damage, inventories and cue-branch examples exist only in tests. "
              "Encoder verification searches at most 64 legal head positions and 256 encode/measure passes; these are computation budgets, not audible targets. "
              "Voice arbitration uses internal priorities 0 (primary) and −1 (optional area), then oldest serial first. "
              "This makes the brief's required drop/steal policy explicit without changing a cue's level.", "",
              "## Reproduce", "", "Run from the task worktree:", "", "```sh",
              "/Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_sync_audit.py --phase before --baseline-ref " + document.get("before", {}).get("baseline_commit", "HEAD"),
              "/Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_sync_audit.py --phase after --check",
              "python3 tools/godot_task_runner.py --task-id sfx-04 --stream -- godot --headless --path . --script tests/sfx_sync_bank_test.gd",
              "/Users/borgerding/.cache/umbra-sfx/venv/bin/python tests/sfx_sync_test.py -v", "```", "",
              "The retained `feedback_1_before` section captures the first implementation's audio before the perceived-onset trims. "
              "To reproduce the approved rebuild from those inputs (or verify its idempotent completed state):", "", "```sh",
              "/Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/sync.py --features /private/tmp/labyrinth_codex/sfx_lab/r2/features.jsonl --align-audit spec/peer_benchmark/staged/sfx/sync_audit.json",
              "```", "",
              "Baseline replay compiles the original scripts in memory and reads the original approved audio into a temporary directory; "
              "it never checks out or modifies the working tree. The retained before source hashes must match the requested revision. "
              "The source manifest remains protected; `assets/audio/sfx/sfx-04-provenance.json` is the timing-only build provenance overlay. "
              "No windowed proof or inspection-fixture command is required by this unit brief.", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=("before", "feedback_1_before", "after"), required=True)
    parser.add_argument("--trace", type=Path, help="Use an already captured deterministic harness trace")
    parser.add_argument("--report", type=Path, default=REPORT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--baseline-ref", help="Replay before code and approved samples from this local Git revision, without checkout writes")
    args = parser.parse_args()
    report = ROOT / args.report
    document = json.loads(report.read_text()) if report.exists() else {"schema_version": 1, "task": "sfx-04", "no_cue": NO_CUE}
    if args.phase == "before" and "before" in document and not args.baseline_ref:
        parser.error("The retained before audit is immutable; use a different --report for an experiment.")
    if args.phase == "feedback_1_before" and "feedback_1_before" in document:
        parser.error("The pre-feedback audio evidence is immutable; use a different --report for an experiment.")
    if args.baseline_ref and args.phase != "before":
        parser.error("--baseline-ref is only valid for the before audit")
    sources = {}
    revision = None
    if args.baseline_ref:
        revision = subprocess.check_output(["git", "rev-parse", "--verify", args.baseline_ref + "^{commit}"], cwd=ROOT, text=True).strip()
        sources = {path: git_file(ROOT, revision, path).decode() for path in (ROUTER, RUN_SCENE, "scripts/sfx_bank.gd", "data/sfx_cues.json")}
        if "before" in document:
            for path, value in sources.items():
                if hashlib.sha256(value.encode()).hexdigest() != document["before"]["source_sha256"][path]:
                    parser.error("Refusing to replace before evidence with a different source revision: " + path)
    cues = json.loads(sources.get("data/sfx_cues.json", (ROOT / "data/sfx_cues.json").read_text()))["cues"]
    with tempfile.TemporaryDirectory(prefix="sfx-04-audit-") as directory:
        temporary = Path(directory)
        samples = sample_measurements(ROOT, cues, revision, temporary / "audio")
        if args.phase == "after" and "feedback_1_before" in document:
            for path, sample in samples.items():
                sample["reference_short_loudness_lufs"] = document["feedback_1_before"]["samples"][path]["short_loudness_lufs"]
        trace_path = args.trace or Path(directory) / "trace.json"
        if args.trace is None:
            samples_path = Path(directory) / "samples.json"
            samples_path.write_text(json.dumps(samples))
            command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", "sfx-04", "--stream", "--",
                       "godot", "--headless", "--path", str(ROOT), "--script", "tests/sfx_sync_harness.gd", "--", f"--output={trace_path}", f"--samples={samples_path}"]
            if args.check:
                command.append("--assert-onsets")
            if sources:
                cue_data = json.loads(sources["data/sfx_cues.json"])
                for entry in cue_data["cues"].values():
                    for key in ("variants", "fallback"):
                        if key in entry:
                            entry[key] = [str(temporary / "audio" / resource.removeprefix("res://")) if resource in samples else resource for resource in entry[key]]
                cue_path = temporary / "baseline_cues.json"
                cue_path.write_text(json.dumps(cue_data))
                sources_path = temporary / "sources.json"
                sources_path.write_text(json.dumps({**sources, "cue_data_path": str(cue_path)}))
                command.append(f"--sources={sources_path}")
            subprocess.run(command, cwd=ROOT, check=True)
        trace = json.loads(trace_path.read_text())
    if args.check:
        for path in TRACE_INPUTS:
            if trace.get("source_sha256", {}).get(path) != digest(ROOT / path):
                parser.error(f"Trace is stale or lacks source provenance: {path}")
    result = analyze(ROOT, trace, cues, samples, sources)
    if revision:
        result["baseline_commit"] = revision
    document[args.phase] = result
    document["schema_version"] = 2
    document["timing_changes"] = timing_changes(document)
    document["feedback_1_changes"] = feedback_changes(document, cues)
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
    report.with_suffix(".md").write_text(markdown(document))
    errors = result["harness_failures"] or result["uncovered_cues"] or result["uncovered_call_sites"] or result["uncovered_cue_call_site_pairs"] or result["summary"]["unmeasured"]
    if args.check:
        errors = errors or result["summary"]["violations"]
    print(f"SFX SYNC AUDIT {args.phase}: {'FAIL' if errors else 'PASS'} {json.dumps(result['summary'], sort_keys=True)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.path.insert(0, str(ROOT))
    raise SystemExit(main())
