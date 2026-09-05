#!/usr/bin/env python3
"""Extract honest Steam gallery stills and natural-speed description loops.

Requires ffmpeg/ffprobe and the six approved native gameplay MP4/cue pairs.
Frames are zero-based. Loop intervals include their first frame and exclude
end_frame. No title cards, overlays, camera changes, audio, or speed changes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

FPS = 30
CLIPS = ("push_bloom", "root_chain", "spell", "merchant", "equipment", "route")


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def probe(path: Path) -> dict:
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)
    ], text=True))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--footage-root", required=True, type=Path)
    parser.add_argument("--output-root", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    source_root = args.footage_root.resolve()
    output_root = args.output_root.resolve()
    screenshots = output_root / "screenshots"
    loops = output_root / "loops"
    screenshots.mkdir(parents=True, exist_ok=True)
    loops.mkdir(parents=True, exist_ok=True)
    sources: dict[str, dict] = {}
    cues: dict[str, list[dict]] = {}
    for clip in CLIPS:
        path = source_root / f"{clip}.mp4"
        cue_path = source_root / f"{clip}.cues.json"
        metadata = json.loads(cue_path.read_text())
        native = probe(path)
        video = next(s for s in native["streams"] if s["codec_type"] == "video")
        assert (video["width"], video["height"]) == (1920, 1080), clip
        assert video["r_frame_rate"] == "30/1", clip
        assert int(video["nb_frames"]) == metadata["frames"], clip
        cues[clip] = metadata["cues"]
        sources[clip] = {
            "file": path.name, "sha256": digest(path), "bytes": path.stat().st_size,
            "cue_file": cue_path.name, "cue_sha256": digest(cue_path),
            "width": 1920, "height": 1080, "fps": FPS, "frames": metadata["frames"],
        }

    def cue(clip: str, kind: str, card: str | None = None, occurrence: int = 0) -> int:
        matches = [c for c in cues[clip] if c["kind"] == kind and (card is None or c.get("card") == card)]
        return int(matches[occurrence]["source_frame"])

    # Three action images lead the gallery; progression and the route follow.
    still_plan = [
        ("01-line-up-the-cross", "push_bloom", cue("push_bloom", "card_aim", "cinder_bloom") + 6,
         "Aim Cinder Bloom at three enemies after pushing a crawler into the cross and moving into range."),
        ("02-chain-the-lightning", "root_chain", cue("root_chain", "impact", occurrence=3),
         "Lightning jumps from a crawler to an acolyte after the group is revealed by light."),
        ("03-elemental-payoff", "push_bloom", cue("push_bloom", "impact", occurrence=1) + 2,
         "Cinder Bloom hits three enemies at once and leaves the surviving enemies burning."),
        ("04-choose-a-spell", "spell", cue("spell", "reward_reveal_complete") + 6,
         "Choose between Updraft, Gust Step and Molten Reach after a fight."),
        ("05-scavengers-wares", "merchant", cue("merchant", "shop_purchase_commit") + 5,
         "A purchased spell rises from the Scavenger's stock as it is added to the pack."),
        ("06-gear-builds-your-deck", "equipment", cue("equipment", "equipment_complete") + 15,
         "The equipped Duelist Rapier supplies Riposte Lunge, Parry Rhythm and Needle Thrust to the deck."),
        ("07-light-reveals-threats", "root_chain", cue("root_chain", "light_reveal_complete") + 6,
         "Root Snare illuminates a hidden crawler and acolyte beside the rooted harrier."),
        ("08-choose-your-route", "route", cue("route", "map_travel_start") + 16,
         "Choose a connected route through elemental rooms, a relic room and the Scavenger."),
    ]
    loop_plan = [
        ("01-set-up-the-strike", "push_bloom", cue("push_bloom", "card_recognition", "updraft"),
         cue("push_bloom", "tactical_payoff_complete") + 12,
         "Push a crawler into a group, walk into range and hit three foes with Cinder Bloom."),
        ("02-choose-your-spell", "spell", 0, cue("spell", "reward_claim_complete") + 20,
         "Three spell rewards appear; Molten Reach is chosen and learned."),
        ("03-shop-and-grow", "merchant", cue("merchant", "shop_browse"),
         cue("merchant", "shop_purchase_complete") + 33,
         "Browse the Scavenger's wares, purchase Threaded Path and watch it arrive in the pack."),
        ("04-reveal-and-chain", "root_chain", cue("root_chain", "card_recognition", "root_snare"),
         cue("root_chain", "tactical_payoff_complete") + 12,
         "Root a visible foe, reveal two hidden neighbors, reposition and chain lightning through the group."),
    ]
    # Bind checked-in captures to their exact source task revision when available.
    head_result = subprocess.run(["git", "-C", str(source_root), "rev-parse", "HEAD"],
                                 capture_output=True, text=True)
    source_head = head_result.stdout.strip() if head_result.returncode == 0 else None
    if source_head:
        source_files = [f"{clip}.{ext}" for clip in CLIPS for ext in ("mp4", "cues.json")]
        run(["git", "-C", str(source_root), "diff", "--quiet", "HEAD", "--", *source_files])
    manifest = {
        "schema": 1, "source_root": str(source_root), "sources": sources,
        "source_repository_head": source_head,
        "policy": {"screenshots": "Uncropped gameplay frames with native UI; no added text or art.",
                   "loops": "Full native frame, natural 30fps timing, silent, hard restart; no camera changes or added frames.",
                   "loop_max_seconds": 12, "description_media_budget_bytes": 15_000_000},
        "valve_sources": [
            "https://partner.steamgames.com/doc/store/assets/standard?l=english",
            "https://partner.steamgames.com/doc/store/page/assets?l=english",
            "https://partner.steamgames.com/doc/store/page/description?l=english",
        ],
        "screenshots": [], "loops": [],
    }
    for name, clip, frame, alt in still_plan:
        assert 0 <= frame < sources[clip]["frames"]
        path = screenshots / f"{name}.png"
        run(["ffmpeg", "-y", "-v", "error", "-i", str(source_root / f"{clip}.mp4"),
             "-vf", f"select=eq(n\\,{frame})", "-frames:v", "1", "-update", "1", str(path)])
        image_stream = probe(path)["streams"][0]
        assert (image_stream["width"], image_stream["height"]) == (1920, 1080)
        manifest["screenshots"].append({"file": str(path.relative_to(output_root)), "source": clip,
            "source_frame": frame, "source_seconds": frame / FPS, "alt": alt,
            "width": 1920, "height": 1080, "sha256": digest(path), "bytes": path.stat().st_size})
    for name, clip, start, end, alt in loop_plan:
        assert 0 <= start < end <= sources[clip]["frames"]
        assert end - start <= 12 * FPS
        path = loops / f"{name}.mp4"
        vf = f"trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS,scale=1170:-2:flags=lanczos,format=yuv420p,setsar=1"
        run(["ffmpeg", "-y", "-v", "error", "-i", str(source_root / f"{clip}.mp4"),
             "-map", "0:v:0", "-an", "-vf", vf, "-c:v", "libx264", "-preset", "slow", "-crf", "20",
             "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
             "-movflags", "+faststart", str(path)])
        streams = probe(path)["streams"]
        assert len(streams) == 1 and streams[0]["codec_type"] == "video"
        video = streams[0]
        assert int(video["nb_frames"]) == end - start
        assert video["r_frame_rate"] == "30/1" and video["width"] == 1170
        assert video["color_space"] == "bt709"
        manifest["loops"].append({"file": str(path.relative_to(output_root)), "source": clip,
            "source_start_frame": start, "source_end_frame_exclusive": end, "frames": end - start,
            "duration_seconds": (end - start) / FPS, "fps": FPS, "width": video["width"],
            "height": video["height"], "silent": True, "alt": alt,
            "sha256": digest(path), "bytes": path.stat().st_size})
    total = sum(item["bytes"] for item in manifest["loops"])
    assert total < 15_000_000, f"Description loops exceed budget: {total}"
    assert all(item["bytes"] < 5_000_000 for item in manifest["loops"])
    manifest["description_media_total_bytes"] = total
    (output_root / "media-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"screenshots": len(still_plan), "loops": len(loop_plan), "loop_bytes": total}, indent=2))


if __name__ == "__main__":
    main()
