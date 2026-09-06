#!/usr/bin/env python3
"""Focused rejection checks for stale native capture and stale render attribution."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import wave
from PIL import Image
from png_srgb import tag_srgb

spec = importlib.util.spec_from_file_location("quality_export", Path(__file__).with_name("export-quality.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory(prefix="umbra-quality-guards-") as directory:
    root = Path(directory)
    module.ROOT = root
    module.REQUIRED = {"push_bloom": 1}
    module.FRAMES = 1
    source = root / "public/native"
    clip = source / "push_bloom"
    clip.mkdir(parents=True)
    png = clip / "frame00000000.png"
    Image.new("RGB", (2, 2), (20, 40, 60)).save(png)
    tag_srgb(png)
    original = png.read_bytes()
    with wave.open(str(source / "push_bloom.wav"), "wb") as audio:
        audio.setparams((2, 2, 48000, 1600, "NONE", "not compressed"))
        audio.writeframes(bytes(1600 * 4))
    cues = {"lossless": {"round_trip_rgb_exact": True, "raw_frames": 1, "source_frame_offset": 0, "native_width": 2, "native_height": 2}, "audio": {"duration_seconds": 1 / 30}}
    (source / "push_bloom.cues.json").write_text(json.dumps(cues))
    (clip / "native-rgb-framemd5.json").write_text(json.dumps({"rgb_frame_md5": [hashlib.md5(bytes((20, 40, 60)) * 4).hexdigest()], "png_srgb_sha256": [hashlib.sha256(original).hexdigest()]}))
    out = root / "out/test"
    out.mkdir(parents=True)
    (out / "render-input-binding.json").write_text(json.dumps({"input_fingerprint": "stale-editor-and-source-binding"}))
    sys.argv = ["export-quality.py", "--source-root", "native", "--out", str(out), "--reuse-render"]
    Image.new("RGB", (2, 2), (21, 40, 60)).save(png)
    try:
        module.main()
        raise AssertionError("Changed native PNG was accepted")
    except RuntimeError as error:
        assert "PNG bytes/profile" in str(error), str(error)
        print("PASS: changed native PNG rejected before rendering")
    png.write_bytes(original)
    try:
        module.main()
        raise AssertionError("Stale cached render was accepted")
    except RuntimeError as error:
        assert "Cached render inputs differ" in str(error), str(error)
        print("PASS: stale cached render rejected after verifying native pixels")
