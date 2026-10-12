"""Shared local-only I/O, provenance validation and deterministic audio processing."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
from fractions import Fraction

# Keep four analysis workers from multiplying numerical-library thread pools.
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["OMP_NUM_THREADS"] = "1"

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy import signal


SOURCE_LICENSES = {
    "sonniss_gdc": "Sonniss GDC Bundle licence",
    "kenney": "CC0-1.0",
    "opengameart": "CC0-1.0",
}
AUDIO_EXTENSIONS = {".wav", ".ogg", ".flac", ".mp3"}
MAX_WORKERS = 4
FFMPEG_THREADS = 2
SUBPROCESS_TIMEOUT_SECONDS = 180
HASH_BLOCK_BYTES = 1024 * 1024
OUTPUT_RATE = 48000
SHORT_SECONDS = 0.4
SCHEMA_VERSION = 1
VORBIS_QUALITY = 0.6  # libvorbis q6 in libsndfile's [0, 1] quality interface.
SFC_SET_VBR_ENCODING_QUALITY = 0x1300  # Stable libsndfile sf_command ABI.
RESAMPLE_MAX_DENOMINATOR = 100000
FFMPEG_SLOT_DIRECTORY = Path(tempfile.gettempdir()) / "umbra-sfx-ffmpeg-slots"
FFMPEG_SLOT_POLL_SECONDS = 0.025

# Owner-approved rendering decisions (sfx-00 feedback 1).
SHORT_PEAK_TARGETS = {"impact": -3, "body": -4, "vocal": -6, "ui": -12,
                      "card": -10, "spell": -4, "movement": -14, "status": -8,
                      "pickup": -8, "stinger": -3}
STEREO_SIDE_RATIO = 0.25  # RMS(side) / RMS(mid), not side-energy share.
LOWPASS_ORDER = 2
LOWPASS_FILTER = "butterworth"
FADE_CURVE = "equal_power"
FADE_IN_MS = 3
FADE_IN_CURVE = "linear"
LOOP_CROSSFADE_CURVE = "equal_power"
PITCH_MODE = "resample"
MULTICHANNEL_DOWNMIX = "front_pair"
DESIGN_DEFAULTS = {"short_peak_targets": SHORT_PEAK_TARGETS,
                   "stereo_side_ratio": STEREO_SIDE_RATIO,
                   "lowpass_order": LOWPASS_ORDER, "lowpass_filter": LOWPASS_FILTER,
                   "fade_curve": FADE_CURVE, "loop_crossfade_curve": LOOP_CROSSFADE_CURVE,
                   "pitch_mode": PITCH_MODE, "multichannel_downmix": MULTICHANNEL_DOWNMIX}


class LabError(ValueError):
    pass


def safe_path(path: str | Path) -> Path:
    """Reject excluded lexical paths AND symlink destinations before opening."""
    value = Path(path).expanduser()
    for candidate in (value, value.resolve()):
        if any(part.lower() == "mixkit" or part.lower().startswith("sfx-sources-excluded")
               for part in candidate.parts):
            raise LabError(f"Excluded source path: {path}")
    return value.resolve()


def source_path(root: str | Path, relative: str, licence_id: str | None = None) -> Path:
    root = safe_path(root)
    rel = Path(relative)
    if rel.is_absolute() or ".." in rel.parts or not rel.parts:
        raise LabError(f"Source path must be relative to the approved root: {relative}")
    if rel.parts[0] not in SOURCE_LICENSES:
        raise LabError(f"Unapproved source: {relative}")
    if licence_id is not None and licence_id != SOURCE_LICENSES[rel.parts[0]]:
        raise LabError(f"Licence mismatch: {relative}")
    result = safe_path(root / rel)
    if not result.is_relative_to(root / rel.parts[0]):
        raise LabError(f"Source escapes its library: {relative}")
    return result


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with safe_path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(HASH_BLOCK_BYTES), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: str | Path):
    with safe_path(path).open(encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: str | Path, value) -> None:
    write_text(path, json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2,
                                allow_nan=False) + "\n")


def write_text(path: str | Path, value: str) -> None:
    path = safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    # Replace atomically; failed analysis never leaves half a catalogue.
    with tempfile.NamedTemporaryFile(dir=path.parent, mode="w", encoding="utf-8",
                                     delete=False) as handle:
        temporary = Path(handle.name)
        handle.write(value)
    temporary.replace(path)


def read_jsonl(path: str | Path) -> list[dict]:
    with safe_path(path).open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def write_jsonl(path: str | Path, rows: list[dict]) -> None:
    write_text(path, "".join(json.dumps(row, sort_keys=True, ensure_ascii=False,
                                       allow_nan=False) + "\n" for row in rows))


def workers(value: str | int) -> int:
    value = int(value)
    if not 1 <= value <= MAX_WORKERS:
        raise argparse.ArgumentTypeError("workers must be between 1 and 4")
    return value


@contextmanager
def ffmpeg_slot():
    """Four cooperative machine-wide slots, including concurrent CLI runs."""
    FFMPEG_SLOT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + SUBPROCESS_TIMEOUT_SECONDS
    while True:
        for number in range(MAX_WORKERS):
            handle = (FFMPEG_SLOT_DIRECTORY / f"{number}.lock").open("a")
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                handle.close()
                continue
            try:
                yield
            finally:
                fcntl.flock(handle, fcntl.LOCK_UN)
                handle.close()
            return
        if time.monotonic() >= deadline:
            raise LabError("Timed out waiting for one of four FFmpeg slots")
        time.sleep(FFMPEG_SLOT_POLL_SECONDS)


def command(args: list[str], **kwargs) -> subprocess.CompletedProcess:
    try:
        if Path(args[0]).name == "ffmpeg":
            with ffmpeg_slot():
                return subprocess.run(args, check=True, capture_output=True,
                                      timeout=SUBPROCESS_TIMEOUT_SECONDS, **kwargs)
        return subprocess.run(args, check=True, capture_output=True, timeout=SUBPROCESS_TIMEOUT_SECONDS, **kwargs)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError) as error:
        stderr = getattr(error, "stderr", b"") or b""
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        raise LabError(f"{args[0]} failed: {stderr or error}") from error


def decode(path: Path) -> tuple[np.ndarray, int]:
    path = safe_path(path)
    try:
        data, rate = sf.read(path, dtype="float64", always_2d=True)
    except (sf.LibsndfileError, RuntimeError):
        info = json.loads(command(["ffprobe", "-v", "error", "-threads", "2",
                                   "-show_streams", "-of", "json", str(path)]).stdout)
        stream = next(item for item in info["streams"] if item["codec_type"] == "audio")
        rate, channels = int(stream["sample_rate"]), int(stream["channels"])
        raw = command(["ffmpeg", "-v", "error", "-threads", "2", "-i", str(path),
                       "-map", "0:a:0", "-threads", "2", "-f", "f64le", "-"]).stdout
        data = np.frombuffer(raw, dtype="<f8").reshape(-1, channels).copy()
    if not len(data) or not np.isfinite(data).all():
        raise LabError(f"Empty or non-finite audio: {path}")
    return data, rate


def db(amplitude: float) -> float | None:
    return 20 * math.log10(amplitude) if amplitude > 0 else None


def loudness(data: np.ndarray, rate: int) -> tuple[float | None, str]:
    if len(data) / rate < SHORT_SECONDS:
        return db(float(np.sqrt(np.mean(data ** 2)))), "short_rms_dbfs"
    if data.shape[1] > 5:
        raise LabError("LUFS measurement supports at most five channels")
    value = float(pyln.Meter(rate).integrated_loudness(data))
    return (value if math.isfinite(value) else None), "integrated_lufs"


def finite(value, name: str) -> float:
    try:
        result = float(value)
    except (ValueError, TypeError) as error:
        raise LabError(f"{name} must be a finite number") from error
    if not math.isfinite(result):
        raise LabError(f"{name} must be a finite number")
    return result


def approved_value(config: dict, name: str, value):
    """Retain read-only config compatibility without overriding approved design."""
    if config.get(name, value) != value:
        raise LabError(f"{name} must use the owner-approved value: {value!r}")
    return value


def design_value(config: dict, name: str):
    return approved_value(config, name, DESIGN_DEFAULTS[name])


def front_pair(data: np.ndarray) -> tuple[np.ndarray, dict]:
    source_channels = data.shape[1]
    return data[:, :2], {"source_channels": source_channels,
                        "multichannel_downmix": MULTICHANNEL_DOWNMIX if source_channels > 2 else None}


def load_design(path: str | Path | None) -> dict:
    return read_json(path) if path else {}


def safe_component(value: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", value):
        raise LabError(f"Unsafe cue id or candidate label: {value!r}")
    return value


class TakeLibrary:
    def __init__(self, features: Path, sources: Path | None = None):
        self.features_path = safe_path(features)
        catalogue = read_json(self.features_path.parent / "index.json")
        self.sources = safe_path(sources or catalogue["sources"])
        self.rows: dict[str, list[dict]] = {}
        for row in read_jsonl(self.features_path):
            source_path(self.sources, row["source_path"], row["licence_id"])
            self.rows.setdefault(row["take_id"], []).append(row)
        self.verified: set[tuple[str, str]] = set()

    def get(self, candidate: dict) -> dict:
        rows = self.rows.get(candidate["take"], [])
        if candidate.get("source_path"):
            rows = [row for row in rows if row["source_path"] == candidate["source_path"]]
        if not rows:
            raise LabError(f"Unknown take: {candidate['take']}")
        if len(rows) != 1:
            raise LabError(f"Ambiguous take {candidate['take']}; specify source_path")
        row = rows[0]
        key = row["source_path"], row["source_sha256"]
        if key not in self.verified:
            if sha256(source_path(self.sources, key[0], row["licence_id"])) != key[1]:
                raise LabError(f"Source hash changed: {key[0]}")
            self.verified.add(key)
        return row

    def excerpt(self, row: dict, variant: dict) -> tuple[np.ndarray, int, dict]:
        data, rate = decode(source_path(self.sources, row["source_path"], row["licence_id"]))
        duration = row["end_seconds"] - row["start_seconds"]
        trim = variant.get("trim", [0, duration])
        if not isinstance(trim, list) or len(trim) != 2:
            raise LabError("trim must be [start, end] in seconds relative to the take")
        start, end = (finite(value, "trim") for value in trim)
        if not 0 <= start < end <= duration + 1 / rate:
            raise LabError(f"trim is outside take: {trim}")
        absolute_start = row["start_seconds"] + start
        absolute_end = min(row["end_seconds"], row["start_seconds"] + end)
        data = data[round(absolute_start * rate):round(absolute_end * rate)]
        pitch = finite(variant.get("pitch", 1.0), "pitch")
        if pitch <= 0:
            raise LabError("pitch must be positive")
        ratio = Fraction(OUTPUT_RATE / (rate * pitch)).limit_denominator(RESAMPLE_MAX_DENOMINATOR)
        data = signal.resample_poly(data, ratio.numerator, ratio.denominator, axis=0)
        return data, OUTPUT_RATE, {"trim": [start, end], "pitch": pitch,
                                  "excerpt_start_seconds": absolute_start,
                                  "excerpt_end_seconds": absolute_end,
                                  "resample_ratio": [ratio.numerator, ratio.denominator]}


def fade_in(data: np.ndarray, rate: int) -> np.ndarray:
    count = min(len(data), round(FADE_IN_MS * rate / 1000))
    if count:
        data = data.copy()
        data[:count] *= np.linspace(0, 1, count)[:, None]
    return data


def fade_out(data: np.ndarray, rate: int, milliseconds: float,
             design: dict | None = None) -> np.ndarray:
    milliseconds = finite(milliseconds, "fade_out_ms")
    if milliseconds < 0:
        raise LabError("fade_out_ms must be nonnegative")
    count = min(len(data), round(milliseconds * rate / 1000))
    if count:
        design_value(design or {}, "fade_curve")
        data = data.copy()
        data[-count:] *= np.sin(np.linspace(np.pi / 2, 0, count))[:, None]
    return data


def normalize(data: np.ndarray, rate: int, target: float, peak_target: float | None,
              gain_db: float = 0) -> tuple[np.ndarray, dict]:
    level, method = loudness(data, rate)
    peak = db(float(np.max(np.abs(data))))
    if level is None or peak is None:
        raise LabError("Cannot normalize silent audio")
    if method == "short_rms_dbfs":
        if peak_target is None:
            raise LabError("Short audio requires an approved peak target")
        adjustment = peak_target - peak
        normalization = "short_peak_dbfs"
    else:
        adjustment = target - level
        normalization = method
    adjustment += finite(gain_db, "gain_db")
    requested_adjustment = adjustment
    # UI's peak target and impact's cap apply to long sounds as well.
    if peak_target is not None:
        adjustment = min(adjustment, peak_target - peak)
    if peak + adjustment > 0:
        raise LabError("Normalization would clip; approval must supply a lower gain")
    result = data * 10 ** (adjustment / 20)
    return result, {"normalization": normalization, "target_lufs": target,
                    "peak_target_dbfs": peak_target, "gain_db": gain_db,
                    "applied_gain_db": adjustment, "input_level": level,
                    "input_peak_dbfs": peak, "peak_cap_applied": adjustment < requested_adjustment}


def encode(path: Path, data: np.ndarray, rate: int, codec: str) -> None:
    path = safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    # FFmpeg bitexact makes Ogg use a stable serial rather than random seeds.
    # Both input and output threads are fixed, with no inherited metadata.
    with tempfile.NamedTemporaryFile(dir=path.parent, suffix="." + codec) as temporary:
        if codec == "ogg":
            # PATH's minimal FFmpeg lacks libvorbis. The approved soundfile
            # dependency already ships it through libsndfile; encode q6 here,
            # then bitexact-remux to remove libsndfile's random Ogg serial.
            with tempfile.NamedTemporaryFile(dir=path.parent, suffix=".ogg") as intermediate:
                with sf.SoundFile(intermediate.name, mode="w", samplerate=rate,
                                  channels=data.shape[1], format="OGG", subtype="VORBIS") as audio:
                    quality = sf._ffi.new("double *", VORBIS_QUALITY)
                    result = sf._snd.sf_command(audio._file, SFC_SET_VBR_ENCODING_QUALITY,
                                                quality, sf._ffi.sizeof("double"))
                    if result != sf._snd.SF_TRUE:
                        raise LabError("libsndfile cannot set Vorbis q6")
                    audio.write(data)
                command(["ffmpeg", "-v", "error", "-y", "-threads", "2", "-i", intermediate.name,
                         "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                         "-threads", "2", "-c:a", "copy", "-serial_offset", "0", temporary.name])
        elif codec == "mp3":
            command(["ffmpeg", "-v", "error", "-y", "-threads", "2", "-f", "f32le",
                     "-ar", str(rate), "-ac", str(data.shape[1]), "-i", "pipe:0",
                     "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                     "-threads", "2", "-c:a", "libmp3lame", "-q:a", "4", "-write_xing", "1",
                     "-id3v2_version", "0", "-ar", str(OUTPUT_RATE), temporary.name],
                    input=data.astype("<f4").tobytes())
        else:
            raise LabError(f"Unsupported output codec: {codec}")
        Path(temporary.name).replace(path)


def cli(main) -> None:
    try:
        main()
    except (LabError, KeyError, OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"sfx_lab: {error}") from error
