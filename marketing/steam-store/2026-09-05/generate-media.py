#!/usr/bin/env python3
"""Extract honest Steam gallery stills and natural-speed description loops.

Requires ffmpeg/ffprobe, seven native video PNG sequences, and six native 2x still PNG sequences with cues.
Frames are zero-based. Loop intervals include their first frame and exclude
end_frame. No title cards, overlays, camera changes, audio, or speed changes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path
import subprocess

FPS = 30
CLIPS = ("push_bloom", "root_chain", "spell", "merchant", "equipment", "route", "campfire")


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def probe(path: Path) -> dict:
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)
    ], text=True))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native_png(path: Path) -> dict:
    """Check the real renderer's dimensions and unambiguous sRGB metadata."""
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    offset = 8
    chunks = {}
    while offset < len(data):
        length = int.from_bytes(data[offset:offset + 4], "big")
        name = data[offset + 4:offset + 8]
        if name in (b"IHDR", b"sRGB", b"cICP", b"iCCP"):
            chunks[name] = data[offset + 8:offset + 8 + length]
        offset += length + 12
    assert chunks.get(b"sRGB") == b"\x00", f"Native capture must explicitly declare sRGB: {path}"
    assert b"cICP" not in chunks and b"iCCP" not in chunks, f"Conflicting native color metadata: {path}"
    width, height, bit_depth, color_type = struct.unpack(">IIBB", chunks[b"IHDR"][:10])
    assert bit_depth == 8 and color_type == 2, f"Expected full-color RGB8 PNG: {path}"
    return {"width": width, "height": height, "color_space": "sRGB", "pixel_format": "rgb24"}


def sequence_pattern(source: dict) -> Path:
    return Path(source.get("_source_root", "")) / source["lossless_pattern"]


def frame_path(source: dict, source_frame: int) -> Path:
    return Path(str(sequence_pattern(source)) % (source["source_frame_offset"] + source_frame))


def portable_source(source: dict) -> dict:
    return {key: value for key, value in source.items() if not key.startswith("_")}



def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--footage-root", required=True, type=Path)
    parser.add_argument("--stills-root", required=True, type=Path, help="Separately captured native 2x PNG/cue sources used only for gallery stills")
    parser.add_argument("--only", nargs="+", metavar="OUTPUT_ID", help="Rebuild only these output filename stems; unchanged outputs and source provenance must still verify")
    parser.add_argument("--output-root", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    source_root = args.footage_root.resolve()
    stills_root = args.stills_root.resolve()
    output_root = args.output_root.resolve()
    screenshots = output_root / "screenshots"
    loops = output_root / "loops"
    screenshots.mkdir(parents=True, exist_ok=True)
    loops.mkdir(parents=True, exist_ok=True)
    def load_sources(root_path: Path, clips: tuple[str, ...], render_scale: int) -> tuple[dict, dict]:
        sources: dict[str, dict] = {}
        cues: dict[str, list[dict]] = {}
        for clip in clips:
            cue_path = root_path / f"{clip}.cues.json"
            metadata = json.loads(cue_path.read_text())
            lossless = metadata.get("lossless", {})
            assert lossless.get("round_trip_rgb_exact") is True, f"{clip}: missing native RGB round-trip proof"
            assert lossless.get("pixel_encoding") == "native_srgb_rgb", f"{clip}: requires native lossless sRGB frames"
            assert lossless.get("render_scale") == render_scale, f"{clip}: requires a genuine {render_scale}x native render"
            assert metadata["fps"] == FPS, clip
            pattern = Path(lossless["pattern"])
            if not pattern.is_absolute():
                pattern = root_path / pattern
            relative_pattern = str(pattern.relative_to(root_path))
            assert "%08d" in str(pattern), f"Unexpected sequence pattern: {pattern}"
            safe_start = int(metadata["safe_start_raw_frame"])
            sequence_offset = int(lossless.get("source_frame_offset", safe_start))
            frames = int(metadata["frames"])
            assert sequence_offset >= 0 and sequence_offset + frames <= lossless["raw_frames"], clip
            cues[clip] = metadata["cues"]
            source = {
                "cue_file": cue_path.name, "cue_sha256": digest(cue_path),
                "_source_root": str(root_path), "lossless_pattern": relative_pattern, "safe_start_raw_frame": safe_start,
                "source_frame_offset": sequence_offset,
                "width": lossless["native_width"], "height": lossless["native_height"],
                "logical_width": 1920, "logical_height": 1080,
                "fps": FPS, "frames": frames, "color_space": "sRGB",
                "capture": f"native {render_scale}x RGB PNG sequence; MP4 proxy is not an input",
                "capture_origin": metadata["capture_origin"],
            }
            assert source["capture_origin"]["captured_script_sha256"], f"{clip}: missing captured source provenance"
            assert (source["width"], source["height"]) == (1920 * render_scale, 1080 * render_scale), clip
            proof_path = pattern.parent / "native-rgb-framemd5.json"
            capture_proof = json.loads(proof_path.read_text())
            spool = capture_proof["spool"]
            assert not spool["failure"] and spool["written_frames"] == spool["source_frames"], clip
            assert spool["written_frames"] == lossless["raw_frames"], clip
            assert (spool["width"], spool["height"]) == (source["width"], source["height"]), clip
            assert len(capture_proof["rgb_frame_md5"]) == len(capture_proof["png_srgb_sha256"]) == spool["written_frames"], clip
            source["capture_rgb_proof_file"] = str(proof_path.relative_to(root_path))
            source["capture_rgb_proof_sha256"] = digest(proof_path)
            source["native_rgb_round_trip_verified"] = True
            assert spool["rendering_method"] == "mobile", f"{clip}: capture must explicitly match the approved production Mobile renderer"
            assert spool["msaa_2d"] == spool["root_msaa_2d"], f"{clip}: capture MSAA differs from the game"
            source["render_settings"] = {key: spool[key] for key in ("rendering_method", "msaa_2d", "root_msaa_2d")}
            # Hash every usable native frame, including its index, to bind actual inputs.
            sequence_hash = hashlib.sha256()
            for frame in range(frames):
                native_frame = frame_path(source, frame)
                info = native_png(native_frame)
                assert (info["width"], info["height"]) == (1920 * render_scale, 1080 * render_scale), native_frame
                frame_sha = digest(native_frame)
                assert frame_sha == capture_proof["png_srgb_sha256"][sequence_offset + frame], f"Changed native frame since capture proof: {native_frame}"
                sequence_hash.update(f"{frame}:{frame_sha}\n".encode())
            source["sequence_sha256"] = sequence_hash.hexdigest()
            source["sequence_digest_scheme"] = "sha256 of source-frame-index:frame-sha256 followed by LF, in source order"
            sources[clip] = source

        return sources, cues

    sources, cues = load_sources(source_root, CLIPS, 1)
    still_sources, still_cues = load_sources(stills_root, tuple(clip for clip in CLIPS if clip != "campfire"), 2)

    def cue(clip: str, kind: str, card: str | None = None, occurrence: int = 0, *, still: bool = False) -> int:
        lookup = still_cues if still else cues
        matches = [c for c in lookup[clip] if c["kind"] == kind and (card is None or c.get("card") == card)]
        return int(matches[occurrence]["source_frame"])

    def still_cue(clip: str, kind: str, card: str | None = None, occurrence: int = 0) -> int:
        return cue(clip, kind, card, occurrence, still=True)

    # Three action images lead the gallery; progression and the route follow.
    still_plan = [
        ("01-line-up-the-cross", "push_bloom", still_cue("push_bloom", "card_aim", "cinder_bloom") + 6,
         "Aim Cinder Bloom at three enemies after pushing a crawler into the cross and moving into range."),
        ("02-chain-the-lightning", "root_chain", still_cue("root_chain", "impact", occurrence=3),
         "Lightning jumps from a crawler to an acolyte after the group is revealed by light."),
        ("03-elemental-payoff", "push_bloom", still_cue("push_bloom", "impact", occurrence=1) + 2,
         "Cinder Bloom hits three enemies at once and leaves the surviving enemies burning."),
        ("04-choose-a-spell", "spell", still_cue("spell", "reward_reveal_complete") + 6,
         "Choose between Updraft, Gust Step and Molten Reach after a fight."),
        ("05-scavengers-wares", "merchant", still_cue("merchant", "shop_purchase_commit") + 5,
         "A purchased spell rises from the Scavenger's stock as it is added to the pack."),
        ("06-gear-builds-your-deck", "equipment", still_cue("equipment", "equipment_complete") + 15,
         "The equipped Duelist Rapier supplies Riposte Lunge, Parry Rhythm and Needle Thrust to the deck."),
        ("07-light-reveals-threats", "root_chain", still_cue("root_chain", "light_reveal_complete") + 6,
         "Root Snare illuminates a hidden crawler and acolyte beside the rooted harrier."),
        ("08-choose-your-route", "route", still_cue("route", "map_travel_start") + 16,
         "Choose a connected route through elemental rooms, a relic room and the Scavenger."),
    ]
    loop_plan = [
        ("01-set-up-the-strike", "push_bloom", cue("push_bloom", "card_recognition", "updraft"),
         cue("push_bloom", "tactical_payoff_complete") + 12,
         "Push a crawler into a group, walk into range and hit three foes with Cinder Bloom."),
        ("02-choose-your-spell", "spell", 0, cue("spell", "reward_claim_complete") + 20,
         "Three spell rewards appear; a spell is chosen and added to reserve magic."),
        ("03-shop-and-grow", "merchant", cue("merchant", "shop_browse"),
         cue("merchant", "shop_purchase_complete") + 33,
         "Browse the Scavenger's wares, purchase a spell and watch it arrive in the pack."),
        ("04-reveal-and-chain", "root_chain", cue("root_chain", "card_recognition", "root_snare"),
         cue("root_chain", "tactical_payoff_complete") + 12,
         "Root a visible foe, reveal two hidden neighbors, reposition and chain lightning through the group."),
        ("05-campfire-choice", "campfire", cue("campfire", "campfire_choices_readable"),
         cue("campfire", "campfire_choice_complete") + 18,
         "At a campfire, review the choices, linger to recover health and continue the run."),
    ]
    # Collection provenance survives relocation outside the capture worktree.
    def collection_provenance(root_path: Path, loaded_sources: dict) -> dict:
        collection_path = root_path / "native-collection.json"
        if not collection_path.exists():
            return {"note": "Working collection; bind native-collection.json before archive/handoff."}
        collection = json.loads(collection_path.read_text())
        assert collection["reviewed_source_head"], "Archive must bind a reviewed source commit"
        assert collection["capture_origins"] == {clip: source["capture_origin"] for clip, source in loaded_sources.items()}, "Archive capture origins disagree with native cues"
        reviewed_heads = collection["reviewed_capture_heads"]
        assert set(reviewed_heads) == set(loaded_sources) and all(reviewed_heads.values()), "Archive must verify a reviewed capture commit for every clip"
        return {"file": collection_path.name, "sha256": digest(collection_path),
                "reviewed_source_head": collection["reviewed_source_head"],
                "collection_sha256": collection["collection_sha256"], "reviewed_capture_heads": reviewed_heads}

    source_provenance = collection_provenance(source_root, sources)
    still_provenance = collection_provenance(stills_root, still_sources)
    if "reviewed_source_head" in source_provenance:
        source_head = source_provenance["reviewed_source_head"]
        source_dirty = None  # Actual dirty capture origins remain in each source entry.
    else:
        head_result = subprocess.run(["git", "-C", str(source_root), "rev-parse", "HEAD"],
                                     capture_output=True, text=True)
        source_head = head_result.stdout.strip() if head_result.returncode == 0 else None
        source_changes = subprocess.run(["git", "-C", str(source_root), "status", "--porcelain"],
                                        capture_output=True, text=True)
        source_dirty = bool(source_changes.stdout.strip()) if source_changes.returncode == 0 else None
    manifest = {
        "schema": 2, "source_root": str(source_root), "sources": {key: portable_source(value) for key, value in sources.items()},
        "screenshot_source_root": str(stills_root), "screenshot_sources": {key: portable_source(value) for key, value in still_sources.items()},
        "source_repository_head": source_head, "source_repository_head_scope": "video bank; still bank has its own independent collection binding",
        "source_repository_dirty_at_generation": source_dirty,
        "source_collection_provenance": source_provenance,
        "screenshot_collection_provenance": still_provenance,
        "policy": {"screenshots": "Byte-identical native 3840x2160 sRGB RGB PNG frames, same 1920x1080 logical UI100; no added text or art.",
                   "loops": "Full native frame, natural 30fps timing, silent, hard restart; no camera changes or added frames.",
                   "loop_max_seconds": 12,
                   "encoding": "1920x1080 H.264 CRF1, yuv420p limited range, BT.709 primaries/matrix and native sRGB transfer; no gamma adjustment.",
                   "quality_priority": "Preserve genuine native detail; no arbitrary local asset byte budget."},
        "valve_sources": [
            "https://partner.steamgames.com/doc/store/assets/standard?l=english",
            "https://partner.steamgames.com/doc/store/page/assets?l=english",
            "https://partner.steamgames.com/doc/store/page/description?l=english",
        ],
        "screenshots": [], "loops": [],
    }
    existing = {}
    requested = {Path(value).stem for value in args.only} if args.only else set()
    if requested:
        valid_ids = {plan[0] for plan in (*still_plan, *loop_plan)}
        assert requested <= valid_ids, f"Unknown output IDs: {sorted(requested - valid_ids)}; choose from {sorted(valid_ids)}"
        existing = json.loads((output_root / "media-manifest.json").read_text())
        assert existing.get("schema") == 2, "Partial rebuild needs a current complete manifest; run a full build first"

    def keep_existing(collection_name: str, name: str, clip: str, expected: dict, *, append: bool = True) -> bool:
        if not requested or name in requested:
            return False
        old = next((item for item in existing[collection_name] if Path(item["file"]).stem == name), None)
        assert old is not None, f"Missing previous {name}; include it in --only or run a full build"
        source_collection = "screenshot_sources" if collection_name == "screenshots" else "sources"
        old_source = existing[source_collection][clip]
        new_source = manifest[source_collection][clip]
        for key in ("sequence_sha256", "cue_sha256", "capture_rgb_proof_sha256", "width", "height", "source_frame_offset"):
            assert old_source.get(key) == new_source.get(key), f"Source changed for {name}; include all dependent outputs in --only or run a full build"
        for key, value in expected.items():
            assert old.get(key) == value, f"Selection/description changed for {name}; include it in --only"
        path = output_root / old["file"]
        assert path.is_file() and digest(path) == old["sha256"], f"Changed/missing untouched output {name}; include it in --only"
        if append:
            manifest[collection_name].append(old)
        return True

    def still_expected(frame: int, alt: str) -> dict:
        return {"source_frame": frame, "alt": alt, "width": 3840, "height": 2160, "color_space": "sRGB"}

    def loop_expected(start: int, end: int, alt: str) -> dict:
        return {"source_start_frame": start, "source_end_frame_exclusive": end, "alt": alt,
                "width": 1920, "height": 1080, "fps": FPS, "crf": 1, "color_transfer": "iec61966-2-1"}

    # Reject all stale untouched assets before copying/encoding any selected output.
    if requested:
        for name, clip, frame, alt in still_plan:
            keep_existing("screenshots", name, clip, still_expected(frame, alt), append=False)
        for name, clip, start, end, alt in loop_plan:
            keep_existing("loops", name, clip, loop_expected(start, end, alt), append=False)

    for name, clip, frame, alt in still_plan:
        assert 0 <= frame < still_sources[clip]["frames"]
        if keep_existing("screenshots", name, clip, still_expected(frame, alt)):
            continue
        path = screenshots / f"{name}.png"
        native_frame = frame_path(still_sources[clip], frame)
        shutil.copyfile(native_frame, path)
        info = native_png(path)
        assert digest(path) == digest(native_frame), f"Screenshot changed native pixels/profile: {path}"
        manifest["screenshots"].append({"file": str(path.relative_to(output_root)), "source": clip,
            "source_frame": frame, "source_collection": "screenshot_sources", "source_seconds": frame / FPS, "alt": alt,
            "source_raw_frame": still_sources[clip]["source_frame_offset"] + frame,
            "native_file": str(native_frame.relative_to(stills_root)), "native_sha256": digest(native_frame),
            **info, "sha256": digest(path), "bytes": path.stat().st_size})
    for name, clip, start, end, alt in loop_plan:
        assert 0 <= start < end <= sources[clip]["frames"]
        assert end - start <= 12 * FPS
        if keep_existing("loops", name, clip, loop_expected(start, end, alt)):
            continue
        path = loops / f"{name}.mp4"
        vf = "scale=1920:1080:flags=lanczos:in_range=pc:out_range=tv:out_color_matrix=bt709,format=yuv420p,setsar=1"
        run(["ffmpeg", "-y", "-v", "error", "-framerate", str(FPS),
             "-start_number", str(sources[clip]["source_frame_offset"] + start),
             "-i", str(sequence_pattern(sources[clip])), "-frames:v", str(end - start),
             "-map", "0:v:0", "-an", "-vf", vf,
             "-c:v", "libx264", "-preset", "slow", "-crf", "1",
             "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "iec61966-2-1",
             "-movflags", "+faststart", str(path)])
        streams = probe(path)["streams"]
        assert len(streams) == 1 and streams[0]["codec_type"] == "video"
        video = streams[0]
        assert int(video["nb_frames"]) == end - start
        assert video["r_frame_rate"] == "30/1" and (video["width"], video["height"]) == (1920, 1080)
        assert video["color_space"] == video["color_primaries"] == "bt709"
        assert video["color_transfer"] == "iec61966-2-1" and video["color_range"] == "tv"
        manifest["loops"].append({"file": str(path.relative_to(output_root)), "source": clip,
            "source_start_frame": start, "source_end_frame_exclusive": end, "frames": end - start,
            "duration_seconds": (end - start) / FPS, "fps": FPS, "width": video["width"],
            "height": video["height"], "silent": True, "alt": alt,
            "color_primaries": "bt709", "color_matrix": "bt709", "color_transfer": "iec61966-2-1",
            "color_range": "tv", "codec": "h264", "pixel_format": "yuv420p", "crf": 1,
            "sha256": digest(path), "bytes": path.stat().st_size})
    total = sum(item["bytes"] for item in manifest["loops"])
    manifest["description_media_total_bytes"] = total
    (output_root / "media-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"screenshots": len(still_plan), "loops": len(loop_plan), "loop_bytes": total, "rebuilt": sorted(requested) if requested else "all"}, indent=2))


if __name__ == "__main__":
    main()
