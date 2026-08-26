from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from typing import TYPE_CHECKING
import wave

if TYPE_CHECKING:
    import numpy as np


class PipelineError(RuntimeError):
    """A user-actionable soundtrack pipeline failure."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PipelineError(f"Could not read JSON from {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise PipelineError(f"Expected a JSON object in {path}")
    return value


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def resolve_from(config_path: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else (config_path.parent / path).resolve()


def require_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise PipelineError(f"Missing {label}: {path}")


def verify_source_clearance(config: dict[str, object], config_path: Path) -> dict[str, object]:
    source = config.get("source")
    if not isinstance(source, dict):
        raise PipelineError("track config is missing its source object")
    if source.get("rights_status") != "cleared":
        raise PipelineError(
            "Source rights are not cleared. Complete LICENSE_SOURCE.md and set "
            'source.rights_status to "cleared" only after the evidence is unambiguous.'
        )
    if source.get("composition_public_domain") is not True:
        raise PipelineError("The composition must be explicitly marked public domain")
    for key in ("composer", "composition", "source_url", "source_format", "transcription_license", "license_evidence", "date_retrieved"):
        if not str(source.get(key, "")).strip():
            raise PipelineError(f"source.{key} must be documented before transformation")
    source_path = resolve_from(config_path, str(source.get("path", "")))
    license_path = resolve_from(config_path, str(source.get("license_file", "LICENSE_SOURCE.md")))
    require_file(source_path, "immutable source")
    require_file(license_path, "source license record")
    expected = str(source.get("sha256", "")).lower()
    actual = sha256(source_path)
    if len(expected) != 64 or actual != expected:
        raise PipelineError(f"Source hash mismatch for {source_path}: expected {expected}, got {actual}")
    license_text = license_path.read_text(encoding="utf-8")
    required_evidence = (str(source["source_url"]), expected, str(source["transcription_license"]), str(source["date_retrieved"]))
    missing = [item for item in required_evidence if item not in license_text]
    if missing:
        raise PipelineError(f"LICENSE_SOURCE.md is missing config evidence: {missing}")
    return {
        "path": str(source_path),
        "sha256": actual,
        "license_file": str(license_path),
        "transcription_license": str(source["transcription_license"]),
    }


def write_mono_wave(path: Path, samples: "np.ndarray", sample_rate: int) -> None:
    import numpy as np

    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(np.round(samples * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(pcm.tobytes())


def write_stereo_wave(path: Path, audio: "np.ndarray", sample_rate: int) -> None:
    import numpy as np

    pcm = np.clip(np.round(audio * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(pcm.tobytes())


def load_mono_wave(path: Path) -> tuple["np.ndarray", int]:
    import numpy as np

    with wave.open(str(path), "rb") as handle:
        if handle.getnchannels() != 1 or handle.getsampwidth() != 2:
            raise PipelineError(f"Expected 16-bit mono WAV: {path}")
        rate = handle.getframerate()
        frames = handle.readframes(handle.getnframes())
    return np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32768.0, rate


def ogg_crc(page: bytes | bytearray) -> int:
    table: list[int] = []
    for value in range(256):
        remainder = value << 24
        for _ in range(8):
            remainder = ((remainder << 1) ^ 0x04C11DB7) & 0xFFFFFFFF if remainder & 0x80000000 else (remainder << 1) & 0xFFFFFFFF
        table.append(remainder)
    checksum = 0
    for value in page:
        checksum = ((checksum << 8) & 0xFFFFFFFF) ^ table[((checksum >> 24) & 0xFF) ^ value]
    return checksum


def normalize_ogg_serial(path: Path, serial: int) -> None:
    """Replace FFmpeg's random Ogg serial and repair every page CRC."""
    data = bytearray(path.read_bytes())
    offset = 0
    page_count = 0
    while offset < len(data):
        if data[offset : offset + 4] != b"OggS":
            raise PipelineError(f"Invalid Ogg page capture at byte {offset}")
        segment_count = data[offset + 26]
        header_end = offset + 27 + segment_count
        page_end = header_end + sum(data[offset + 27 : header_end])
        if page_end > len(data):
            raise PipelineError("Truncated Ogg page")
        data[offset + 14 : offset + 18] = serial.to_bytes(4, "little")
        data[offset + 22 : offset + 26] = b"\x00\x00\x00\x00"
        data[offset + 22 : offset + 26] = ogg_crc(data[offset:page_end]).to_bytes(4, "little")
        offset = page_end
        page_count += 1
    if page_count == 0:
        raise PipelineError("Ogg file contained no pages")
    path.write_bytes(data)


def require_executable(name: str) -> str:
    executable = shutil.which(name)
    if executable is None:
        raise PipelineError(f"Required executable is not available: {name}")
    return executable


def run_json(command: list[str]) -> dict[str, object]:
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        parsed = json.loads(result.stdout)
    except (subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        raise PipelineError(f"Command failed: {' '.join(command)}") from exc
    if not isinstance(parsed, dict):
        raise PipelineError(f"Expected JSON output from {' '.join(command)}")
    return parsed
