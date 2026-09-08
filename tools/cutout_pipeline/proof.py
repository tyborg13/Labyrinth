from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from fractions import Fraction
from pathlib import Path

from .cases import CutoutError, PROJECT, case_hashes, digest, fresh_directory, load_case, local_path, read_json, write_json
from .validation import validate


def input_hashes(case: Path) -> dict[str, str]:
    result = {"case:" + p: sha for p, sha in case_hashes(case).items()}
    paths = {PROJECT / "project.godot", PROJECT / "tools/cutout_workflow.py"}
    # Include the board/rendering dependency closure, including dynamic art paths.
    # Audio is not part of this silent character study.
    for folder, extensions in [("scripts", {".gd"}), ("tools/cutout_pipeline", {".gd", ".py"}), ("scenes", {".tscn"}), ("data", {".json"}), ("shaders", {".gdshader"}), ("assets", {".png", ".ttf", ".otf", ".json", ".res"})]:
        paths.update(p for p in (PROJECT / folder).rglob("*") if p.is_file() and p.suffix in extensions)
    result.update({"project:" + str(p.relative_to(PROJECT)): digest(p) for p in sorted(paths)})
    return result


def pack(output: Path, ffmpeg: str = "ffmpeg") -> dict:
    manifest = read_json(output / "render_manifest.json")
    if manifest.get("errors"):
        raise CutoutError("Cannot pack failed native proof")
    if not shutil.which(ffmpeg):
        raise CutoutError("ffmpeg is required for the preview reel")
    ffprobe = str(Path(shutil.which(ffmpeg)).with_name("ffprobe"))
    if not Path(ffprobe).is_file():
        ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        raise CutoutError("ffprobe (included with ffmpeg) is required to verify playback duration")
    video_root = fresh_directory(output / "videos")
    clips = []
    for record in manifest["clips"]:
        folder = output / record["folder"]
        fps = Fraction(1 / record["frame_seconds"]).limit_denominator(100000)
        video = video_root / (record["folder"] + ".mp4")
        subprocess.run([ffmpeg, "-v", "error", "-y", "-framerate", str(fps), "-i", str(folder / "board_%04d.jpg"), "-an", "-vf", "fps=60", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)], check=True)
        metadata = json.loads(subprocess.check_output([ffprobe, "-v", "error", "-select_streams", "v:0", "-count_frames", "-show_entries", "stream=nb_read_frames,avg_frame_rate,width,height", "-of", "json", str(video)], text=True))["streams"][0]
        source_seconds = record["frames"] * record["frame_seconds"]
        encoded_frames = int(metadata["nb_read_frames"])
        encoded_seconds = encoded_frames / float(Fraction(metadata["avg_frame_rate"]))
        if abs(encoded_seconds - source_seconds) > 1 / 60 + 0.000001:
            raise CutoutError(f"Encoded clip duration differs from authored playback: {video}")
        clips.append({"file": str(video.relative_to(output)), "source_frames": record["frames"], "source_seconds": source_seconds, "encoded_frames": encoded_frames, "encoded_seconds": encoded_seconds, "duration_error_seconds": encoded_seconds - source_seconds})
    concat = video_root / "clips.ffconcat"
    concat.write_text("ffconcat version 1.0\n" + "".join("file '" + Path(c["file"]).name.replace("'", "'\\''") + "'\n" for c in clips))
    reel = video_root / "cutout_review.mp4"
    subprocess.run([ffmpeg, "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(concat), "-c", "copy", "-movflags", "+faststart", str(reel)], check=True)
    subprocess.run([ffmpeg, "-v", "error", "-i", str(reel), "-f", "null", "-"], check=True)
    report = {"clips": clips, "reel": str(reel.relative_to(output)), "timing": "Case-declared playback speed; 60fps frame repetition, no synthesized poses; per-clip boundary rounding is at most one 60fps frame", "full_decode": "PASS", "source_seconds": sum(c["source_seconds"] for c in clips), "encoded_seconds": sum(c["encoded_seconds"] for c in clips)}
    write_json(video_root / "encoding.json", report)
    return report


def render(case: Path, output: Path, task_id: str | None, godot: str, backend: str | None, ffmpeg: str) -> dict:
    validation = validate(case)
    if not validation["ok"]:
        raise CutoutError("; ".join(validation["errors"]))
    path, config = load_case(case)
    if output.exists():
        raise CutoutError("Proof output already exists; choose a fresh version")
    before = input_hashes(path)
    frame_count = sum(c["frames"] * c.get("preview_cycles", 1) for c in config["clips"].values()) * len(config["layouts"])
    # Known capture behavior: two native frames + synchronous image writes for
    # each authored sample. Startup remains covered by the runner's watchdog.
    timeout = max(60, round(frame_count * 0.20 + 30))
    with tempfile.TemporaryDirectory(prefix="labyrinth-cutout-probe-") as scratch:
        result_path = Path(scratch) / "visual_result.json"
        command = [sys.executable, str(PROJECT / "tools/visual_probe_runner.py"), "tools/cutout_pipeline/preview.gd", "--project", str(PROJECT), "--godot", godot, "--no-headless", "--expect-size", "1920x1080", "--expect-size", "512x512", "--timeout", str(timeout), "--result-manifest", str(result_path)]
        if task_id:
            command += ["--task-id", task_id]
        if backend:
            command += ["--rendering-method", "mobile", "--rendering-driver", backend]
        command += ["--", "--case", str(path)]
        process = subprocess.run(command, cwd=PROJECT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if process.returncode:
            raise CutoutError("Native preview failed:\n" + process.stdout[-16000:])
        result = read_json(result_path)
        if not result.get("ok"):
            raise CutoutError("Native preview was not accepted")
        if input_hashes(path) != before:
            raise CutoutError("Case or rendering inputs changed during capture; run fresh proof")
        raw = next((Path(i["path"]).parent for i in result["images"] if Path(i["path"]).name == "keyboard_focus.png"), None)
        if raw is None or not (raw / "render_manifest.json").exists():
            raise CutoutError("Native result lacks its complete render manifest")
        root = fresh_directory(output)
        shutil.copytree(raw, root, dirs_exist_ok=True)
        (root / "native_probe.log").write_text(process.stdout)
        for item in result["images"]:
            item["path"] = str(Path(item["path"]).relative_to(raw))
        for attempt in result["attempts"]:
            for item in attempt.get("images", []):
                item["path"] = str(Path(item["path"]).relative_to(raw))
        write_json(root / "visual_probe_result.json", result)
        write_json(root / "capture_input_sha256.json", before)
        write_json(root / "case_validation.json", validation)
    encoding = pack(root, ffmpeg)
    write_json(root / "proof_sha256.json", {str(p.relative_to(root)): digest(p) for p in sorted(root.rglob("*")) if p.is_file() and p.name != "proof_sha256.json"})
    verification = verify_render(path, root)
    return {"ok": verification["ok"], "output": str(root), "preview": str(root / encoding["reel"]), "authored_frames": frame_count, "verification": verification}


def verify_render(case: Path, output: Path) -> dict:
    errors = []
    inputs = read_json(output / "capture_input_sha256.json")
    actual = input_hashes(case)
    for path in sorted(inputs.keys() | actual.keys()):
        if inputs.get(path) != actual.get(path):
            errors.append("Changed capture input: " + path)
    expected = read_json(output / "proof_sha256.json")
    for relative, sha in expected.items():
        file = local_path(output, relative)
        if not file.is_file() or digest(file) != sha:
            errors.append("Changed/missing proof output: " + relative)
    native = read_json(output / "render_manifest.json")
    if native.get("errors") or not native.get("roundtrip") or not all(r["pixel_identical"] for r in native["roundtrip"]):
        errors.append("Native render or editable-scene roundtrip did not pass")
    return {"ok": not errors, "inputs": len(inputs), "outputs": len(expected), "errors": errors}


def inspect(case: Path, task_id: str | None, godot: str) -> int:
    report = validate(case)
    if not report["ok"]:
        raise CutoutError("; ".join(report["errors"]))
    path, _ = load_case(case)
    command = [sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--project", str(PROJECT), "--timeout", "0", "--stream"]
    if task_id:
        command += ["--task-id", task_id]
    command += ["--", godot, "--path", str(PROJECT), "--script", "tools/cutout_pipeline/preview.gd", "--", "--case", str(path), "--interactive"]
    return subprocess.call(command, cwd=PROJECT)
