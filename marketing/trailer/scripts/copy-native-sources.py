#!/usr/bin/env python3
"""Copy or restore a portable native source bank, verifying every retained file."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from source_lock import source_lock


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--reviewed-source-head", help="Final reviewed commit; captured script bytes must match this commit")
    args = parser.parse_args()
    source, destination = args.source.resolve(), args.destination.resolve()
    if source == destination:
        raise ValueError("Choose a separate archive or restoration destination")
    with source_lock(source), source_lock(destination):
        paths: list[Path] = []
        origins: dict = {}
        repo = Path(__file__).resolve().parents[3]
        clips: list[str] = []
        for cue_path in sorted(source.glob("*.cues.json")):
            cue = json.loads(cue_path.read_text())
            clip = cue["clip"]
            origins[clip] = cue["capture_origin"]
            if args.reviewed_source_head:
                for relative, expected in origins[clip]["captured_script_sha256"].items():
                    data = subprocess.check_output(["git", "show", f"{args.reviewed_source_head}:{relative}"], cwd=repo)
                    if hashlib.sha256(data).hexdigest() != expected:
                        raise RuntimeError(f"{clip}: captured {relative} differs from reviewed source HEAD")
            native = cue["lossless"]
            if native["pattern"] != f"{clip}/frame%08d.png" or native["audio"] != f"{clip}.wav":
                raise RuntimeError(f"{clip}: source references must be portable and relative")
            folder = source / clip
            proof_path = folder / "native-rgb-framemd5.json"
            proof = json.loads(proof_path.read_text())
            images = sorted(folder.glob("frame????????.png"))
            if len(images) != native["raw_frames"] or [sha(p) for p in images] != proof["png_srgb_sha256"]:
                raise RuntimeError(f"{clip}: current native PNGs differ from their verified source proof")
            paths += [cue_path, proof_path, source / f"{clip}.wav", source / f"{clip}.capture.log", *images]
            clips.append(clip)
        if not clips:
            raise RuntimeError("No verified native source collection found")
        files = {str(path.relative_to(source)): sha(path) for path in paths}
        collection_hash = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
        existing = destination / "native-collection.json"
        if existing.exists() and json.loads(existing.read_text())["collection_sha256"] != collection_hash:
            raise RuntimeError("Destination contains a different source bank; choose a new versioned destination")
        for path in paths:
            relative = path.relative_to(source)
            target = destination / relative
            if target.exists() and sha(target) != files[str(relative)]:
                raise RuntimeError(f"Destination has a different file: {relative}")
        for path in paths:
            target = destination / path.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                shutil.copy2(path, target)
            if sha(target) != files[str(path.relative_to(source))]:
                raise RuntimeError(f"Copy verification failed: {target}")
        repo = Path(__file__).resolve().parents[3]
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
        dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=repo, text=True).strip())
        manifest = {"collection_sha256": collection_hash, "clips": clips, "files_sha256": files, "capture_origins": origins, "reviewed_source_head": args.reviewed_source_head, "archive_tool_repository_head": head, "archive_tool_repository_dirty_at_copy": dirty, "restore": "Run this script with the archive as source and the next task's marketing/trailer/public/footage/lossless as destination, then run npm run render in marketing/trailer. All cue references are relative and remain byte-identical."}
        existing.write_text(json.dumps(manifest, indent=2) + "\n")
        print(json.dumps({"destination": str(destination), "clips": clips, "files": len(files), "collection_sha256": collection_hash, "copied_bytes_verified": True}, indent=2))

if __name__ == "__main__":
    main()
