#!/usr/bin/env python3
"""Render the approved edit from native RGB/PCM and export a lossless archive plus Steam MP4."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
from source_lock import source_lock

ROOT = Path(__file__).resolve().parents[1]
FPS = 30
FRAMES = 1219
REQUIRED = {"push_bloom": 352, "spell": 228, "route": 50, "merchant": 216, "equipment": 190, "root_chain": 363}


def run(args: list[str], log: Path | None = None) -> str:
    if log:
        with log.open("w") as output:
            subprocess.run(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, check=True)
        return ""
    return subprocess.check_output(args, cwd=ROOT, text=True)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rgb_hashes(inputs: list[str]) -> list[str]:
    output = run(["ffmpeg", "-v", "error", *inputs, "-map", "0:v:0", "-pix_fmt", "rgb24", "-f", "framemd5", "-"])
    return [line.rsplit(",", 1)[-1].strip() for line in output.splitlines() if not line.startswith("#")]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", default="footage/lossless")
    parser.add_argument("--version", default="v5", help="Version label for the output directory and deliverables")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--reuse-render", action="store_true", help="Reuse an already rendered PNG/PCM edit in this output directory")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.version):
        parser.error("version must contain only letters, digits, underscores or hyphens")
    if args.out is None:
        args.out = ROOT / "out" / f"quality-{args.version}"
    with source_lock(ROOT / "public" / args.source_root):
        export(args)


def export(args: argparse.Namespace) -> None:
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sources: dict = {}
    for clip, required in REQUIRED.items():
        source = ROOT / "public" / args.source_root
        cues = json.loads((source / f"{clip}.cues.json").read_text())
        native = cues["lossless"]
        if not native["round_trip_rgb_exact"] or native["raw_frames"] < required or native["source_frame_offset"] != 0:
            raise RuntimeError(f"{clip}: native frame coverage/round-trip proof is insufficient")
        if cues["audio"]["duration_seconds"] < required / FPS - 1 / FPS:
            raise RuntimeError(f"{clip}: native sound does not cover the approved audio cut")
        capture_proof = json.loads((source / clip / "native-rgb-framemd5.json").read_text())
        recorded = capture_proof["rgb_frame_md5"]
        current_png_sha256 = [sha(path) for path in sorted((source / clip).glob("frame????????.png"))]
        if current_png_sha256 != capture_proof["png_srgb_sha256"]:
            raise RuntimeError(f"{clip}: current native PNG bytes/profile differ from the verified capture")
        actual = rgb_hashes(["-framerate", "30", "-i", str(source / clip / "frame%08d.png")])
        if actual != recorded or len(actual) != native["raw_frames"]:
            raise RuntimeError(f"{clip}: current PNG pixels do not match the verified native RGB capture")
        sources[clip] = {"cues_sha256": sha(source / f"{clip}.cues.json"), "pcm_sha256": sha(source / f"{clip}.wav"), "native_frame_hashes_sha256": sha(source / clip / "native-rgb-framemd5.json"), "raster": [native["native_width"], native["native_height"]]}
    props = out / "render-props.json"
    props.write_text(json.dumps({"nativeSourceRoot": args.source_root}) + "\n")
    images = out / "frames"
    audio = out / "edit-pcm.wav"
    dependency_paths = sorted((ROOT / "src").glob("**/*"))
    dependency_paths += [ROOT / "remotion.config.ts", ROOT / "package-lock.json"]
    dependency_paths += sorted((ROOT / "public/title-cards").glob("*.png"))
    dependency_paths += [ROOT / "public/branding/steam-logo-inverse-transparent.png", ROOT / "public/game-assets/art/ui/main_menu_umbra_dragon.png", ROOT / "public/game-assets/audio/music/zekarion_boss.wav"]
    dependencies = {str(path.relative_to(ROOT)): sha(path) for path in dependency_paths if path.is_file()}
    fingerprint_payload = {"sources": sources, "dependencies": dependencies, "props": json.loads(props.read_text()), "frames": FRAMES, "fps": FPS}
    fingerprint = hashlib.sha256(json.dumps(fingerprint_payload, sort_keys=True).encode()).hexdigest()
    binding_path = out / "render-input-binding.json"
    if args.reuse_render:
        binding = json.loads(binding_path.read_text())
        if binding["input_fingerprint"] != fingerprint:
            raise RuntimeError("Cached render inputs differ from the current native sources/editor/assets")
        current_files = {path.name: sha(path) for path in sorted(images.glob("frame*.png"))}
        if current_files != binding["rendered_png_sha256"] or sha(audio) != binding["rendered_pcm_sha256"]:
            raise RuntimeError("Cached PNG/PCM render differs from its verified input binding")
    else:
        common = ["npx", "remotion", "render", "EscapeTheUmbraTrailer"]
        flags = ["--props", str(props), "--concurrency=1", "--timeout=60000"]
        run([*common, str(images.relative_to(ROOT)), "--sequence", "--image-format=png", "--image-sequence-pattern=frame[frame].[ext]", "--muted", *flags], out / "render-frames.log")
        run([*common, str(audio), "--codec=wav", "--audio-codec=pcm-16", "--sample-rate=48000", *flags], out / "render-audio.log")
    frames = sorted(images.glob("frame*.png"))
    if len(frames) != FRAMES:
        raise RuntimeError(f"The approved edit must contain exactly {FRAMES} frames, got {len(frames)}")
    if not args.reuse_render:
        binding_path.write_text(json.dumps({"input_fingerprint": fingerprint, "inputs": fingerprint_payload, "rendered_png_sha256": {path.name: sha(path) for path in frames}, "rendered_pcm_sha256": sha(audio)}, indent=2) + "\n")
    digits = len(frames[0].stem.removeprefix("frame"))
    pattern = str(images / f"frame%0{digits}d.png")
    image_inputs = ["-framerate", str(FPS), "-i", pattern]
    archive = out / f"escape-the-umbra-{args.version}-lossless-rgb.mkv"
    upload = out / f"escape-the-umbra-steam-trailer-{args.version}.mp4"
    common_color = ["-color_primaries", "bt709", "-color_trc", "iec61966-2-1"]
    run(["ffmpeg", "-y", "-v", "error", *image_inputs, "-i", str(audio), "-map", "0:v:0", "-map", "1:a:0", "-frames:v", str(FRAMES), "-c:v", "ffv1", "-level", "3", "-coder", "1", "-context", "1", "-g", "1", "-slices", "16", "-slicecrc", "1", "-pix_fmt", "bgr0", "-color_range", "pc", "-colorspace", "rgb", *common_color, "-c:a", "copy", str(archive)], out / "encode-lossless.log")
    original_hashes = rgb_hashes(image_inputs)
    archive_hashes = rgb_hashes(["-i", str(archive)])
    if original_hashes != archive_hashes or len(original_hashes) != FRAMES:
        raise RuntimeError("Archive must decode to every exact composited RGB sample")
    def pcm_hash(path: Path) -> str:
        return run(["ffmpeg", "-v", "error", "-i", str(path), "-map", "0:a:0", "-c:a", "pcm_s16le", "-f", "hash", "-hash", "sha256", "-"]).strip()
    if pcm_hash(audio) != pcm_hash(archive):
        raise RuntimeError("Lossless archive must preserve every mixed PCM sample")
    (out / "composited-rgb-framemd5.json").write_text(json.dumps(original_hashes, indent=2) + "\n")
    # Native sRGB code values are preserved; only the RGB→709 YCbCr matrix and
    # limited range are converted. Signal the actual sRGB transfer explicitly.
    # This widely compatible upload is extremely high quality, but 4:2:0 and
    # AAC remain lossy. Steam will produce its own playback transcodes.
    run(["ffmpeg", "-y", "-v", "error", *image_inputs, "-i", str(audio), "-map", "0:v:0", "-map", "1:a:0", "-frames:v", str(FRAMES), "-vf", "scale=1920:1080:flags=lanczos:in_range=pc:out_range=tv:out_color_matrix=bt709,format=yuv420p,setsar=1", "-c:v", "libx264", "-preset", "veryslow", "-crf", "1", "-profile:v", "high", "-pix_fmt", "yuv420p", "-color_range", "tv", "-colorspace", "bt709", *common_color, "-bsf:v", "h264_metadata=video_full_range_flag=0:colour_primaries=1:transfer_characteristics=13:matrix_coefficients=1", "-c:a", "aac", "-b:a", "320k", "-ar", "48000", "-ac", "2", "-movflags", "+faststart", str(upload)], out / "encode-steam.log")
    artifacts: dict = {}
    for path in (archive, upload):
        run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "null", "-"], out / f"{path.suffix[1:]}-decode.log")
        probe = json.loads(run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)]))
        (out / f"{path.suffix[1:]}-probe.json").write_text(json.dumps(probe, indent=2) + "\n")
        artifacts[path.name] = {"sha256": sha(path), "bytes": path.stat().st_size, "decode_pass": True}
    run(["ffmpeg", "-hide_banner", "-i", str(upload), "-af", "ebur128=peak=true", "-f", "null", "-"], out / "audio-loudness.log")
    manifest = {"fps": FPS, "frames": FRAMES, "duration_seconds": FRAMES / FPS, "sources": sources, "editor_sha256": sha(ROOT / "src/Trailer.tsx"), "loader_sha256": sha(ROOT / "src/NativeSource.tsx"), "lossless_rgb_round_trip_exact": True, "lossless_pcm_round_trip_exact": True, "render_input_fingerprint": fingerprint, "artifacts": artifacts, "upload_claim": "Single-generation H.264 High CRF1 / 4:2:0 and AAC320k; intentionally described as high quality, not lossless", "native_color": "sRGB RGB source and compositing; Rec.709 primaries/matrix with sRGB transfer for upload", "steam_reference": "https://partner.steamgames.com/doc/store/trailer?l=english"}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(artifacts, indent=2))

if __name__ == "__main__":
    main()
