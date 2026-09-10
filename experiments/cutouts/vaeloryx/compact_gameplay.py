"""Package native gameplay proof after its complete timed reels pass decoding."""
from pathlib import Path
import argparse
import hashlib
import json


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compact(root, raw):
    assert root.resolve() != raw.resolve(), "Preserve the original native capture"
    assert not (root / "source_frame_sha256.json").exists(), "Already packaged"
    manifest = json.loads((root / "manifest.json").read_text())
    encoding = json.loads((root / "videos/encoding.json").read_text())
    assert encoding["full_decode"] == "PASS"
    assert len(encoding["clips"]) == len(manifest["clips"])
    frames = {}
    for clip in manifest["clips"]:
        folder = root / clip["label"]
        assert folder.resolve().parent == root.resolve()
        for file in sorted(folder.glob("frame_*.jpg")):
            relative = str(file.relative_to(root))
            sha = digest(file)
            assert digest(raw / relative) == sha, relative
            frames[relative] = sha
    # These are duplicate encoding inputs. The untouched native capture stays
    # in its runner-owned HOME. Reels retain the full sequence and its timing;
    # original PNG stills, analytics and sample records remain in this package.
    report = {
        "source_root": str(raw),
        "sha256": frames,
        "retention": "Duplicate JPEG encoding inputs omitted from the branch after source-byte equality and full reel decoding passed. Untouched originals remain in the runner capture directory. Full-resolution native PNGs, all timed clip videos, sample timestamps, analytics and reconstruction commands are retained here.",
    }
    (root / "source_frame_sha256.json").write_text(json.dumps(report, indent=2) + "\n")
    for relative in frames:
        (root / relative).unlink()
    return len(frames)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    runner = json.loads((args.output / "native_runner.json").read_text())
    raw = Path(runner["images"][0]["path"]).parent
    while not (raw / "manifest.json").exists():
        assert raw != raw.parent
        raw = raw.parent
    count = compact(args.output, raw)
    hashes = {str(p.relative_to(args.output)): digest(p) for p in sorted(args.output.rglob("*")) if p.is_file() and p.name != "proof_sha256.json"}
    (args.output / "proof_sha256.json").write_text(json.dumps(hashes, indent=2) + "\n")
    print("Packaged", count, "native source frames into verified timed reels")
