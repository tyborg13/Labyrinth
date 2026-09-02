from __future__ import annotations

from dataclasses import asdict, dataclass
import math
from pathlib import Path
import shutil
import tempfile

import numpy as np

from .common import PipelineError, read_json, sha256, write_json, write_mono_wave


BANK_SAMPLE_RATE = 16_000
BANK_VERSION = "classical_dark_fantasy_v1"


@dataclass(frozen=True)
class StringSpec:
    bank_id: str
    filename: str
    root_midi: int
    harmonics: tuple[float, ...]
    phase_seed: int
    attack_brightness: float
    signal_quantization_bits: int


@dataclass(frozen=True)
class PercussionSpec:
    bank_id: str
    filename: str
    midi_note: int
    label: str
    duration_seconds: float
    render_gain: float
    pan: int
    signal_quantization_bits: int
    synthesis: str


STRING_SPECS = (
    StringSpec("veiled_violin", "veiled_violin_a4.wav", 69, (1.0, 0.46, 0.24, 0.14, 0.08, 0.045, 0.025), 17, 1.20, 11),
    StringSpec("ashen_violin", "ashen_violin_d4.wav", 62, (1.0, 0.38, 0.20, 0.105, 0.058, 0.03), 29, 1.05, 11),
    StringSpec("hollow_viola", "hollow_viola_c3.wav", 48, (1.0, 0.58, 0.29, 0.17, 0.09, 0.05, 0.025), 43, 0.90, 10),
    StringSpec("grave_cello", "grave_cello_c2.wav", 36, (1.0, 0.72, 0.39, 0.23, 0.13, 0.07, 0.035), 61, 0.78, 10),
    StringSpec("undercrypt_bass", "undercrypt_bass_e1.wav", 28, (1.0, 0.82, 0.42, 0.21, 0.10, 0.045), 79, 0.66, 9),
)

PERCUSSION_SPECS = (
    PercussionSpec("umbra_war_drum", "umbra_war_drum.wav", 36, "Low war drum", 0.72, 0.25, 61, 10, "exponentially swept sinusoidal membrane plus deterministic transient"),
    PercussionSpec("bone_tom", "bone_tom.wav", 41, "Muted bone tom", 0.38, 0.17, 70, 10, "short swept sinusoidal membrane with an inharmonic upper partial"),
    PercussionSpec("ash_tick", "ash_tick.wav", 42, "Ash tick", 0.085, 0.065, 76, 8, "high-passed deterministic integer-noise burst with a quiet metallic partial"),
)


def midi_frequency(pitch: int) -> float:
    return 440.0 * (2.0 ** ((pitch - 69) / 12.0))


def deterministic_phase(seed: int, harmonic: int) -> float:
    value = (seed * 1_103_515_245 + harmonic * 12_345 + 0x9E3779B9) & 0xFFFFFFFF
    return (value / 2**32) * 2.0 * math.pi


def deterministic_noise(length: int, seed: int) -> np.ndarray:
    state = seed & 0xFFFFFFFF
    output = np.empty(length, dtype=np.float64)
    for index in range(length):
        state = (1_664_525 * state + 1_013_904_223) & 0xFFFFFFFF
        output[index] = ((state >> 8) / float(1 << 24)) * 2.0 - 1.0
    return output


def synthesize_string(spec: StringSpec, destination: Path) -> dict[str, object]:
    desired_frequency = midi_frequency(spec.root_midi)
    cycles = max(8, int(round(desired_frequency * 0.32)))
    loop_samples = int(round(cycles * BANK_SAMPLE_RATE / desired_frequency))
    effective_frequency = cycles * BANK_SAMPLE_RATE / loop_samples
    sample_index = np.arange(loop_samples, dtype=np.float64)
    phase = 2.0 * math.pi * cycles * sample_index / loop_samples
    progress = sample_index / max(1, loop_samples - 1)
    sustain = np.zeros(loop_samples, dtype=np.float64)
    attack = np.zeros(loop_samples, dtype=np.float64)
    for harmonic, amplitude in enumerate(spec.harmonics, start=1):
        phase_offset = deterministic_phase(spec.phase_seed, harmonic)
        partial = np.sin(harmonic * phase + phase_offset)
        sustain += amplitude * partial
        start_factor = 1.0 + spec.attack_brightness * (harmonic - 1) / len(spec.harmonics)
        attack += amplitude * (start_factor + (1.0 - start_factor) * progress) * partial
    bow_texture = np.zeros(loop_samples, dtype=np.float64)
    for upper in range(11, 28, 2):
        bow_texture += np.sin(upper * phase + deterministic_phase(spec.phase_seed + 101, upper)) / upper
    sustain += 0.055 * bow_texture
    attack += 0.12 * np.exp(-5.0 * progress) * bow_texture
    sustain /= max(1e-9, float(np.max(np.abs(sustain))))
    attack /= max(1e-9, float(np.max(np.abs(attack))))
    attack *= np.sin(progress * math.pi / 2.0) ** 1.7
    combined = np.concatenate((attack, sustain)) * 0.82
    maximum = float((1 << (spec.signal_quantization_bits - 1)) - 1)
    combined = np.round(combined * maximum) / maximum
    write_mono_wave(destination, combined, BANK_SAMPLE_RATE)
    return {
        **asdict(spec),
        "kind": "looped_string",
        "path": spec.filename,
        "sha256": sha256(destination),
        "sample_rate": BANK_SAMPLE_RATE,
        "channels": 1,
        "sample_width_bits": 16,
        "root_frequency_hz": desired_frequency,
        "stored_effective_frequency_hz": effective_frequency,
        "loop_start_sample": loop_samples,
        "loop_end_sample_exclusive": loop_samples * 2,
        "harmonics": list(spec.harmonics),
        "generator": "deterministic additive sinusoidal bowed-tone synthesis",
    }


def _tail_taper(signal: np.ndarray, milliseconds: float = 12.0) -> np.ndarray:
    count = min(len(signal), max(8, int(round(milliseconds * BANK_SAMPLE_RATE / 1000.0))))
    signal[-count:] *= np.cos(np.linspace(0.0, math.pi / 2.0, count)) ** 2
    return signal


def synthesize_percussion(spec: PercussionSpec, destination: Path) -> dict[str, object]:
    count = int(round(spec.duration_seconds * BANK_SAMPLE_RATE))
    time = np.arange(count, dtype=np.float64) / BANK_SAMPLE_RATE
    progress = time / spec.duration_seconds
    if spec.bank_id == "umbra_war_drum":
        frequency = 47.0 + 66.0 * np.exp(-8.0 * progress)
        phase = np.cumsum(2.0 * math.pi * frequency / BANK_SAMPLE_RATE)
        membrane = np.sin(phase) + 0.24 * np.sin(2.03 * phase + 0.4)
        transient = deterministic_noise(count, 0x810036) * np.exp(-95.0 * time)
        signal = membrane * (1.0 - np.exp(-time / 0.0035)) * np.exp(-4.8 * progress) + 0.11 * transient
    elif spec.bank_id == "bone_tom":
        frequency = 82.0 + 62.0 * np.exp(-10.0 * progress)
        phase = np.cumsum(2.0 * math.pi * frequency / BANK_SAMPLE_RATE)
        membrane = np.sin(phase) + 0.18 * np.sin(2.71 * phase + 0.8)
        signal = membrane * (1.0 - np.exp(-time / 0.0025)) * np.exp(-6.3 * progress)
    else:
        high_passed = np.diff(deterministic_noise(count + 1, 0xA55042))
        metallic = np.sin(2.0 * math.pi * 1760.0 * time + 0.3)
        signal = (0.78 * high_passed + 0.22 * metallic) * np.exp(-11.0 * progress)
    signal = _tail_taper(signal)
    signal /= max(1e-12, float(np.max(np.abs(signal))))
    signal *= 0.80
    maximum = float((1 << (spec.signal_quantization_bits - 1)) - 1)
    signal = np.round(signal * maximum) / maximum
    write_mono_wave(destination, signal, BANK_SAMPLE_RATE)
    return {
        **asdict(spec),
        "kind": "one_shot_percussion",
        "path": spec.filename,
        "sha256": sha256(destination),
        "sample_rate": BANK_SAMPLE_RATE,
        "channels": 1,
        "sample_width_bits": 16,
        "frames": len(signal),
        "generator": "deterministic local mathematical synthesis",
    }


def _build_bank(destination: Path) -> dict[str, object]:
    destination.mkdir(parents=True, exist_ok=True)
    samples = [synthesize_string(spec, destination / spec.filename) for spec in STRING_SPECS]
    samples.extend(synthesize_percussion(spec, destination / spec.filename) for spec in PERCUSSION_SPECS)
    manifest = {
        "schema_version": 1,
        "bank_id": BANK_VERSION,
        "name": "Escape the Umbra Procedural Dark Fantasy Ensemble v1",
        "provenance": "Generated locally from mathematical sinusoidal partials, oscillators, fixed integer seeds, and deterministic envelopes. No recording, sample pack, SoundFont, ROM, model output, or third-party audio was used.",
        "commercial_use_status": "Original project-generated assets with no third-party audio rights input; intended for unrestricted use in Escape the Umbra and its distributed builds.",
        "sample_rate": BANK_SAMPLE_RATE,
        "samples": samples,
    }
    write_json(destination / "bank_manifest.json", manifest)
    return {**manifest, "manifest_sha256": sha256(destination / "bank_manifest.json")}


def generate_bank(destination: Path) -> dict[str, object]:
    """Create the versioned bank or prove that its checked-in bytes still match."""
    destination = destination.resolve()
    with tempfile.TemporaryDirectory(prefix="labyrinth-classical-bank-") as temporary:
        candidate = Path(temporary) / BANK_VERSION
        generated = _build_bank(candidate)
        existing_manifest = destination / "bank_manifest.json"
        if existing_manifest.is_file():
            names = ["bank_manifest.json", *(str(sample["path"]) for sample in generated["samples"])]
            drifted = [name for name in names if not (destination / name).is_file() or (destination / name).read_bytes() != (candidate / name).read_bytes()]
            if drifted:
                raise PipelineError(
                    f"Refusing to mutate immutable bank {BANK_VERSION}; create a new bank version. Drifted files: {drifted}"
                )
            existing = read_json(existing_manifest)
            return {**existing, "manifest_sha256": sha256(existing_manifest)}
        if destination.exists() and any(destination.iterdir()):
            raise PipelineError(f"Refusing to initialize a bank inside non-empty directory: {destination}")
        destination.mkdir(parents=True, exist_ok=True)
        for source in candidate.iterdir():
            shutil.copyfile(source, destination / source.name)
        return generated
