#!/usr/bin/env python3
"""perf-164 headless proof: staged base/candidate projects, load counts, semantic receipts and interleaved timing."""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
import shutil
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TASK = "perf-164"
# perf-161 (codex/perf-161), the base this unit was built on; pinned so the
# baseline arm stays the same after the director commits perf-164.
BASE = "0679a2087a8fc907de0c4d4b8cefcbcd912e27ed"
PROBE = "res://tools/perf164/probe.gd"
SKIP = {".git", ".godot", "output"}
ENV = {"LABYRINTH_CEL_LOOK": "all", "LABYRINTH_DEMO": "0", "LABYRINTH_DISABLE_STEAM": "1"}
ORDER = "ABBAABBAAB"
NATIVE = False  # --native: Metal window at the probe corner; set by main()
# Native timing keeps perf-158's Deck pixel load: 1280x800 backing, 115% UI, no HiDPI (copy-only override.cfg).
NATIVE_DISPLAY = ["--display-driver", "macos", "--rendering-method", "mobile", "--rendering-driver", "metal",
                  "--audio-driver", "Dummy", "--windowed", "--position", "24,24"]
ARENAS = [f"guardian:{name}" for name in ("ashen_reaver", "rimejaw", "storm_cantor", "gallows_roc", "craghide", "last_lamplighter")] + \
    [f"dragon:{name}" for name in ("vyraketh", "iskaldra", "zekarion", "vaeloryx", "tharokh", "noctyrax")]


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=ROOT)


def changed_paths():
    """Working-tree changes against BASE, excluding this tool."""
    changes = {}
    diff = git("diff", "--name-status", "--no-renames", "-z", BASE).decode().rstrip("\0").split("\0")
    for state, name in zip(diff[::2], diff[1::2]):
        changes[Path(name)] = state
    for name in git("ls-files", "--others", "--exclude-standard", "-z").decode().split("\0"):
        if name:
            changes.setdefault(Path(name), "A")
    return {path: state for path, state in changes.items() if path.parts[:2] != ("tools", "perf164")}


def stage(destination: Path, baseline: bool):
    """Symlinked project; the base arm restores BASE blobs for every changed file."""
    changes = changed_paths() if baseline else {}
    ancestors = {parent for path in changes for parent in path.parents}

    def place(relative: Path):
        target = destination / relative
        source = ROOT / relative
        status = changes.get(relative)
        if status == "A":
            return
        if status:
            target.write_bytes(git("show", f"{BASE}:{relative.as_posix()}"))
        elif relative in ancestors:
            target.mkdir()
            names = {entry.name for entry in source.iterdir()} if source.is_dir() else set()
            names.update(path.name for path in (changes.keys() | ancestors) if path.parent == relative)
            for name in sorted(names):
                place(relative / name)
        elif source.exists() or source.is_symlink():
            target.symlink_to(source, target_is_directory=source.is_dir())

    destination.mkdir(parents=True)
    for entry in sorted(ROOT.iterdir()):
        if entry.name not in SKIP:
            place(Path(entry.name))
    subprocess.run(["cp", "-cR", str(ROOT / ".godot"), str(destination / ".godot")], check=True)
    return {"baseline": baseline, "restored": sorted(str(path) for path, state in changes.items() if state != "A"),
            "omitted": sorted(str(path) for path, state in changes.items() if state == "A")}


def run_take(project: Path, take: Path, case: str, fixture: str, profile: str, trace: bool, timeout: int = 420,
             storage: Path | None = None, capture: bool = False):
    take.mkdir(parents=True)
    qos = ["/usr/sbin/taskpolicy", "-c", "background"] if profile == "background" else []
    if capture:
        # Real renderer pixels: the visual runner validates the emitted 1920x1080 PNGs.
        command = [sys.executable, str(ROOT / "tools/visual_probe_runner.py"), "--project", str(project), "--task-id", TASK,
                   "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy", "--rendering-method", "mobile",
                   "--rendering-driver", "metal", "--timeout", str(timeout), "--expect-size", "1920x1080", "--min-images", "1",
                   "--result-manifest", str(take / "images.json"), PROBE, "--", "--capture", f"--case={case}", f"--output={take}"]
    else:
        display = NATIVE_DISPLAY if NATIVE else ["--headless"]
        command = [*qos, sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--project", str(project), "--task-id", TASK,
                   "--timeout", str(timeout), "--", "godot", *display, "--path", str(project), "--script", PROBE, "--",
                   f"--case={case}", f"--output={take}", *(["--deck"] if NATIVE else [])]
    if fixture:
        command.append(f"--fixture={fixture}")
    if storage is not None:
        command.extend([f"--storage={storage}", *(["--from-save"] if case != "save_quit_pre_battle" else [])])
    env = {**os.environ, **ENV, "LABYRINTH_HITCH_TRACE": "1" if trace else "0", **({"LABYRINTH_PROBE_WINDOW": "1"} if NATIVE or capture else {}),
           **({"SteamDeck": "1"} if NATIVE and not capture else {})}
    (take / "command.json").write_text(json.dumps({"command": command, "env": {**ENV, "LABYRINTH_HITCH_TRACE": env["LABYRINTH_HITCH_TRACE"]}}, indent=2))
    with (take / "godot.log").open("w") as log:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    path = take / "receipt.json"
    receipt = json.loads(path.read_text()) if path.exists() else {"errors": ["no receipt"]}
    receipt["exit"] = result.returncode
    status = "PASS" if not result.returncode and not receipt.get("errors") else "FAIL"
    print(f"PERF164 TAKE {status}: {take}", flush=True)
    return receipt


def projects(output: Path):
    arms = {}
    for name, baseline in (("baseline", True), ("candidate", False)):
        project = output / "projects" / name
        if not project.exists():
            manifest = stage(project, baseline)
            if NATIVE:
                sys.path.insert(0, str(ROOT / "tools" / "hitch_census"))
                from census import write_window_override
                if (project / "override.cfg").is_symlink():
                    (project / "override.cfg").unlink()
                write_window_override(project)
            (output / "projects" / f"{name}.json").write_text(json.dumps(manifest, indent=2))
        arms[name] = project
    return arms


def metrics(case: str, receipt: dict):
    frames = receipt.get("frames", {})

    def frame(label, key="max_us"):
        return frames.get(label, {}).get(key)

    result = {}
    if case == "continue_pre_battle":
        result = {"continue_wall_us": receipt.get("continue_wall_us"), "cover_max_frame_us": frame("continue"),
                  "revealed_max_frame_us": frame("revealed")}
    elif case == "arena":
        result = {"travel_wall_us": receipt.get("travel_wall_us"), "travel_max_frame_us": frame("travel"),
                  "begin_frame_us": frame("begin", "first_us"), "opening_max_frame_us": frame("opening")}
    elif case in ("map_history", "grimoire", "chronicle"):
        prefix = {"map_history": "map", "grimoire": "grimoire", "chronicle": "chronicle"}[case]
        selections = receipt.get("selections", [])
        result = {"open_frame_us": frame(f"{prefix}_open", "first_us"), "idle_max_frame_us": frame(f"{prefix}_idle"),
                  "select_call_us_total": sum(item["call_us"] for item in selections),
                  "select_call_us_max": max((item["call_us"] for item in selections), default=None)}
        for item in selections:
            key = item.get("section", item.get("entry", item.get("record")))
            result[f"select_call_us[{key}]"] = item["call_us"]
    elif case in ("abandon_dragon", "finish_dragon"):
        result = {"abandon_max_frame_us": frame("abandon"), "title_rgba8_bytes": receipt.get("cache_at_title", {}).get("rgba8_bytes")}
    return result


def semantic(case: str, receipt: dict):
    """The parts of a receipt that must match between arms."""
    keys = {"continue_pre_battle": ("pre_battle", "ink_pools"), "arena": ("board",),
            "map_history": ("map_first_frame", "map_first_background", "selections"),
            "grimoire": ("grimoire_first_frame", "selections"), "chronicle": ("chronicle_first_frame", "selections"),
            "abandon_dragon": (), "finish_dragon": ()}[case]
    result = {}
    for key in keys:
        value = receipt.get(key)
        if key == "selections" and value is not None:
            value = [{name: entry[name] for name in entry if name != "call_us"} for entry in value]
        result[key] = value
    # Auto-generated node names ("@Label@545") carry a process-wide counter.
    return json.loads(re.sub(r"@([A-Za-z0-9_]+)@\d+", r"@\1@", json.dumps(result, sort_keys=True)))


def saved_route(project: Path, directory: Path, fixture: str, trace: bool):
    """The review's route: Save and Quit from pre-battle in one process, Continue cold in the next."""
    save = run_take(project, directory / "save", "save_quit_pre_battle", fixture, "normal", trace, storage=directory / "storage")
    return save


def without_texture_class(value):
    """Texel identity: a texture receipt minus its Texture2D subclass."""
    if isinstance(value, dict):
        return {key: without_texture_class(item) for key, item in value.items() if not (key == "class" and "pixels" in value)}
    if isinstance(value, list):
        return [without_texture_class(item) for item in value]
    return value


def counts(output: Path, case: str, fixtures: list[str]):
    arms = projects(output)
    summary = []
    for fixture in fixtures or [""]:
        takes = {}
        saves = {}
        for arm, project in arms.items():
            directory = output / "counts" / case / (fixture.replace(":", "-") or "default") / arm
            storage = None
            if case == "continue_pre_battle":
                saves[arm] = saved_route(project, directory, fixture, True)
                storage = directory / "storage"
            takes[arm] = run_take(project, directory / "take" if storage else directory, case, fixture, "normal", True, storage=storage)
        before, after = takes["baseline"], takes["candidate"]
        same = semantic(case, before) == semantic(case, after)
        texels = without_texture_class(semantic(case, before)) == without_texture_class(semantic(case, after))
        row = {"case": case, "fixture": fixture, "semantic_identical": same, "texel_identical": texels,
               "baseline": {key: before.get(key) for key in ("sync_load_count", "factory_begins", "maquette_fallbacks", "prepared_loads", "errors", "exit")},
               "candidate": {key: after.get(key) for key in ("sync_load_count", "factory_begins", "maquette_fallbacks", "prepared_loads", "errors", "exit")},
               "baseline_loads": [(item["label"], item["path"], item["count"]) for item in before.get("sync_loads", [])],
               "candidate_loads": [(item["label"], item["path"], item["count"]) for item in after.get("sync_loads", [])]}
        if saves:
            row["save_bytes_identical"] = {name: saves["baseline"].get(name) == saves["candidate"].get(name)
                                           for name in saves["baseline"] if name.startswith("sha256:")}
        if case in ("abandon_dragon", "finish_dragon"):
            base_keys = set(before.get("cache_at_title", {}).get("textures", []))
            cand_keys = set(after.get("cache_at_title", {}).get("textures", []))
            row["title_cache"] = {"baseline_only": sorted(base_keys - cand_keys), "candidate_only": sorted(cand_keys - base_keys),
                                  "baseline_bytes": before.get("cache_at_title", {}).get("rgba8_bytes"),
                                  "candidate_bytes": after.get("cache_at_title", {}).get("rgba8_bytes")}
        if not same:
            diff = []
            sb, sa = semantic(case, before), semantic(case, after)
            for key in sb:
                if sb[key] != sa[key]:
                    diff.append(key)
            row["semantic_differences"] = diff
        summary.append(row)
        print(f"PERF164 COUNTS: {case} {fixture} base={row['baseline']['sync_load_count']} cand={row['candidate']['sync_load_count']} "
              f"factory {row['baseline']['factory_begins']}->{row['candidate']['factory_begins']} semantic_identical={same} texel_identical={texels}"
              + (f" saves_identical={row['save_bytes_identical']}" if saves else ""), flush=True)
    path = output / "counts" / f"{case}.json"
    path.write_text(json.dumps(summary, indent=2))
    return summary


def pairs(output: Path, case: str, fixture: str, profile: str, count: int):
    arms = projects(output)
    order = (ORDER * ((count * 2 + len(ORDER) - 1) // len(ORDER)))[: count * 2]
    takes = {"baseline": [], "candidate": []}
    golden = {}
    if case == "continue_pre_battle":
        for arm, project in arms.items():
            directory = output / ("timing-native" if NATIVE else "timing") / case / profile / f"golden-{arm}"
            saved_route(project, directory, fixture, False)
            golden[arm] = directory / "storage"
    for index, letter in enumerate(order):
        arm = "baseline" if letter == "A" else "candidate"
        take = output / ("timing-native" if NATIVE else "timing") / case / profile / f"{index:02d}-{arm}"
        storage = None
        if golden:
            storage = take.with_name(take.name + "-storage")
            shutil.copytree(golden[arm], storage)
        receipt = run_take(arms[arm], take, case, fixture, profile, False, storage=storage)
        if receipt.get("errors") or receipt.get("exit"):
            raise RuntimeError(f"Failed take {take}")
        takes[arm].append(metrics(case, receipt))
    rows = []
    for key in takes["baseline"][0]:
        base = [take[key] for take in takes["baseline"] if take.get(key) is not None]
        cand = [take[key] for take in takes["candidate"] if take.get(key) is not None]
        deltas = [c - b for b, c in zip(base, cand)]
        if not base or not cand:
            continue
        rows.append({"metric": key, "baseline_median_ms": statistics.median(base) / 1000, "candidate_median_ms": statistics.median(cand) / 1000,
                     "paired_delta_median_ms": statistics.median(deltas) / 1000, "paired_delta_min_ms": min(deltas) / 1000,
                     "paired_delta_max_ms": max(deltas) / 1000, "baseline_ms": [value / 1000 for value in base],
                     "candidate_ms": [value / 1000 for value in cand]})
    result = {"case": case, "fixture": fixture, "profile": profile, "order": order, "rows": rows}
    (output / ("timing-native" if NATIVE else "timing") / case / f"{profile}.json").write_text(json.dumps(result, indent=2))
    lines = [f"## {case} {fixture} / {profile} / {'native Metal' if NATIVE else 'headless'} ({count} pairs, {order})", "",
             "| Metric | Base median ms | Candidate median ms | Paired delta median ms | Delta min..max ms |", "|---|---:|---:|---:|---|"]
    for row in rows:
        lines.append(f"| {row['metric']} | {row['baseline_median_ms']:.2f} | {row['candidate_median_ms']:.2f} | {row['paired_delta_median_ms']:+.2f} | "
                     f"{row['paired_delta_min_ms']:+.2f}..{row['paired_delta_max_ms']:+.2f} |")
    (output / ("timing-native" if NATIVE else "timing") / case / f"{profile}.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines), flush=True)
    return result


def pixels(output: Path, case: str, fixture: str):
    """Native strict pixel identity: full frames and the touched controls' regions."""
    arms = projects(output)
    takes = {}
    for arm, project in arms.items():
        directory = output / "pixels" / case / (fixture.replace(":", "-") or "default") / arm
        storage = None
        if case == "continue_pre_battle":
            saved_route(project, directory, fixture, False)
            storage = directory / "storage"
        takes[arm] = run_take(project, directory / "take", case, fixture, "normal", False, timeout=600, storage=storage, capture=True)
    before, after = (takes[arm].get("captures", {}) for arm in ("baseline", "candidate"))
    rows = []
    for name in sorted(before.keys() | after.keys()):
        base, cand = before.get(name, {}), after.get(name, {})
        regions = {key: base.get("regions", {}).get(key, {}).get("sha256") == cand.get("regions", {}).get(key, {}).get("sha256")
                   for key in base.get("regions", {}).keys() | cand.get("regions", {}).keys()}
        rows.append({"capture": name, "full_frame_identical": bool(base) and base.get("sha256") == cand.get("sha256"),
                     "regions_identical": regions, "baseline": base.get("path"), "candidate": cand.get("path")})
        print(f"PERF164 PIXELS {case} {fixture} {name}: full={'IDENTICAL' if rows[-1]['full_frame_identical'] else 'DIFFERENT'} "
              f"regions={regions}", flush=True)
    errors = {arm: takes[arm].get("errors") for arm in takes if takes[arm].get("errors") or takes[arm].get("exit")}
    (output / "pixels" / f"{case}-{fixture.replace(':', '-') or 'default'}.json").write_text(json.dumps({"rows": rows, "errors": errors}, indent=2))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("stage", "counts", "pairs", "pixels"))
    parser.add_argument("--native", action="store_true", help="pairs on the Metal renderer (VSync off) instead of headless")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--case", default="continue_pre_battle")
    parser.add_argument("--fixture", action="append", default=[])
    parser.add_argument("--all-arenas", action="store_true")
    parser.add_argument("--profile", choices=("normal", "background"), default="normal")
    parser.add_argument("--pairs", type=int, default=5)
    args = parser.parse_args()
    output = args.output.resolve()
    global NATIVE
    NATIVE = args.native
    if args.mode == "pixels":
        pixels(output, args.case, args.fixture[0] if args.fixture else "")
    elif args.mode == "stage":
        print(projects(output))
    elif args.mode == "counts":
        counts(output, args.case, ARENAS if args.all_arenas else args.fixture)
    else:
        pairs(output, args.case, args.fixture[0] if args.fixture else "", args.profile, args.pairs)


if __name__ == "__main__":
    main()
