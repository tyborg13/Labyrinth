from __future__ import annotations

from pathlib import Path
import shutil

from .common import PipelineError, read_json, sha256
from .verify import require_promotion_ready, verify_track


def promote_track(config_path: Path, output_dir: Path | None, asset_path: Path) -> dict[str, object]:
    config_path = config_path.resolve()
    output_dir = output_dir.resolve() if output_dir else None
    config = read_json(config_path)
    approval = require_promotion_ready(config, config_path)
    verification = verify_track(config_path, output_dir)
    render = config.get("render")
    if not isinstance(render, dict):
        raise PipelineError("render must be an object")
    source_dir = output_dir or config_path.parent
    preview = source_dir / f"{render['output_basename']}.ogg"
    destination = asset_path.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if sha256(destination) != sha256(preview):
            raise PipelineError(f"Refusing to overwrite a different game asset: {destination}")
    else:
        shutil.copyfile(preview, destination)
    return {
        "ok": True,
        "asset_path": str(destination),
        "sha256": sha256(destination),
        "approval": approval,
        "verification": verification,
    }
