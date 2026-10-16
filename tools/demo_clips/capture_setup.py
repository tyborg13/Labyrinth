"""Per-clip startup settings and proof of the renderer actually used."""
from __future__ import annotations

import json
from pathlib import Path
import re

QUALITY = 1.0
OVERRIDE = "\n[editor]\nmovie_writer/mjpeg_quality=1.0\nmovie_writer/video_quality=1.0\n"


def prepare_project(directory, root):
    # Godot 4.6 has no CLI settings-override path. A project view keeps the
    # original project file byte-identical and links the same resources/cache,
    # while its own override.cfg is loaded before MovieWriter construction.
    project = directory / "capture-project"
    project.mkdir(parents=True)
    (project / "project.godot").write_bytes((root / "project.godot").read_bytes())
    original_override = root / "override.cfg"
    original = original_override.read_text() if original_override.exists() else ""
    (project / "override.cfg").write_text(original + OVERRIDE)
    for source in root.iterdir():
        if source.name in {"project.godot", "override.cfg", "output", ".git", ".codex", ".agents"}: continue
        if source.name.startswith(".") and source.name != ".godot": continue
        if source.is_dir() or source.suffix in {".gd", ".tscn", ".tres", ".svg", ".png", ".ttf"}:
            (project / source.name).symlink_to(source.resolve(), target_is_directory=source.is_dir())
    return project


def log_proof(log):
    plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", log)
    headers = [line.strip() for line in plain.splitlines()
               if re.match(r"^Metal\b.* - Forward Mobile(?: -|\s*$)", line.strip())]
    if len(headers) != 1:
        raise ValueError("Capture renderer proof missing: expected Metal … - Forward Mobile")
    snapshots = [json.loads(line.removeprefix("DEMO CAPTURE SETTINGS "))
                 for line in plain.splitlines() if line.startswith("DEMO CAPTURE SETTINGS ")]
    if len(snapshots) != 1: raise ValueError("Capture quality proof missing from Godot log")
    settings = snapshots[0]
    if (settings.get("mjpeg_quality") != QUALITY or settings.get("effective_quality") != QUALITY
            or settings.get("effective_quality_setting") not in
            {"editor/movie_writer/video_quality", "editor/movie_writer/mjpeg_quality"}):
        raise ValueError("Capture MJPEG quality is not verified at 1.0")
    return {"renderer_log": headers[0], "capture_settings": settings}
