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
DESIGNED_SOURCE = "designed"
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


class SourceRoots:
    """Validated index roots; str preserves the list across legacy worker jobs."""
    def __init__(self, roots):
        if not roots or not all(isinstance(root, (str, Path)) for root in roots):
            raise LabError("sources must contain at least one source root")
        self.roots = tuple(safe_path(root) for root in roots)
        if not all(isinstance(root, Path) for root in self.roots):
            raise LabError("Nested source roots are invalid")

    def __str__(self):
        return json.dumps([str(root) for root in self.roots])


def safe_path(path: str | Path | list | SourceRoots) -> Path | SourceRoots:
    """Reject excluded lexical paths AND symlink destinations before opening."""
    if isinstance(path, SourceRoots):
        return SourceRoots(path.roots)
    if isinstance(path, list):
        return SourceRoots(path)
    # slice's existing worker interface carries roots as str(safe_path(sources)).
    if str(path).startswith("["):
        try:
            roots = json.loads(str(path))
        except json.JSONDecodeError:
            roots = None
        if isinstance(roots, list):
            return SourceRoots(roots)
    value = Path(path).expanduser()
    for candidate in (value, value.resolve()):
        if any(part.lower() == "mixkit" or part.lower().startswith("sfx-sources-excluded")
               for part in candidate.parts):
            raise LabError(f"Excluded source path: {path}")
    return value.resolve()


def source_path(root: str | Path | list | SourceRoots, relative: str,
                licence_id: str | None = None) -> Path:
    root = safe_path(root)
    rel = Path(relative)
    if rel.is_absolute() or ".." in rel.parts or not rel.parts:
        raise LabError(f"Source path must be relative to the approved root: {relative}")
    safe_path(relative)
    if rel.parts[0] not in SOURCE_LICENSES and rel.parts[0] != DESIGNED_SOURCE:
        raise LabError(f"Unapproved source: {relative}")
    if isinstance(root, SourceRoots):
        matches = []
        for item in root.roots:
            candidate = safe_path(item / rel)
            if candidate.is_file():
                matches.append(source_path(item, relative, licence_id))
        if len(matches) != 1:
            raise LabError(f"Source path must resolve in exactly one root: {relative}")
        return matches[0]
    result = safe_path(root / rel)
    if not result.is_relative_to(root / rel.parts[0]):
        raise LabError(f"Source escapes its library: {relative}")
    actual_licence = (designed_licence(result) if rel.parts[0] == DESIGNED_SOURCE
                      else SOURCE_LICENSES[rel.parts[0]])
    if licence_id is not None and licence_id != actual_licence:
        raise LabError(f"Licence mismatch: {relative}")
    return result


def derive_licence(layers: list[dict]) -> str:
    if not layers:
        raise LabError("A designed source requires layer provenance")
    licences = []
    for layer in layers:
        relative = layer["source_path"]
        safe_path(relative)
        rel = Path(relative)
        if rel.is_absolute() or ".." in rel.parts or not rel.parts:
            raise LabError(f"Invalid layer source path: {relative}")
        folder = rel.parts[0]
        licence = layer["licence_id"]
        if folder == DESIGNED_SOURCE:
            if licence not in SOURCE_LICENSES.values():
                raise LabError(f"Invalid designed layer licence: {relative}")
        elif folder not in SOURCE_LICENSES or licence != SOURCE_LICENSES[folder]:
            raise LabError(f"Invalid layer licence: {relative}")
        licences.append(licence)
    return (SOURCE_LICENSES["sonniss_gdc"] if SOURCE_LICENSES["sonniss_gdc"] in licences
            else SOURCE_LICENSES["kenney"])


def designed_licence(path: Path) -> str:
    """The per-file sidecar, not the folder licence, owns derivative provenance."""
    try:
        sidecar = read_json(path.with_suffix(".json"))
        if not isinstance(sidecar["recipe"], dict):
            raise LabError("Missing recipe entry")
        layers = sidecar["layers"]
        if not isinstance(layers, list) or not layers:
            raise LabError("Missing layers")
        if len(sidecar["recipe"]["layers"]) != len(layers):
            raise LabError("Inconsistent recipe layers")
        for layer, recipe_layer in zip(layers, sidecar["recipe"]["layers"]):
            if layer["take_id"] != recipe_layer["take"]:
                raise LabError("Inconsistent take identity")
            if recipe_layer.get("source_path", layer["source_path"]) != layer["source_path"]:
                raise LabError("Inconsistent source path")
            if not re.fullmatch(r"[0-9a-f]{64}", layer["source_sha256"]):
                raise LabError("Invalid source hash")
            if not re.fullmatch(re.escape(layer["source_sha256"][:12]) + r"#[1-9][0-9]*",
                                layer["take_id"]):
                raise LabError("Take identity does not match source hash")
            start = finite(layer["start_seconds"], "start_seconds")
            end = finite(layer["end_seconds"], "end_seconds")
            if not 0 <= start < end:
                raise LabError("Invalid take range")
        licence = derive_licence(layers)
        if sidecar["licence_id"] != licence:
            raise LabError("Incorrect derived licence")
        return licence
    except (LabError, OSError, KeyError, TypeError, AttributeError, json.JSONDecodeError) as error:
        raise LabError(f"Missing or invalid designed sidecar: {path.with_suffix('.json')}: {error}") from error


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
        self.sources = safe_path(catalogue["sources"])
        self.relocated = None
        if sources is not None:
            relocated = safe_path(sources)
            if isinstance(self.sources, SourceRoots) and isinstance(relocated, Path):
                # A single --sources can relocate either tree, or a combined tree.
                self.relocated = relocated
            else:
                self.sources = relocated
        self.rows: dict[str, list[dict]] = {}
        for row in read_jsonl(self.features_path):
            self.path(row)
            self.rows.setdefault(row["take_id"], []).append(row)
        self.verified: set[tuple[str, str]] = set()

    def path(self, row: dict) -> Path:
        relative = row["source_path"]
        if self.relocated is not None:
            candidate = safe_path(self.relocated / relative)
            if candidate.is_file():
                return source_path(self.relocated, relative, row["licence_id"])
        return source_path(self.sources, relative, row["licence_id"])

    def get(self, candidate: dict) -> dict:
        if candidate.get("source_path"):
            safe_path(candidate["source_path"])
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
            if sha256(self.path(row)) != key[1]:
                raise LabError(f"Source hash changed: {key[0]}")
            self.verified.add(key)
        return row

    def excerpt(self, row: dict, variant: dict) -> tuple[np.ndarray, int, dict]:
        data, rate = decode(self.path(row))
        duration = row["end_seconds"] - row["start_seconds"]
        trim = variant.get("trim", [0, duration])
        if not isinstance(trim, list) or len(trim) != 2:
            raise LabError("trim must be [start, end] in seconds relative to the take")
        start = finite(trim[0], "trim")
        end = duration if trim[1] is None else finite(trim[1], "trim")
        if not 0 <= start < end <= duration + 1 / rate:
            raise LabError(f"trim is outside take: {trim}")
        absolute_start = row["start_seconds"] + start
        absolute_end = min(row["end_seconds"], row["start_seconds"] + end)
        data = data[round(absolute_start * rate):round(absolute_end * rate)]
        pitch = finite(variant.get("pitch", 1.0), "pitch")
        if pitch <= 0:
            raise LabError("pitch must be positive")
        ratio = Fraction(OUTPUT_RATE / (rate * pitch)).limit_denominator(RESAMPLE_MAX_DENOMINATOR)
        data = resample_audio(data, rate, OUTPUT_RATE, pitch)
        return data, OUTPUT_RATE, {"trim": [start, end], "pitch": pitch,
                                  "excerpt_start_seconds": absolute_start,
                                  "excerpt_end_seconds": absolute_end,
                                  "resample_ratio": [ratio.numerator, ratio.denominator]}


def resample_audio(data: np.ndarray, rate: int, output_rate: int,
                   pitch: float = 1.0) -> np.ndarray:
    ratio = Fraction(output_rate / (rate * pitch)).limit_denominator(RESAMPLE_MAX_DENOMINATOR)
    return signal.resample_poly(data, ratio.numerator, ratio.denominator, axis=0)


def fade_in(data: np.ndarray, rate: int, milliseconds: float = FADE_IN_MS) -> np.ndarray:
    milliseconds = finite(milliseconds, "fade_in_ms")
    if milliseconds < 0:
        raise LabError("fade_in_ms must be nonnegative")
    count = min(len(data), round(milliseconds * rate / 1000))
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
    # Never clip: cap the gain so the peak lands at -1 dBFS (recorded as a peak cap).
    adjustment = min(adjustment, -1.0 - peak)
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
