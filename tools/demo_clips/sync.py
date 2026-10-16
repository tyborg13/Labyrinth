"""Waveform-matched measurements and informational limits of the recorded mix.

Only stdlib + the brief's ffmpeg are used. Correlation locates each emitted PCM
voice in the mixed WAV; overlapping voices are never assigned the nearest loud
peak. Unidentifiable cues are reported as unmeasured, never assigned times.
"""
from __future__ import annotations

from array import array
import json
import math
from operator import mul
from pathlib import Path
import subprocess

RATE = 48000  # Preserve the recorded stereo RMS envelope (0.021 ms precision).
SEARCH_SECONDS = 0.25
MATCH_SECONDS = 0.12
MIN_CORRELATION = 0.65
AMBIGUOUS_CORRELATION = 0.5
AUDIBLE_THRESHOLD = 10 ** (-40 / 20)
MEASURE_PREFIXES = ("hit.", "spell.", "hurt.", "status.", "trap.", "block.", "surface.", "impact.", "stoneskin.")


class Stereo:
    def __init__(self, left, right):
        if len(left) != len(right): raise ValueError("Stereo channel length mismatch")
        self.channels = (left, right)

    def __len__(self):
        return len(self.channels[0])


def channels(samples):
    return samples.channels if isinstance(samples, Stereo) else (samples,)


def energy(samples):
    tracks = channels(samples)
    return [sum(track[i] ** 2 for track in tracks) / len(tracks) for i in range(len(samples))]


def pcm(path: Path, pitch=1.0):
    # asetrate changes pitch and duration exactly once; aresample produces an
    # analysis copy. Never apply these filters to the deliverable audio.
    filters = []
    if pitch != 1.0:
        import wave
        with wave.open(str(path), "rb") as wav:
            filters.append(f"asetrate={wav.getframerate() * pitch:.9f}")
    filters.append(f"aresample={RATE}")
    result = subprocess.run(["ffmpeg", "-v", "error", "-threads", "2", "-filter_threads", "2", "-i", str(path), "-af", ",".join(filters), "-ac", "2", "-f", "f32le", "-threads", "2", "pipe:1"], check=True, capture_output=True)
    values = array("f")
    values.frombytes(result.stdout)
    return Stereo(values[0::2], values[1::2])


def rms_peak(samples, rules):
    """Same centered RMS window / first near-strongest local maximum as sfx-04."""
    if not samples: raise ValueError("Empty PCM")
    window = max(1, round(RATE * rules["envelope_window_ms"] / 1000))
    half = window // 2
    sums = [0.0]
    for power in energy(samples): sums.append(sums[-1] + power)
    powers = [(sums[min(len(samples), i - half + window)] - sums[max(0, i - half)]) / window for i in range(len(samples))]
    peak = max(range(len(powers)), key=powers.__getitem__)
    floor = powers[peak] * 10 ** (-rules["alignment_peak_within_db"] / 10)
    return next((i for i in range(1, len(powers) - 1) if powers[i] >= floor and powers[i] > powers[i - 1] and powers[i] >= powers[i + 1]), peak)


def correlation_peak_width(template):
    """Sample width of the cue's autocorrelation main lobe at half height.

    Autocorrelation is symmetric about lag zero. Count the contiguous samples
    at >= 0.5, including zero, so adjacent samples of one broad peak do not
    become separate occurrences. Periodic side lobes remain competing peaks.
    """
    power = sum(sum(map(mul, track, track)) for track in template)
    width = len(template[0])
    for lag in range(1, width):
        dot = sum(sum(map(mul, track[lag:], track[:-lag])) for track in template)
        if dot < AMBIGUOUS_CORRELATION * power:
            return 2 * lag - 1
    return 2 * width - 1


def locate(mix, reference, expected_s):
    # Locate the most energetic 120 ms section; sparse impulses and a quiet
    # leading pad cannot make silent frames look like a successful match.
    width = min(len(reference) // 2, round(MATCH_SECONDS * RATE))
    if width < 24: raise ValueError("Cue PCM too short to identify")
    ref_energy = energy(reference)
    window_energy = sum(ref_energy[:width])
    best_energy, start = window_energy, 0
    for i in range(width, len(reference)):
        window_energy += ref_energy[i] - ref_energy[i - width]
        if window_energy > best_energy: best_energy, start = window_energy, i - width + 1
    if best_energy < 1e-9: raise ValueError("Silent cue reference")
    expected = round(expected_s * RATE)
    radius = round(SEARCH_SECONDS * RATE)
    pairs = list(zip(channels(mix), channels(reference)))
    if len(channels(mix)) != len(channels(reference)): raise ValueError("Mix/reference channel mismatch")
    template = [r[start:start + width] for _, r in pairs]
    ref_power = sum(sum(map(mul, track, track)) for track in template)

    def score(offset):
        if offset + start < 0 or offset + start + width > len(mix): return -1.0
        dot = power = 0.0
        for (mix_channel, _), target in zip(pairs, template):
            segment = mix_channel[offset + start:offset + start + width]
            dot += sum(map(mul, segment, target))
            power += sum(map(mul, segment, segment))
        return dot / math.sqrt(max(1e-30, power * ref_power))

    # Every offset in the search window is scored with every template sample.
    # A sparse shortlist cannot establish the absence of another occurrence:
    # overlapping audio can lower its sparse rank while it remains identifiable.
    first = expected - radius
    dense = [score(i) for i in range(first, expected + radius + 1)]
    best = max(range(len(dense)), key=dense.__getitem__)
    correlation, offset = dense[best], first + best
    separation = correlation_peak_width(template)
    competing = next((i for i, confidence in enumerate(dense)
                      if confidence >= AMBIGUOUS_CORRELATION
                      and abs(i - best) >= separation
                      and (i == 0 or confidence > dense[i - 1])
                      and (i == len(dense) - 1 or confidence >= dense[i + 1])), None)
    if competing is not None:
        raise ValueError(f"ambiguous PCM match: competing occurrences at {offset / RATE:.6f}s and {(first + competing) / RATE:.6f}s")
    if correlation < MIN_CORRELATION:
        raise ValueError(f"low correlation: Cue cannot be separated from recorded mix (correlation {correlation:.3f})")
    dot = sum(sum(m[offset+i] * r[i] for i in range(start, start+width)) for m, r in pairs) / len(pairs)
    gain = dot / best_energy
    return offset, correlation, gain


def contacts(report):
    result = []
    previous = {}
    previous_traps = []
    previous_surfaces = []
    previous_terrain = []
    for frame in report["frames"]:
        changed, statuses = [], []
        for key, actor in frame["actors"].items():
            old = previous.get(key, actor)
            if any((actor.get(field) or 0) < (old.get(field) or 0) for field in ("hp", "block", "stoneskin")):
                changed.append(key)
            if any(actor.get(field) != old.get(field) for field in ("bleed", "freeze", "shock", "stoneskin", "block")):
                statuses.append(key)
        terrain_changed = bool(frame.get("terrain")) and frame.get("terrain") != previous_terrain
        traps_changed = frame["traps"] != previous_traps
        if changed or statuses or terrain_changed or traps_changed or (frame["surfaces"] and frame["surfaces"] != previous_surfaces):
            result.append({"frame": frame["frame"], "hit": changed, "status": statuses,
                           "trap": traps_changed, "surface": bool(frame["surfaces"]), "terrain": terrain_changed})
        previous = frame["actors"]
        previous_traps, previous_surfaces = frame["traps"], frame["surfaces"]
        previous_terrain = frame.get("terrain", [])
    return result


def contact_matches(cue, contact):
    if cue.startswith("trap."): return contact["trap"]
    if cue.startswith("surface."): return contact["surface"]
    if cue.startswith(("status.", "stoneskin.")) or cue == "block.gain": return contact["status"]
    if cue.startswith("spell."): return contact["hit"] or contact["surface"] or contact["terrain"]
    return contact["hit"]


def audible_duration(mix, reference, offset, gain):
    audible = [i for i in range(len(reference))
               if max(abs(c[i] * gain) for c in channels(reference)) >= AUDIBLE_THRESHOLD]
    if not audible: raise ValueError("Cue is inaudible at -40 dBFS in mix")
    first, last = audible[0], audible[-1]
    if offset + first < 0 or offset + last >= len(mix):
        raise ValueError("overlap or truncation: Recorded cue tail is outside the mix")
    tail_start = max(first, last - round(0.05 * RATE))
    dot = sum(sum(m[offset+i] * r[i] for i in range(tail_start, last+1))
              for m, r in zip(channels(mix), channels(reference)))
    power = sum(sum(r[i] ** 2 for i in range(tail_start, last+1)) for r in channels(reference))
    if power <= 1e-12 or dot / power < gain * 0.5:
        raise ValueError("overlap or truncation: Recorded cue tail is truncated or obscured")
    return (last - first + 1) / RATE


def visual_contact(cue, event, visual_contacts, fps):
    relevant = [f for f in visual_contacts if contact_matches(cue, f)]
    if not relevant: raise ValueError("ambiguous contact: No independent rendered contact for cue")
    # Association uses the request frame, never the measured audio peak.
    distance = min(abs(f["frame"] - event["frame"]) for f in relevant)
    nearest = [f for f in relevant if abs(f["frame"] - event["frame"]) == distance]
    if distance > math.ceil(SEARCH_SECONDS * fps) or len(nearest) != 1:
        raise ValueError("ambiguous contact: No unambiguous contact near the cue request")
    return nearest[0]


def audit(directory: Path, report, rules):
    mix, mix_error = None, None
    try:
        mix = pcm(directory / "movie.wav")
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        mix_error = str(exc)
    visual_contacts = contacts(report)
    rows, flags = [], []
    for event in report["events"]:
        cue = event.get("cue", "")
        if event.get("result") != "played": continue
        row = {"cue": cue, "request_frame": event["frame"], "pcm": event.get("pcm"),
               "status": "unmeasured", "flags": []}
        if not (cue.startswith(MEASURE_PREFIXES) or cue in {"fatigue", "push.collision", "dragon.breath"}):
            row.update(applicable=False, reason="UI/input cue, footfall, ambient bed or wind-up; outside the requested hit/status/trap table")
            rows.append(row)
            continue
        if report["clip"] == "air_pull" and not any(c["hit"] for c in visual_contacts):
            row.update(applicable=False, reason="Director's pull-only exception; no hit")
            rows.append(row)
            continue
        row["applicable"] = True
        row["offset_status"] = "unmeasured"
        needs_duration = cue.startswith(("status.", "trap."))
        if needs_duration: row["duration_status"] = "unmeasured"
        reasons = []
        try:
            if mix_error: raise ValueError("Recorded mix analysis unavailable: " + mix_error)
            if not event.get("pcm"): raise ValueError("Missing emitted PCM")
            reference = pcm(directory / event["pcm"], event["pitch"])
            offset, correlation, gain = locate(mix, reference, event["frame"] / report["fps"])
            row.update(correlation=correlation, method="PCM waveform matched in recorded WAV; independent final board submission")
            peak = rms_peak(reference, rules)
            peak_time = (offset + peak) / RATE
            try:
                visual = visual_contact(cue, event, visual_contacts, report["fps"])
                visual_time = visual["frame"] / report["fps"]
                lag = (peak_time - visual_time) * 1000
                row.update(offset_status="measured", visual_frame=visual["frame"], visual_time_s=visual_time,
                           audio_peak_time_s=peak_time, offset_ms=lag)
                low, high = rules["peak_window_ms"]
                if not low <= lag <= high:
                    row["flags"].append(f"Peak offset {lag:.3f} ms outside sfx-04 [{low}, {high}]")
                if event.get("alignment") and abs(lag - rules["target_lag_ms"]) > rules["aligned_tolerance_ms"]:
                    row["flags"].append(f"Aligned peak {lag:.3f} ms outside sfx-04 target ± tolerance")
            except ValueError as exc:
                row["offset_reason"] = str(exc)
                reasons.append("offset: " + str(exc))
            if needs_duration:
                try:
                    duration = audible_duration(mix, reference, offset, gain)
                    row.update(duration_status="measured", audible_duration_s=duration, tail_threshold_dbfs=-40)
                    if duration > 1.2: row["flags"].append(f"Status/trap cue lasts {duration:.3f}s (> 1.2s)")
                except ValueError as exc:
                    row["duration_reason"] = str(exc)
                    reasons.append("duration: " + str(exc))
        except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as exc:
            reasons.append(str(exc))
            row["offset_reason"] = str(exc)
            if needs_duration: row["duration_reason"] = str(exc)
        # A partial measurement retains its measured metric and explains the
        # other metric's limit; unknown values never become zero or flags.
        if row["offset_status"] == "measured" or row.get("duration_status") == "measured":
            row["status"] = "measured"
        if reasons: row["reason"] = "; ".join(reasons)
        flags.extend(f"{report['clip']}/{cue}: {flag}" for flag in row["flags"])
        rows.append(row)
    return rows, flags


def summary(items):
    rows = [dict(row, clip=item["clip"]) for item in items for row in item.get("sync_table", []) if row.get("applicable")]
    result = {"rows": rows, "flags": [dict(clip=row["clip"], cue=row["cue"], reason=flag)
                                      for row in rows for flag in row.get("flags", [])],
              "unmeasured": [row for row in rows if row["status"] == "unmeasured" or row.get("reason")],
              "trap_durations": []}
    for item in items:
        if item["clip"] not in ("trap_enemy", "trap_hero"): continue
        trap_rows = [row for row in item.get("sync_table", []) if row["cue"] == "trap.trigger"]
        if not trap_rows:
            result["trap_durations"].append({"clip": item["clip"], "cue": "trap.trigger", "status": "unmeasured",
                                            "reason": "; ".join(item.get("errors", [])) or "No played lightning-trap cue in take"})
        for row in trap_rows:
            entry = {"clip": item["clip"], "cue": row["cue"], "request_frame": row["request_frame"],
                     "status": row.get("duration_status", "unmeasured")}
            if entry["status"] == "measured": entry["audible_duration_s"] = row["audible_duration_s"]
            else: entry["reason"] = row.get("duration_reason", row.get("reason", "Duration not measured"))
            result["trap_durations"].append(entry)
    return result


def print_summary(result):
    print("DEMO SYNC SUMMARY (informational)", flush=True)
    print("clip | cue | status | offset ms | duration s | flags / unmeasured reason", flush=True)
    for row in result["rows"]:
        offset = f"{row['offset_ms']:.3f}" if row.get("offset_status") == "measured" else "—"
        duration = f"{row['audible_duration_s']:.6f}" if row.get("duration_status") == "measured" else "—"
        detail = "; ".join(row.get("flags", []) + ([row["reason"]] if row.get("reason") else [])) or "—"
        print(f"{row['clip']} | {row['cue']} | {row['status']} | {offset} | {duration} | {detail}", flush=True)
    for row in result["trap_durations"]:
        detail = f"{row['audible_duration_s']:.6f}s" if row["status"] == "measured" else row["reason"]
        print(f"DEMO LIGHTNING TRAP DURATION {row['clip']}: {row['status']} — {detail}", flush=True)
    print(f"DEMO SYNC TOTAL: {len(result['flags'])} flags; {len(result['unmeasured'])} rows with unmeasured metrics", flush=True)
