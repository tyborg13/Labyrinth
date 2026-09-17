#!/usr/bin/env python3
"""Rebuild a portable lighting chooser and optional 12-second wipe from native proof.

Requires Pillow; --video also requires ffmpeg and the committed game-font renderer.
Reads the probe's lighting-capture.json, so new registry profiles appear automatically.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def preview(path: Path, full_frame: bool) -> str:
    with Image.open(path) as original:
        if original.size != (1920, 1080):
            raise ValueError(f"Expected native 1920x1080 proof: {path}")
        pixels = original.convert("RGB")
        if not full_frame:
            pixels = pixels.crop((420, 150, 1500, 740))
        output = io.BytesIO()
        pixels.save(output, format="WEBP", lossless=True, method=6)
    return "data:image/webp;base64," + base64.b64encode(output.getvalue()).decode()


def render_video(before: Path, after: Path, look: str, output: Path) -> Path:
    # Same native still-to-wipe recipe as the accepted September 17 comparison.
    title_path = PROJECT / "marketing/trailer/scripts/render-title-cards.py"
    spec = importlib.util.spec_from_file_location("lighting_titles", title_path)
    titles = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(titles)
    titles.OUTPUT_DIR = output / "labels"
    titles.OUTPUT_DIR.mkdir(exist_ok=True)
    titles.render_card("before", "UNTREATED", 34, "#f5e8cf", 0.025)
    titles.render_card("after", look.upper(), 34, "#f5e8cf", 0.025)
    position = ("if(lt(t,1.4),1920,if(lt(t,4.4),1920*(1-(t-1.4)/3),"
                "if(lt(t,5.4),0,if(lt(t,8.4),1920*(t-5.4)/3,"
                "if(lt(t,9),1920,if(lt(t,11),1920*(1-(t-9)/2),0))))))")
    graph = ";".join([
        "[0:v][2:v]overlay=x=50:y=82:format=auto,format=gbrp,split=2[b0][b1]",
        "[1:v][3:v]overlay=x=W-w-50:y=82:format=auto,format=gbrp,split=2[a0][a1]",
        "[b0][a0]xfade=transition=wipeleft:duration=3:offset=1.4[x1]",
        "[x1][b1]xfade=transition=wiperight:duration=3:offset=5.4[x2]",
        "[x2][a1]xfade=transition=wipeleft:duration=2:offset=9[x3]",
        "color=c=0xede6d8:s=3x1080:r=60:d=12,format=rgb24[line]",
        f"[x3][line]overlay=x='{position}-1':y=0:format=auto:enable='between(t,1.4,4.4)+between(t,5.4,8.4)+between(t,9,11)'[wipe]",
        "[wipe]scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p[out]",
    ])
    target = output / f"combat-lighting-{look}-before-after.mp4"
    command = ["ffmpeg", "-hide_banner", "-y", "-filter_complex_threads", "2"]
    for source in (before, after, output / "labels/before.png", output / "labels/after.png"):
        command.extend(["-loop", "1", "-framerate", "60", "-i", str(source)])
    command.extend(["-filter_complex", graph, "-map", "[out]", "-an", "-frames:v", "720",
                    "-r", "60", "-c:v", "libx264", "-profile:v", "high", "-preset", "slow",
                    "-crf", "12", "-pix_fmt", "yuv420p", "-color_range", "tv", "-colorspace", "bt709",
                    "-color_primaries", "bt709", "-color_trc", "iec61966-2-1", "-movflags", "+faststart", str(target)])
    (output / "filtergraph.txt").write_text(graph + "\n")
    (output / "render-command.json").write_text(json.dumps(command, indent=2) + "\n")
    with (output / "render.log").open("w") as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(target), "-f", "null", "-"], check=True)
    return target


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--look", help="Initially selected profile; defaults to captured global default")
    parser.add_argument("--video", action="store_true", help="Also reconstruct the selected profile's silent wipe")
    parser.add_argument("--full-frame", action="store_true", help="Include the full HUD in the HTML instead of the board crop")
    args = parser.parse_args()
    capture = args.capture_dir.resolve()
    output = args.output_dir.resolve()
    metadata_path = capture / "lighting-capture.json"
    metadata = json.loads(metadata_path.read_text())
    if metadata.get("schema_version") != 1 or not metadata.get("probe_passed") or metadata.get("scenario_issues"):
        parser.error("Use a passing, realistic combat_lighting_variants_probe capture")
    profiles = metadata["profiles"]
    selected = args.look or metadata["default_id"]
    if selected not in {profile["id"] for profile in profiles}:
        parser.error(f"Profile {selected!r} was not captured")
    output.mkdir(parents=True, exist_ok=True)
    baseline = capture / metadata["baseline"]
    data = {"default_id": metadata["default_id"], "selected_id": selected,
            "scene": f"{metadata['room_name']} · seed {metadata['seed']} · room {metadata['room']}",
            "baseline": preview(baseline, args.full_frame),
            "profiles": [{"id": profile["id"], "name": profile["id"].replace("_", " ").title(),
                          "src": preview(capture / profile["image"], args.full_frame)} for profile in profiles]}
    template_path = PROJECT / "tools/templates/combat_lighting_comparison.html"
    page = template_path.read_text().replace("__DATA__", json.dumps(data).replace("<", "\\u003c"))
    html = output / "lighting-comparison.html"
    html.write_text(page)
    sources = [metadata_path, baseline, *[capture / item["image"] for item in profiles],
               Path(__file__), template_path, PROJECT / "scripts/combat_lighting_profiles.gd"]
    products = [html]
    if args.video:
        after = capture / next(item["image"] for item in profiles if item["id"] == selected)
        products.append(render_video(baseline, after, selected, output))
        sources.extend([PROJECT / "fonts/LabyrinthCrumble-Display.ttf",
                        PROJECT / "marketing/trailer/scripts/render-title-cards.py"])
    (output / "reconstruction.json").write_text(json.dumps({
        "schema_version": 1, "capture": metadata, "selected_id": selected,
        "html_crop": None if args.full_frame else [420, 150, 1500, 740],
        "source_sha256": {str(path): digest(path) for path in sources},
        "output_sha256": {str(path): digest(path) for path in products},
    }, indent=2) + "\n")
    for path in products:
        print(path)


if __name__ == "__main__":
    main()
