from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from process_quad_art_sheet import split_and_process


ROOT = Path(__file__).resolve().parent
THREAD_IMAGE_DIR = Path("/Users/borgerding/.codex/generated_images/019e76f7-f2d6-79b0-ad1d-3488d7a5af10")
MANIFEST_PATH = ROOT / "source_art" / "imported_quads.json"


def load_manifest() -> dict:
    if not MANIFEST_PATH.exists():
        return {"imports": []}
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def save_manifest(manifest: dict) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def latest_unimported(manifest: dict) -> Path:
    imported = {entry["source"] for entry in manifest.get("imports", [])}
    candidates = sorted(THREAD_IMAGE_DIR.glob("*.png"), key=lambda path: path.stat().st_mtime, reverse=True)
    for candidate in candidates:
        if str(candidate) not in imported:
            return candidate
    raise SystemExit("No unimported generated image found.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quad", required=True, type=int)
    parser.add_argument("--ids", required=True)
    args = parser.parse_args()
    ids = [part.strip() for part in args.ids.split(",") if part.strip()]
    manifest = load_manifest()
    source = latest_unimported(manifest)
    copied = ROOT / "source_art" / f"quad_{args.quad:02d}.png"
    copied.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, copied)
    split_and_process(copied, ids, ROOT / "assets" / "art" / "cards")
    manifest.setdefault("imports", []).append({
        "quad": args.quad,
        "ids": ids,
        "source": str(source),
        "copied_to": str(copied),
    })
    save_manifest(manifest)
    print(copied)


if __name__ == "__main__":
    main()
