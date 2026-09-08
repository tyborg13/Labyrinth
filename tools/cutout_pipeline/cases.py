from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
ID = re.compile(r"[a-z][a-z0-9_]*\Z")


class CutoutError(ValueError):
    pass


def read_json(path: Path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as error:
        raise CutoutError(f"Cannot read JSON {path}: {error}") from error


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + "\n")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fresh_directory(path: Path) -> Path:
    path = path.resolve()
    if path.exists():
        raise CutoutError(f"Output already exists; choose a new case/version: {path}")
    path.mkdir(parents=True)
    return path


def local_path(root: Path, value: str) -> Path:
    if not isinstance(value, str) or not value or Path(value).is_absolute() or "://" in value:
        raise CutoutError(f"Expected a case-relative path, got {value!r}")
    path = (root / value).resolve()
    if not path.is_relative_to(root.resolve()):
        raise CutoutError(f"Path escapes the case: {value}")
    return path


def load_case(path: Path) -> tuple[Path, dict]:
    path = path.resolve()
    if path.is_dir():
        path /= "cutout.json"
    config = read_json(path)
    if not isinstance(config, dict) or config.get("schema_version") != 1:
        raise CutoutError("Expected cutout.json with schema_version 1")
    return path, config


def image_records(layout: dict):
    yield from layout.get("parts", [])
    yield from layout.get("joint_meshes", [])
    if layout.get("cape_mesh"):
        yield layout["cape_mesh"]


def runtime_paths(case: Path) -> tuple[Path, dict, set[Path]]:
    path, config = load_case(case)
    root = path.parent
    paths = {path, local_path(root, config["motion"])}
    for relative in config["layouts"].values():
        layout_path = local_path(root, relative)
        paths.add(layout_path)
        layout = read_json(layout_path)
        for item in image_records(layout):
            paths.add(local_path(root, item["file"]))
        if layout.get("rest_source"):
            paths.add(local_path(root, layout["rest_source"]))
    for relative in config.get("sources", []):
        paths.add(local_path(root, relative))
    return path, config, paths


def case_hashes(case: Path) -> dict[str, str]:
    path, _, paths = runtime_paths(case)
    return {str(p.relative_to(path.parent)): digest(p) for p in sorted(paths)}


def baseline(case: Path) -> None:
    path, _ = load_case(case)
    write_json(path.parent / "baseline.sha256.json", case_hashes(case))


def init_case(output: Path, character: str, facings: list[str]) -> Path:
    if not ID.fullmatch(character) or not facings or any(not ID.fullmatch(x) for x in facings) or len(set(facings)) != len(facings):
        raise CutoutError("Character and unique facing ids use lowercase snake_case")
    root = fresh_directory(output)
    config = {
        "schema_version": 1, "character_id": character, "source_size": [255, 255],
        "canvas_size": [512, 512], "source_offset": [128, 128],
        "default_facing": facings[0], "layouts": {f: f"layouts/{f}.json" for f in facings},
        "motion": "motion.gd", "clips": {"idle": {"frames": 24, "duration": 1.0, "loop": True, "preview_cycles": 2}},
        "rigid_bones": [], "contact_feet": [], "sources": [],
        "source_baseline": {"kind": "new_character", "art_status": "unbuilt"},
    }
    for facing in facings:
        write_json(root / config["layouts"][facing], {
            "version": 1, "facing": facing, "canvas_size": [255, 255],
            "joints": {"root": {"parent": None, "position": [128, 211]}},
            "parts": [], "joint_meshes": [],
        })
    shutil.copyfile(PROJECT / "tools/cutout_pipeline/rest_motion.gd", root / "motion.gd")
    write_json(root / "cutout.json", config)
    return root / "cutout.json"


def _renderer_constant(text: str, name: str) -> float:
    match = re.search(rf"^const {re.escape(name)}: (?:float|int) = ([0-9.]+)$", text, re.MULTILINE)
    if not match:
        raise CutoutError(f"Cannot snapshot current {name}; update the timing adapter for the changed renderer")
    return float(match[1])


def seed_protagonist(output: Path, character: str) -> Path:
    if not ID.fullmatch(character):
        raise CutoutError("Character id uses lowercase snake_case")
    renderer = (PROJECT / "scripts/protagonist_cutout/renderer.gd").read_text()
    idle = _renderer_constant(renderer, "IDLE_CYCLE_SECONDS")
    walk = _renderer_constant(renderer, "WALK_CYCLE_SECONDS")
    frames = int(_renderer_constant(renderer, "MELEE_FRAMES"))
    # The renderer declares the frame tick as 1.0 / 60.0; fail visibly if its
    # expression changes rather than quietly carrying a stale timing snapshot.
    tick = re.search(r"^const MELEE_FRAME_SECONDS: float = 1\.0 / ([0-9.]+)$", renderer, re.MULTILINE)
    if "static func attack_pose_phase(" not in renderer:
        raise CutoutError("Cannot snapshot the current attack playback mapping")
    phase_function = renderer.split("static func attack_pose_phase(", 1)[1].split("static func ", 1)[0]
    curve = [[float(a), float(b)] for a, b in re.findall(r"Vector2\(([0-9.]+), ([0-9.]+)\)", phase_function)]
    if tick is None or len(curve) < 2:
        raise CutoutError("Cannot snapshot the current attack playback mapping")
    root = fresh_directory(output)
    config = {
        "schema_version": 1, "character_id": character, "source_size": [255, 255],
        "canvas_size": [512, 512], "source_offset": [128, 128], "default_facing": "front",
        "layouts": {f: f"layouts/{f}.json" for f in ["front", "rear"]}, "motion": "motion.gd",
        "clips": {
            "idle": {"frames": max(2, round(idle * 25)), "duration": idle, "loop": True, "preview_cycles": 2},
            "walk": {"frames": max(2, round(walk * 60)), "duration": walk, "loop": True, "preview_cycles": 3, "travel": "motion"},
            "attack": {"frames": frames, "duration": frames / float(tick[1]), "loop": False, "phase_curve": curve},
        },
        "rigid_bones": ["foot_r", "foot_l"], "contact_feet": ["foot_r", "foot_l"], "sources": [],
        "source_baseline": {"kind": "protagonist_production", "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True).strip(), "files": {}},
    }
    source_files: set[Path] = {PROJECT / "scripts/protagonist_cutout/motion.gd", PROJECT / "scripts/protagonist_cutout/renderer.gd", PROJECT / "scripts/protagonist_cutout/rig.gd"}
    copied: dict[Path, str] = {}
    def copy_image(value: str) -> str:
        source = PROJECT / value.removeprefix("res://")
        if source not in copied:
            relative = "assets/" + str(source.relative_to(PROJECT / "assets/units/protagonist_cutout"))
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            Path(str(target) + ".import").write_text('[remap]\n\nimporter="keep"\n')
            copied[source] = relative
            source_files.add(source)
        return copied[source]
    for facing, destination in config["layouts"].items():
        source = PROJECT / f"assets/units/protagonist_cutout/{facing}.json"
        source_files.add(source)
        layout = read_json(source)
        for item in image_records(layout):
            item["file"] = copy_image(item["file"])
        layout["rest_source"] = copy_image(layout["rest_source"])
        write_json(root / destination, layout)
    shutil.copyfile(PROJECT / "scripts/protagonist_cutout/motion.gd", root / "motion.gd")
    config["source_baseline"]["files"] = {str(p.relative_to(PROJECT)): digest(p) for p in sorted(source_files)}
    write_json(root / "cutout.json", config)
    baseline(root)
    return root / "cutout.json"


def fork_case(source: Path, output: Path, character: str) -> Path:
    if not ID.fullmatch(character):
        raise CutoutError("Character id uses lowercase snake_case")
    path, config, files = runtime_paths(source)
    # Resolve inputs before creating output. Copy only the runtime/source closure;
    # previews and prior fork trees cannot recursively balloon the new variant.
    for file in files:
        if not file.is_file():
            raise CutoutError(f"Missing case input: {file}")
    root = fresh_directory(output)
    for file in files:
        destination = root / file.relative_to(path.parent)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, destination)
        if file.suffix == ".png":
            Path(str(destination) + ".import").write_text('[remap]\n\nimporter="keep"\n')
    config["character_id"] = character
    config["source_baseline"] = {"kind": "case_fork", "character_id": config.get("source_baseline", {}).get("character_id", read_json(path)["character_id"]), "files": case_hashes(path)}
    write_json(root / "cutout.json", config)
    baseline(root)
    return root / "cutout.json"
