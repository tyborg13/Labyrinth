#!/usr/bin/env python3
"""Exercise real archive/restore commands with two reviewed capture revisions."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

SCRIPTS = Path(__file__).resolve().parent


def run(args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def main():
    with tempfile.TemporaryDirectory(prefix="umbra-native-archive-") as temporary:
        repo = Path(temporary) / "repo"
        scripts = repo / "marketing/trailer/scripts"
        scripts.mkdir(parents=True)
        for name in ["copy-native-sources.py", "source_lock.py"]:
            shutil.copy2(SCRIPTS / name, scripts / name)
        run(["git", "init", "-q"], repo)
        actor = repo / "capture.gd"
        actor.write_text("reviewed capture revision one\n")
        run(["git", "add", "capture.gd"], repo)
        run(["git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "First fixture"], repo)
        first = run(["git", "rev-parse", "HEAD"], repo)
        first_digest = hashlib.sha256(actor.read_bytes()).hexdigest()
        actor.write_text("reviewed capture revision two\n")
        run(["git", "add", "capture.gd"], repo)
        run(["git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "Second fixture"], repo)
        second = run(["git", "rev-parse", "HEAD"], repo)
        second_digest = hashlib.sha256(actor.read_bytes()).hexdigest()
        source = Path(temporary) / "source"

        def fixture(clip, digest):
            folder = source / clip
            folder.mkdir(parents=True, exist_ok=True)
            # This test exercises verified byte transfer, not media decoding.
            image = folder / "frame00000000.png"
            image.write_bytes(b"synthetic RGB fixture")
            proof = {"png_srgb_sha256": [hashlib.sha256(image.read_bytes()).hexdigest()]}
            (folder / "native-rgb-framemd5.json").write_text(json.dumps(proof))
            cue = {"clip": clip, "capture_origin": {"repository_head": first, "repository_dirty": True, "captured_script_sha256": {"capture.gd": digest}}, "lossless": {"pattern": f"{clip}/frame%08d.png", "audio": f"{clip}.wav", "raw_frames": 1}}
            (source / f"{clip}.cues.json").write_text(json.dumps(cue))
            (source / f"{clip}.wav").write_bytes(b"synthetic PCM fixture")
            (source / f"{clip}.capture.log").write_text("archive transfer fixture\n")

        def copy(src, dst, head=None):
            args = ["python3", str(scripts / "copy-native-sources.py"), str(src), str(dst)]
            if head:
                args += ["--reviewed-source-head", head]
            return subprocess.run(args, capture_output=True, text=True)

        fixture("unchanged", first_digest)
        fixture("recaptured", first_digest)
        old_archive = Path(temporary) / "old-archive"
        assert copy(source, old_archive, first).returncode == 0
        # Restore archive metadata into the working bank, then replace one scene.
        shutil.copy2(old_archive / "native-collection.json", source / "native-collection.json")
        fixture("recaptured", second_digest)
        mixed = Path(temporary) / "mixed-archive"
        result = copy(source, mixed, second)
        assert result.returncode == 0, result.stderr
        manifest = json.loads((mixed / "native-collection.json").read_text())
        assert manifest["reviewed_source_head"] == second
        assert manifest["reviewed_capture_heads"] == {"unchanged": first, "recaptured": second}
        assert manifest["capture_origins"]["recaptured"]["repository_head"] == first
        restored = Path(temporary) / "restored"
        result = copy(mixed, restored)
        assert result.returncode == 0, result.stderr
        final = json.loads((restored / "native-collection.json").read_text())
        for key in ["reviewed_source_head", "reviewed_capture_heads", "capture_origins", "files_sha256", "collection_sha256"]:
            assert manifest[key] == final[key], key
        print("PASS: mixed-origin archive and restore preserve verified per-clip HEADs, original origins and all bytes")
        fixture("recaptured", "0" * 64)
        rejection = copy(source, Path(temporary) / "bad", second)
        assert rejection.returncode != 0 and "match neither" in rejection.stderr
        print("PASS: changed clip matching neither reviewed binding is rejected")
        (restored / "unchanged.wav").write_bytes(b"conflicting destination")
        rejection = copy(mixed, restored)
        assert rejection.returncode != 0 and "different file" in rejection.stderr
        print("PASS: conflicting restoration destination is rejected")


if __name__ == "__main__":
    main()
