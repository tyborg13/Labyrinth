#!/usr/bin/env python3
"""Derive the turn, menu and ambience cues from recordings already shipped.

Like tools/generate_ember_hearth_sfx.py, every output is a filtered, re-timed
excerpt of an existing project recording; no oscillators, downloaded samples or
generated audio are introduced. Requires ffmpeg and numpy.

    python3 tools/generate_ui_cue_sfx.py            # rebuild every cue
    python3 tools/generate_ui_cue_sfx.py --report   # also print source/output hashes
"""
from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SFX = ROOT / "assets" / "audio" / "sfx"
OUT = SFX / "ui"
RATE = 44100

# Each cue: source recording, ffmpeg filter chain, output name, peak ceiling.
CUES = [
    {
        # Menu open: the deal swish slowed into a page being turned.
        "name": "menu_page_open.wav",
        "source": "card_draw_deal.wav",
        "filter": "asetrate={rate}*0.80,aresample={rate},highpass=f=180,lowpass=f=6500,afade=t=out:st=0.22:d=0.14",
        "peak_db": -4.0,
    },
    {
        # Menu close: a shorter, brighter fold of the same page.
        "name": "menu_page_close.wav",
        "source": "card_draw_deal.wav",
        "filter": "atrim=0:0.22,asetrate={rate}*0.92,aresample={rate},highpass=f=260,lowpass=f=7000,afade=t=out:st=0.10:d=0.12",
        "peak_db": -6.0,
    },
]

AMBIENCE_NAME = "dungeon_hall_ambience_loop.wav"
AMBIENCE_SOURCE = "run/campfire_loop.wav"
AMBIENCE_SECONDS = 48.0
AMBIENCE_CROSSFADE = 4.0


def _decode(path: Path, filter_chain: str) -> np.ndarray:
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path),
        "-af", filter_chain, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-",
    ]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def _normalize_peak(samples: np.ndarray, peak_db: float) -> np.ndarray:
    peak = float(np.max(np.abs(samples))) if samples.size else 0.0
    if peak <= 0.0:
        return samples
    return samples * (10.0 ** (peak_db / 20.0) / peak)


def _write_wav(path: Path, samples: np.ndarray, channels: int = 1) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    clipped = np.clip(samples, -1.0, 1.0)
    pcm = (clipped * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(channels)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def _stereo_decode(path: Path, filter_chain: str) -> np.ndarray:
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path),
        "-af", filter_chain, "-ac", "2", "-ar", str(RATE), "-f", "f32le", "-",
    ]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64).reshape(-1, 2)


def build_ambience() -> np.ndarray:
    """A barely-there stone-hall room tone, looped seamlessly.

    Only the campfire's low body is used, slowed and low-passed into a rumble;
    the crackle is left out so ordinary rooms never sound like a fire.
    """
    source = SFX / AMBIENCE_SOURCE
    total = AMBIENCE_SECONDS + AMBIENCE_CROSSFADE
    rumble = _stereo_decode(source, f"atrim=20:{20 + total * 0.6 + 1.0},asetrate={RATE}*0.6,aresample={RATE},lowpass=f=240,highpass=f=35")
    frames = int(total * RATE)
    rumble = rumble[:frames]
    bed = rumble / max(1e-9, float(np.sqrt(np.mean(rumble ** 2)))) * 0.060
    loop_frames = int(AMBIENCE_SECONDS * RATE)
    fade_frames = int(AMBIENCE_CROSSFADE * RATE)
    head = bed[:loop_frames].copy()
    tail = bed[loop_frames:loop_frames + fade_frames]
    # Equal-power crossfade of the overhang into the head makes the loop seamless.
    ramp = np.linspace(0.0, np.pi / 2.0, fade_frames)[:, None]
    head[:fade_frames] = head[:fade_frames] * np.sin(ramp) + tail * np.cos(ramp)
    peak = float(np.max(np.abs(head)))
    if peak > 0.5:
        head *= 0.5 / peak
    return head


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", action="store_true", help="print source and output hashes")
    args = parser.parse_args()
    report: list[str] = []
    for cue in CUES:
        source = SFX / cue["source"]
        samples = _decode(source, cue["filter"].format(rate=RATE))
        samples = _normalize_peak(samples, cue["peak_db"])
        destination = OUT / cue["name"]
        _write_wav(destination, samples)
        report.append(f"{cue['name']}: {len(samples) / RATE:.3f}s from {cue['source']}")
    ambience = build_ambience()
    _write_wav(OUT / AMBIENCE_NAME, ambience.reshape(-1), channels=2)
    report.append(f"{AMBIENCE_NAME}: {AMBIENCE_SECONDS:.1f}s loop from {AMBIENCE_SOURCE}")
    for line in report:
        print(line)
    if args.report:
        for path in sorted(OUT.glob("*.wav")):
            print(path.name, hashlib.sha256(path.read_bytes()).hexdigest())
    return 0


if __name__ == "__main__":
    sys.exit(main())
