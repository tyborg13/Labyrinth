#!/usr/bin/env python3
"""Reduce matched perf-156 loader, first-visit, and capture receipts."""

import argparse
from collections import Counter, defaultdict
import csv
import gzip
import json
from math import ceil
from pathlib import Path
import re
import statistics
import sys

TEXTURE_EXTENSIONS = {".png", ".webp", ".jpg", ".svg", ".ctex"}
BOSSES = {"iskaldra", "noctyrax", "tharokh", "vaeloryx", "vyraketh", "zekarion"}
GUARDIANS = {"ashen_reaver", "craghide", "gallows_roc", "last_lamplighter", "rimejaw", "storm_cantor"}


def texture_path(label):
    path = label.removeprefix("load:")
    return path if Path(path).suffix in TEXTURE_EXTENSIONS else None


def accumulate(target, events):
    for label, entry in events.items():
        path = texture_path(label)
        if path:
            target[path] += entry["total_us"] if isinstance(entry, dict) else entry


def start(directory):
    payload = json.loads((directory / "probe.json").read_text())
    loads = Counter()
    for row in payload["frames"]:
        if row["stage"] != "opening_to_map":
            accumulate(loads, row["loads"])
    return loads


def visits(directory):
    payload = json.loads((directory / "first-visits.json").read_text())
    if payload["errors"]:
        raise ValueError(f"Incomplete first-visit take {directory}: {payload['errors']}")
    loads = {}
    for scope, events in payload["load_scopes"].items():
        loads[scope] = Counter()
        accumulate(loads[scope], events)
    return loads, payload


def tour(directory):
    receipt = json.loads((directory / "receipt.json").read_text())
    if receipt["outcome"] != "tour_complete" or receipt["errors"]:
        raise ValueError(f"Incomplete tour take {directory}: {receipt['outcome']} {receipt['errors']}")
    loads = defaultdict(Counter)
    install_paths = defaultdict(lambda: Counter())
    with (directory / "frames.jsonl").open() as trace:
        header = json.loads(next(trace))
        columns = header["columns"]
        for line in trace:
            row = json.loads(line)
            if isinstance(row, dict):
                continue
            context = row[columns.index("context")]
            phase = context.get("phase", "")
            if phase in {"fixture_install", "tour_open", "tour_visible"}:
                scope = f"{phase}/{context.get('action', '')}"
                events = row[columns.index("events")]
                accumulate(loads[scope], events)
                if phase != "fixture_install":
                    continue
                for label, event in events.items():
                    path = texture_path(label)
                    if not path or not isinstance(event, dict):
                        continue
                    totals = install_paths[context["action"], path]
                    totals["load_us"] += event["total_us"]
                    totals["requests"] += event["count"]
                    totals["godot_cache_hits"] += event.get("godot_cached_at_entry", 0)
                    totals["max_frame_load_us"] = max(totals["max_frame_load_us"], event["total_us"])
    return loads, install_paths


def write_tour_installs(output, base, candidate):
    fields = ("load_us", "requests", "godot_cache_hits", "max_frame_load_us")
    keys = base.keys() | candidate.keys()
    with (output / "tour-installs.csv").open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["fixture", "texture", "delta_load_us",
                         *(f"{side}_{field}" for side in ("base", "candidate") for field in fields)])
        for key in sorted(keys, key=lambda key: (key[0], -abs(candidate[key]["load_us"] - base[key]["load_us"]), key[1])):
            writer.writerow([*key, candidate[key]["load_us"] - base[key]["load_us"],
                             *(side[key][field] for side in (base, candidate) for field in fields)])


def rig_family(path):
    part = path.removeprefix("res://assets/units/").split("/")
    if path.startswith("res://assets/units/guardians/"):
        return part[1]
    if path.startswith("res://assets/units/"):
        return part[0].removesuffix("_cutout")
    return ""


def audit_route(path, sightings, demo):
    """Audit classifications follow the use boundary, even for resources already lazy."""
    name = Path(path).stem
    family = rig_family(path)
    if "/backgrounds/sections/" in path:
        if demo and name != "tharokh":
            return "b", "SectionMapPanel._refresh / SectionTransition._build", "Map or section entry", "current + linked next painting"
        return "a", "SectionMapPanel._refresh / SectionTransition._build", "Map or section entry", "current + linked next painting"
    if "/art/biomes/" in path:
        section = path.split("/")[-2]
        group = "d" if section == "tharokh" or path.endswith("iskaldra/pillar.png") else "b" if demo else "a"
        return group, "BiomeLibrary._asset; CombatBoardView._load_base_floor_assets, _load_biome_prop_assets, _load_loot_and_terrain_assets", "Board", "room biome; Iskaldra pillar also supplies ice terrain"
    if family in BOSSES | GUARDIANS or path.startswith("res://assets/units/guardians/"):
        group = "d" if sightings.get(path) else "a" if sightings.get(family) else "b"
        return group, "CombatBoardView.unit_rig_preparation_manifest; shared rig._texture / RigData.source_texture_manifest", "Encounter actors and alternate facings", "encounter sources; authored parts, meshes and rest textures"
    if family:
        return "d", "RigData.source_texture_manifest; renderer layout/_ready; Board._ensure_unit_assets_for_type", "Board or NPC rig", "active rig JSON, alternate facing/slice or rest artwork"
    if "/art/cards/" in path or "/art/items/" in path or "/art/equipment/" in path:
        return "a/c", "EncounterAssetPreparation.state_texture_manifest; RunLoadingTextureManifest; RunScene._grimoire_entry_icon / ChroniclePanel._build_detail", "Loadout, card/reward/merchant or reference menu", "state, room-specific static warm list or selected menu record"
    if "/art/relics/" in path:
        return "a/c", "RunScene reward choice builder; ChroniclePanel._build_items", "Relic reward or Chronicle", "actual reward or selected run record"
    if "/art/events/" in path:
        return "a", "RunLoadingTextureManifest; EventView._rebuild", "Event", "room event ID; removed fixed Ember Shaft boot entry"
    if "/art/portraits/" in path:
        group = "a" if not demo or name.startswith("craghide") or name.startswith("stoneback") else "b"
        return group, "RunScene TURN_ORDER_PORTRAITS / _combat_portrait_path; RunEndRecapOverlay._apply_model", "Turn order or defeat recap", "encounter roster or recap killer"
    if "/icons/map/" in path or "/art/map/guardians/" in path:
        return "d", "RunInitialCpuAssets._prepare_for; CombatBoardView._load_door_icon_asset; RoomIconLibrary.icon_texture", "Map or board door", "map icons owned by perf-155"
    if "/art/icons/" in path:
        return "d", "CombatBoardView._load_keyword_icon_asset; ActionIconLibrary.icon_texture", "HUD, Skill Tree or inline text", "action/status icon registry; derived glyphs can hide direct submissions"
    if "/ui/graftwright/" in path:
        return "a", "RunLoadingTextureManifest.GRAFT_PANEL_TEXTURES; GraftwrightView._ensure_built", "Graftwright", "committed room travel"
    if "/ui/visual_pass_4/" in path or "/ui/scavenger_shop/" in path:
        return "a", "ScavengerShopView._build_static_scene; ScavengerSignage; ScavengerMaterials; UiSkin", "Merchant or shared UI", "shop chrome and shared style constants"
    if "/art/ui/" in path:
        return "d", "RunScene.initial_texture_preparation_manifest; UiSkin; CardPresentationCache; SectionMapSkin.prepare_initial_assets_for", "HUD, cards or map chrome", "view constants or source textures for derivatives"
    if "/art/props/relic_chest_" in path:
        return "a", "RelicChestProp._draw_part", "Treasure opening", "committed treasure room, lid animation inputs"
    if "/art/npcs/" in path or "/placeholders/units/" in path:
        return "d", "CombatBoardView._ensure_unit_assets_for_type; RunScene._grimoire_entry_icon", "Board fallback, NPC or Grimoire", "selected actor's definition or selected detail"
    if "/art/tiles/campfire_bonfire" in path:
        return "a", "CombatBoardView._initial_asset_jobs / _ensure_scene_prop_assets", "Campfire board", "committed Campfire, idle atlas and static fallback"
    if "/art/tiles/" in path or "/placeholders/tiles/" in path or "/props/" in path:
        return "d", "CombatBoardView._initial_asset_jobs: floor/prop/door/destruction helpers", "Board, animation or derivative atlas", "shared board sources and fallback terrain"
    if "/art/traps/" in path:
        return "d", "CombatBoardView._load_element_trap_assets", "Board trap placement or activation", "element sheets including card-spawned traps"
    if "/art/effects/" in path:
        if "ambient_air_wisp" in name:
            return "b", "CombatBoardView._initial_asset_jobs / _ensure_ambient_combined_atlas", "Ambient board particles", "existing AIR_DECORATIVE_GUSTS_ENABLED gate"
        return "d", "CombatBoardView._initial_asset_jobs / _ensure_ambient_combined_atlas", "Ambient board particles or Blink preview", "combined atlas inputs or make-on-input preview"
    raise ValueError(f"Unclassified audit texture: {path}")


def audit_rows(source, observations, demo_seen):
    with gzip.open(source, "rt", newline="") as stream:
        audit = list(csv.DictReader(stream))
    seen = defaultdict(bool)
    for observation in observations:
        if (observation["driver"].startswith("demo")) != demo_seen:
            continue
        for path, data in observation["textures"].items():
            if data["kinds"]:
                seen[path] = True
                seen[rig_family(path)] = True
    for row in audit:
        path = row["path"]
        family = rig_family(path)
        never_drawn = row["status"] == "no supported draw observed" and int(row["timed_total_us"]) > 1000
        special_rig = family in BOSSES | GUARDIANS or path.startswith("res://assets/units/guardians/")
        if never_drawn or special_rig:
            yield row, audit_route(path, seen, demo_seen)


def rig_inventory(root):
    units = root / "assets/units"
    for folder in sorted(units.iterdir()):
        if folder.name.removesuffix("_cutout") in BOSSES | GUARDIANS or folder.name == "guardians":
            for path in sorted(folder.rglob("*.png")):
                if path.parent.name not in {"front", "rear"}:
                    continue
                yield "res://" + path.relative_to(root).as_posix()


def literal_locations(root):
    locations = defaultdict(list)
    pattern = re.compile(r'res://[^"\s]+\.(?:png|webp|jpg|svg)')
    inputs = [*root.joinpath("scripts").rglob("*.gd"), *root.joinpath("data").rglob("*.json")]
    for file in sorted(inputs):
        for number, line in enumerate(file.read_text().splitlines(), 1):
            for path in pattern.findall(line):
                locations[path].append(f"{file.relative_to(root)}:{number}")
    return locations


def write_audit(output, source, measurement_file, compared):
    with gzip.open(measurement_file, "rt") as stream:
        observations = json.load(stream)["observations"]
    demo = {row["path"]: (row, disposition) for row, disposition in audit_rows(source, observations, True)}
    tour = {row["path"]: disposition for row, disposition in audit_rows(source, observations, False)}
    root = Path(__file__).resolve().parents[2]
    for path in rig_inventory(root):
        if path not in demo:
            demo[path] = ({}, audit_route(path, {"tharokh": True, "craghide": True}, True))
            tour[path] = audit_route(path, {}, False)
    measured = {path for loads in compared.values() for path in loads}
    locations = literal_locations(root)
    with (output / "textures.csv").open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["texture", "audit_status", "archive_inclusive_us", "archive_estimated_one_copy_bytes",
                         "seed7_category", "tour_category", "call_sites", "surface", "manifest_boundary", "literal_references",
                         *compared])
        for path in sorted(demo.keys() | measured):
            row, disposition = demo.get(path, ({}, ("", "", "", "")))
            category, sites, surface, manifest = disposition
            tour_category = tour.get(path, ("", "", "", ""))[0]
            writer.writerow([path, row.get("status", ""), row.get("timed_total_us", ""),
                             row.get("vram_bytes_estimate_one_copy", ""), category, tour_category, sites,
                             surface, manifest, " | ".join(locations[path]),
                             *(loads.get(path, 0) for loads in compared.values())])


def frame_rows(payload):
    grouped = defaultdict(list)
    for frame in payload["frames"]:
        grouped[frame["screen"]].append(frame)
    for screen, rows in sorted(grouped.items()):
        times = sorted(row["ms"] for row in rows)
        yield (screen, len(rows), statistics.median(times), times[ceil(len(times) * 0.95) - 1],
               times[ceil(len(times) * 0.99) - 1], times[-1], sum(ms > 16.67 for ms in times),
               sum(ms > 20 for ms in times), sum(ms > 33 for ms in times),
               sum(row["focused"] is False for row in rows))


def total(loads):
    return sum(loads.values()) / 1000


def compare_pngs(base, candidate):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from visual_probe_runner import decode_png

    files = {path.name for folder in (base, candidate) for path in folder.glob("*.png")}
    identical = bool(files)
    for name in sorted(files):
        left, right = base / name, candidate / name
        if not left.is_file() or not right.is_file():
            print(f"{name}: missing side")
            identical = False
            continue
        a, b = decode_png(left), decode_png(right)
        size = ("width", "height", "channels")
        if any(a[field] != b[field] for field in size):
            print(f"{name}: geometry or format mismatch")
            identical = False
            continue
        channels = a["channels"]
        difference = sum(
            x[i:i + channels] != y[i:i + channels]
            for x, y in zip(a["rows"], b["rows"])
            for i in range(0, len(x), channels)
        )
        print(f"{name}: {difference} differing pixels")
        identical &= difference == 0
    return identical


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path)
    parser.add_argument("--observations", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--start", type=Path, nargs=2, metavar=("BASE", "CANDIDATE"))
    parser.add_argument("--visits", type=Path, nargs=2, metavar=("BASE", "CANDIDATE"))
    parser.add_argument("--tour", type=Path, nargs=2, metavar=("BASE", "CANDIDATE"))
    parser.add_argument("--pixels", type=Path, nargs=2, metavar=("BASE", "CANDIDATE"))
    args = parser.parse_args()
    if args.pixels:
        return 0 if compare_pngs(*args.pixels) else 1
    if args.output is None:
        parser.error("--output is required")
    args.output.mkdir(parents=True, exist_ok=True)
    compared = {}
    tour_installs = []
    for index, side in enumerate(("base", "candidate")):
        if args.start:
            compared[side + "_new_run_us"] = start(args.start[index])
        if args.visits:
            loaded, payload = visits(args.visits[index])
            if payload["capture"]:
                raise ValueError("Capture receipts are excluded from timing comparisons")
            print(f"{side} first visits, {payload['display']}, {payload['renderer']}, {payload['cpu']}")
            print(f"peak/post-teardown texture bytes: {payload['peak_texture_bytes']}/{payload['post_teardown_texture_bytes']}")
            print(f"post-teardown AssetLoader path count: {payload['post_teardown_asset_cache_paths']}")
            print("screen, frames, median_ms, p95_ms, p99_ms, max_ms, over_16.67, over_20, over_33, unfocused")
            for row in frame_rows(payload):
                print(", ".join(f"{value:.3f}" if isinstance(value, float) else str(value) for value in row))
            for scope, paths in loaded.items():
                compared[f"{side}_{scope}_us"] = paths
            compared[f"{side}_section_entries_us"] = sum(
                (paths for scope, paths in loaded.items() if scope.startswith("section-") and scope.endswith("-entry")),
                Counter(),
            )
            compared[f"{side}_section_entry_covers_us"] = sum(
                (paths for scope, paths in loaded.items() if scope.startswith("section-") and scope.endswith("-cover")),
                Counter(),
            )
        if args.tour:
            loaded, install_paths = tour(args.tour[index])
            tour_installs.append(install_paths)
            for scope, paths in loaded.items():
                compared[f"{side}_tour_{scope}_us"] = paths
            compared[f"{side}_tour_install_us"] = sum(
                (paths for scope, paths in loaded.items() if scope.startswith("fixture_install/")), Counter()
            )

    print("scope, base_inclusive_load_ms, candidate_inclusive_load_ms, percent_reduction")
    for key, paths in sorted(compared.items()):
        if not key.startswith("base_"):
            continue
        scope = key.removeprefix("base_")
        other = compared.get("candidate_" + scope)
        if other is not None:
            before, after = total(paths), total(other)
            delta = f"{100 * (1 - after / before):.1f}" if before else "n/a"
            print(f"{scope}, {before:.3f}, {after:.3f}, {delta}")
    if args.audit and args.observations:
        write_audit(args.output, args.audit, args.observations, compared)
        print(args.output / "textures.csv")
    if tour_installs:
        write_tour_installs(args.output, *tour_installs)
        print(args.output / "tour-installs.csv")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
