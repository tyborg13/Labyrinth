"""Join bank requests to admissions and find the exact qualifying windows."""

from collections import Counter, defaultdict
from functools import lru_cache
import json
from pathlib import Path
import re

import numpy as np

from tools.qa111.measure import ROOT, pcm
from tools.sfx_lab.sync_metrics import RULES, envelope
from tools.sfx_sync_audit import cue_samples


REPEAT_MS = 150
BURST_MS = 100
BURST_REQUESTS = 4
OVERLAP_HOP_MS = 1
VOICE_AUDIBLE_RELATIVE_DB = -20
VOICE_AUDIBLE_ABSOLUTE_DBFS = -60


def jsonl(path):
    return [json.loads(line) for line in path.read_text().splitlines()]


def source_label(route):
    for frame in route:
        script, _, function = frame.split(":", 2)
        if script == "sfx_cue_router.gd" and function == "request":
            continue
        if function in {"_play_sfx", "schedule_area", "play_entry"}:
            continue
        return f"{script.removesuffix('.gd')}.{function}"
    return "source unavailable"


def decision_label(row):
    value = row.get("card_id") or row.get("choice_id") or row.get("method") or row.get("path") or ""
    return " ".join(filter(None, (row.get("kind", "startup"), value.rsplit("/", 1)[-1])))


def windows(requests, width, minimum):
    """All maximal qualifying windows, including two overlapping bursts if distinct."""
    end = previous_end = 0
    for start, request in enumerate(requests):
        while end < len(requests) and requests[end]["ms"] - request["ms"] <= width:
            end += 1
        if end - start >= minimum and end > previous_end:
            yield requests[start:end]
        previous_end = end


def request_windows(requests):
    by_cue = defaultdict(list)
    for request in requests:
        by_cue[request["cue"]].append(request)
    for rows in by_cue.values():
        for window in windows(rows, REPEAT_MS, 2):
            yield "repeat", window
    for window in windows(requests, BURST_MS, BURST_REQUESTS):
        yield "burst", window


def close_voice(slots, slot, at):
    if slot in slots:
        voice = slots.pop(slot)
        voice["stolen"] = not voice["loop"] and at < voice["end"]
        voice["end"] = min(voice["end"], at)


def fade_bed(beds, bank, at, fade):
    if bank in beds:
        voice = beds.pop(bank)
        voice["fade_out"] = (at, fade)
        voice["end"] = min(voice["end"], at + fade)


def load_hunt(directory, cues):
    decisions = {row["data"]["decision"]: row["data"] for row in jsonl(directory / "trace.jsonl")
                 if row["event"] == "decision"}
    requests, slots, beds, playing = {}, {}, {}, {}
    for row in jsonl(directory / "sfx.jsonl"):
        if "stop_slot" in row:
            close_voice(slots, row["stop_slot"], row["ms"])
        elif "fade_bank" in row:
            fade_bed(beds, row["fade_bank"], row["ms"], row["loop_fade_ms"])
        elif "requested" in row:
            decision = decisions.get(row["decision"], {})
            row["input"] = decision_label(decision)
            row["section"] = decision.get("context", {}).get("section", 0)
            row["room"] = decision.get("context", {}).get("room_kind", "startup")
            row["site"] = source_label(row["source"])
            requests[row["id"]] = row
        else:
            request = requests[row["id"]]
            request.update(cue=row["cue"], result=row["result"], started=row.get("start", False))
            if not row.get("start"):
                continue
            cue = row["cue"]
            if not row["path"]:
                if cue in cues:
                    row["path"] = cue_samples(cue, cues)[row["variant"]]
                elif cue.startswith("legacy:"):
                    row["path"] = cue.removeprefix("legacy:")
                else:
                    row["path"] = legacy_paths()[cue]
            bank = request["bank"]
            row["end"] = float("inf") if row["loop"] else row["ms"] + row["duration_ms"]
            close_voice(slots, row["slot"], row["ms"])
            slots[row["slot"]] = row
            if row["loop"]:
                fade_bed(beds, bank, row["ms"], row["loop_fade_ms"])
                beds[bank] = row
            playing[row["id"]] = row
    for request in requests.values():
        request.setdefault("cue", request["requested"])
        request.setdefault("result", "unresolved")
        request.setdefault("started", False)
    return list(requests.values()), playing


@lru_cache(maxsize=1)
def legacy_paths():
    source = (ROOT / "scripts/run_sfx_library.gd").read_text()
    names = dict(re.findall(r'const (\w+): String = "([^"]+)"', source))
    return {names.get(key, key.strip('"')): path for key, path in
            re.findall(r'([\w."]+):\s*\{\s*"path":\s*"([^"]+)"', source)}


@lru_cache(maxsize=None)
def file_envelope(path):
    samples, rate = pcm(path)
    rms = envelope(samples, rate)
    # A millisecond grid is sufficient for the overlap model and keeps loop
    # modelling cheap. Work in linear amplitude for pitch/gain and fades.
    points = np.arange(0, len(samples) * 1000 / rate, OVERLAP_HOP_MS)
    return np.interp(points * rate / 1000, np.arange(len(rms)), rms)


def voice_envelope(voice, grid):
    rms = file_envelope(voice["path"])
    age = grid - voice["ms"]
    file_age = age * voice["pitch"]
    if voice["loop"]:
        file_age %= len(rms)
    else:
        # Releases with alignment play a shortened PCM stream. Published
        # one-shots in this trace have no explicit length override. Recover
        # the alignment cut from the original versus actual stream length.
        cut = max(0.0, len(rms) - voice["duration_ms"] * voice["pitch"])
        file_age += cut
    gain = 10 ** (voice["gain"] / 20)
    result = np.interp(file_age, np.arange(len(rms)), rms, right=0) * gain
    if voice["loop"]:
        result *= np.clip(age / voice["loop_fade_ms"], 0, 1)
    if "fade_out" in voice:
        end, length = voice["fade_out"]
        result *= np.clip(1 - (grid - end) / length, 0, 1)
    result[(age < 0) | (grid >= voice["end"])] = 0
    return result, rms.max() * gain


def allocated_peak(voices):
    edges = [(voice["ms"], 1) for voice in voices] + [(voice["end"], -1) for voice in voices]
    active = peak = 0
    for _, change in sorted(edges):
        active += change
        peak = max(active, peak)
    return peak


def overlap(voices):
    if len(voices) < 2:
        return 0, None
    start = sorted(voice["ms"] for voice in voices)[1]
    end = sorted(voice["end"] for voice in voices)[-2]
    if end <= start:
        return 0, None
    if not np.isfinite(end):
        raise ValueError("Two unbounded beds survived crossfade")
    grid = np.arange(start, end, OVERLAP_HOP_MS)
    simultaneous = np.zeros(len(grid), dtype=int)
    power = np.zeros(len(grid))
    for voice in voices:
        rms, peak = voice_envelope(voice, grid)
        floor = max(10 ** (VOICE_AUDIBLE_ABSOLUTE_DBFS / 20), peak * 10 ** (VOICE_AUDIBLE_RELATIVE_DB / 20))
        simultaneous += rms >= floor
        power += rms ** 2
    mask = simultaneous >= 2
    if not mask.any():
        return 0, None
    return int(mask.sum()) * OVERLAP_HOP_MS, float(10 * np.log10(power[mask].max()))


def analyze_hunts(campaign, cues):
    runs = []
    incidents = []
    observed = defaultdict(Counter)
    results = Counter()
    for directory in sorted(campaign.glob("seed-*")):
        if not (directory / "evidence.json").exists():
            continue
        evidence = json.loads((directory / "evidence.json").read_text())
        requests, voices = load_hunt(directory, cues)
        seed = int(evidence["seed"])
        runs.append((seed, evidence, len(requests), len(voices)))
        for request in requests:
            results[request["result"]] += 1
            voice = voices.get(request["id"])
            if voice:
                observed[(voice["cue"], voice["path"])][(request["site"], request["room"])] += 1
        for kind, window in request_windows(requests):
            played = [voices[request["id"]] for request in window if request["started"]]
            overlap_ms, sum_db = overlap(played)
            counts = Counter(request["result"] for request in window)
            incidents.append({
                "seed": seed, "kind": kind, "time_ms": window[0]["ms"],
                "span_ms": window[-1]["ms"] - window[0]["ms"],
                "ids": [row["id"] for row in window], "requests": Counter(row["cue"] for row in window),
                "starts": Counter(row["cue"] for row in played), "results": counts,
                "actors": sorted({(row["action_serial"], row["actor"], row["action"]) for row in window}),
                "inputs": sorted({(row["decision"], row["section"], row["room"], row["input"]) for row in window}),
                "sites": sorted({row["site"] for row in window}),
                "overlap_ms": overlap_ms, "sum_db": sum_db, "allocated_peak": allocated_peak(played),
                "voices_cut_short": sum(row.get("stolen", False) for row in played),
            })
    incidents.sort(key=lambda row: (row["seed"], row["time_ms"], row["kind"], row["ids"]))
    return runs, incidents, observed, results
