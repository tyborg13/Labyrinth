#!/usr/bin/env python3
"""Build the condensed, sample-bank-rendered Schubert tactical loop.

This additive version-2 build leaves every faithful version-1 artifact unchanged.
It selects three measure-aligned regions from the expanded public-domain source,
assembles an A-B-C-B-A loop, generates a deterministic procedural sample bank,
and renders compact Ogg Vorbis plus lossless FLAC previews.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
from dataclasses import asdict, dataclass
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

if sys.version_info < (3, 12):
    raise SystemExit(
        "This reproducible build requires Python 3.12 or newer; "
        f"found {sys.version.split()[0]}"
    )

import mido
import numpy as np

import build_arrangement as base


POC_ROOT = Path(__file__).resolve().parents[1]
BANK_DIR = POC_ROOT / "procedural_bank"
BANK_MANIFEST = BANK_DIR / "bank_manifest.json"
ARRANGEMENT_MIDI = POC_ROOT / "active_tactical_loop.mid"
AUDIO_OGG = POC_ROOT / "active_tactical_loop_preview.ogg"
AUDIO_FLAC = POC_ROOT / "active_tactical_loop_preview.flac"
BUILD_REPORT = POC_ROOT / "ACTIVE_TACTICAL_LOOP_REPORT.json"

TEMPO_QPM = 92
TICKS_PER_BEAT = 480
OUTPUT_SAMPLE_RATE = 44_100
BANK_SAMPLE_RATE = 16_000
CROSSFADE_QUARTERS = 4.0
OGG_SERIAL = 0x53383230  # ASCII "S820": Schubert/version 2/loop 0.


@dataclass(frozen=True)
class SourceSegment:
    key: str
    source_start_ql: float
    source_end_ql: float
    performed_measure_start: int
    performed_measure_end: int
    requested_window: str

    @property
    def duration_ql(self) -> float:
        return self.source_end_ql - self.source_start_ql


SOURCE_SEGMENTS = {
    "A": SourceSegment("A", 192.0, 256.0, 25, 32, "2:05-2:45"),
    "B": SourceSegment("B", 384.0, 480.0, 49, 64, "4:10-5:10"),
    "C": SourceSegment("C", 576.0, 672.0, 73, 88, "6:15-7:17"),
}
FORM = ("A", "B", "C", "B", "A")


@dataclass(frozen=True)
class FormSection:
    label: str
    segment_key: str
    occurrence_index: int
    destination_start_ql: float
    destination_end_ql: float


def form_sections() -> tuple[FormSection, ...]:
    destination = 0.0
    occurrences: dict[str, int] = defaultdict(int)
    sections: list[FormSection] = []
    for key in FORM:
        occurrences[key] += 1
        segment = SOURCE_SEGMENTS[key]
        label = f"{key}{occurrences[key]}"
        sections.append(
            FormSection(
                label,
                key,
                occurrences[key] - 1,
                destination,
                destination + segment.duration_ql,
            )
        )
        destination += segment.duration_ql
    return tuple(sections)


FORM_SECTIONS = form_sections()
LOOP_QUARTERS = FORM_SECTIONS[-1].destination_end_ql


@dataclass(frozen=True)
class LoopTrackSpec:
    name: str
    source_track: str
    channel: int
    program: int
    volume: int
    pan: int
    bank_id: str
    render_gain: float
    velocity_adjust: int
    duration_scale: float
    release_seconds: float
    vibrato_cents: float
    vibrato_hz: float


LOOP_TRACKS = (
    LoopTrackSpec(
        "Veiled Bow / Violin I",
        "Pulse I / Violin I",
        0,
        48,
        78,
        80,
        "veiled_violin",
        0.42,
        -6,
        0.80,
        0.10,
        3.5,
        5.1,
    ),
    LoopTrackSpec(
        "Ashen Bow / Violin II",
        "Pulse II / Violin II",
        1,
        49,
        68,
        48,
        "ashen_violin",
        0.32,
        -9,
        0.74,
        0.10,
        2.8,
        4.7,
    ),
    LoopTrackSpec(
        "Hollow Viola",
        "Triangle / Viola",
        2,
        50,
        84,
        70,
        "hollow_viola",
        0.50,
        -2,
        0.94,
        0.13,
        2.0,
        4.4,
    ),
    LoopTrackSpec(
        "Grave Cello",
        "Low Triangle / Cello",
        3,
        42,
        110,
        58,
        "grave_cello",
        0.82,
        10,
        1.08,
        0.19,
        1.6,
        4.0,
    ),
    LoopTrackSpec(
        "Undercrypt Bass / Cello -8ve",
        "Sub-Bass Shadow / Cello -8ve",
        4,
        43,
        96,
        64,
        "undercrypt_bass",
        0.66,
        10,
        1.10,
        0.24,
        0.8,
        3.4,
    ),
)


@dataclass(frozen=True)
class ArrangedEvent:
    start_ql: float
    duration_ql: float
    pitch: int
    velocity: int
    source_start_ql: float
    source_end_ql: float
    source_pitch: int
    source_track: str
    section_label: str

    @property
    def end_ql(self) -> float:
        return self.start_ql + self.duration_ql


@dataclass(frozen=True)
class BankSpec:
    bank_id: str
    filename: str
    root_midi: int
    harmonics: tuple[float, ...]
    phase_seed: int
    attack_brightness: float
    quantization_bits: int


BANK_SPECS = (
    BankSpec(
        "veiled_violin",
        "veiled_violin_a4.wav",
        69,
        (1.0, 0.46, 0.24, 0.14, 0.08, 0.045, 0.025),
        17,
        1.20,
        11,
    ),
    BankSpec(
        "ashen_violin",
        "ashen_violin_d4.wav",
        62,
        (1.0, 0.38, 0.20, 0.105, 0.058, 0.03),
        29,
        1.05,
        11,
    ),
    BankSpec(
        "hollow_viola",
        "hollow_viola_c3.wav",
        48,
        (1.0, 0.58, 0.29, 0.17, 0.09, 0.05, 0.025),
        43,
        0.90,
        10,
    ),
    BankSpec(
        "grave_cello",
        "grave_cello_c2.wav",
        36,
        (1.0, 0.72, 0.39, 0.23, 0.13, 0.07, 0.035),
        61,
        0.78,
        10,
    ),
    BankSpec(
        "undercrypt_bass",
        "undercrypt_bass_e1.wav",
        28,
        (1.0, 0.82, 0.42, 0.21, 0.10, 0.045),
        79,
        0.66,
        9,
    ),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def midi_frequency(pitch: int) -> float:
    return 440.0 * (2.0 ** ((pitch - 69) / 12.0))


def seconds_for_quarters(quarters: float) -> float:
    return quarters * 60.0 / TEMPO_QPM


def source_timestamp(quarters: float) -> float:
    return seconds_for_quarters(quarters)


def source_events() -> dict[str, list[base.NoteEvent]]:
    base.verify_immutable_source()
    score = base.expanded_performance_score(base.parse_normalized_score())
    parts = {part.partName: part for part in score.parts}
    events: dict[str, list[base.NoteEvent]] = {}
    for spec in base.TRACK_SPECS:
        part = parts.get(spec.source_part)
        if part is None:
            raise RuntimeError(f"Missing normalized source part {spec.source_part}")
        events[spec.name] = base.part_note_events(part, spec)
    events[base.BASS_SPEC.name] = base.bass_shadow_events(
        events[base.TRACK_SPECS[-1].name]
    )
    return events


def keep_upper_event(
    spec: LoopTrackSpec,
    event: base.NoteEvent,
    local_index: int,
    occurrence_index: int,
) -> bool:
    """Thin only short upper-voice motion with stable, documented patterns."""
    if event.duration_ql > 0.75:
        return True
    if spec.source_track == "Pulse I / Violin I":
        return (local_index + occurrence_index * 2) % 5 != 1
    if spec.source_track == "Pulse II / Violin II":
        modulus = 2 if occurrence_index > 0 else 3
        return (local_index + occurrence_index) % modulus != 1
    return True


def clamp_monophonic(events: list[ArrangedEvent]) -> list[ArrangedEvent]:
    ordered = sorted(events, key=lambda event: (event.start_ql, event.pitch))
    clamped: list[ArrangedEvent] = []
    for index, event in enumerate(ordered):
        duration = event.duration_ql
        if index + 1 < len(ordered):
            next_start = ordered[index + 1].start_ql
            if event.start_ql + duration >= next_start:
                duration = max(0.02, (next_start - event.start_ql) * 0.97)
        duration = min(duration, LOOP_QUARTERS - event.start_ql)
        if duration <= 0:
            continue
        clamped.append(
            ArrangedEvent(
                event.start_ql,
                duration,
                event.pitch,
                event.velocity,
                event.source_start_ql,
                event.source_end_ql,
                event.source_pitch,
                event.source_track,
                event.section_label,
            )
        )
    return clamped


def build_track_events() -> tuple[dict[str, list[ArrangedEvent]], dict[str, object]]:
    original = source_events()
    output: dict[str, list[ArrangedEvent]] = {}
    thinning: dict[str, dict[str, int]] = {}

    for spec in LOOP_TRACKS[:-1]:
        arranged: list[ArrangedEvent] = []
        considered = 0
        dropped = 0
        for section in FORM_SECTIONS:
            segment = SOURCE_SEGMENTS[section.segment_key]
            selected = [
                event
                for event in original[spec.source_track]
                if event.start_ql < segment.source_end_ql
                and event.end_ql > segment.source_start_ql
            ]
            for local_index, event in enumerate(selected):
                considered += 1
                if not keep_upper_event(
                    spec, event, local_index, section.occurrence_index
                ):
                    dropped += 1
                    continue
                source_start = max(event.start_ql, segment.source_start_ql)
                source_end = min(event.end_ql, segment.source_end_ql)
                start = section.destination_start_ql + (
                    source_start - segment.source_start_ql
                )
                available = section.destination_end_ql - start
                duration = min(
                    max(0.02, (source_end - source_start) * spec.duration_scale),
                    available,
                )
                velocity = max(28, min(88, event.velocity + spec.velocity_adjust))
                arranged.append(
                    ArrangedEvent(
                        round(start, 8),
                        round(duration, 8),
                        event.pitch,
                        velocity,
                        source_start,
                        source_end,
                        event.pitch,
                        spec.source_track,
                        section.label,
                    )
                )
        output[spec.name] = clamp_monophonic(arranged)
        thinning[spec.name] = {"considered": considered, "dropped": dropped}

    cello_spec = LOOP_TRACKS[-2]
    bass_spec = LOOP_TRACKS[-1]
    bass_events: list[ArrangedEvent] = []
    for event in output[cello_spec.name]:
        transposed = event.pitch - 12
        if transposed < 28:
            continue
        bass_events.append(
            ArrangedEvent(
                event.start_ql,
                event.duration_ql,
                transposed,
                max(30, min(88, event.velocity + 2)),
                event.source_start_ql,
                event.source_end_ql,
                event.source_pitch,
                cello_spec.source_track,
                event.section_label,
            )
        )
    output[bass_spec.name] = bass_events
    thinning[bass_spec.name] = {
        "considered": len(output[cello_spec.name]),
        "dropped": len(output[cello_spec.name]) - len(bass_events),
    }
    return output, {"thinning": thinning}


def ticks(quarters: float) -> int:
    return int(round(quarters * TICKS_PER_BEAT))


def midi_note_track(
    spec: LoopTrackSpec, events: list[ArrangedEvent]
) -> mido.MidiTrack:
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name=spec.name, time=0))
    track.append(
        mido.MetaMessage(
            "instrument_name",
            name=(
                f"Procedural bank sample {spec.bank_id}; GM program is fallback only"
            ),
            time=0,
        )
    )
    track.append(
        mido.Message(
            "program_change", channel=spec.channel, program=spec.program, time=0
        )
    )
    track.append(
        mido.Message(
            "control_change", channel=spec.channel, control=7, value=spec.volume, time=0
        )
    )
    track.append(
        mido.Message(
            "control_change", channel=spec.channel, control=10, value=spec.pan, time=0
        )
    )

    timed: list[tuple[int, int, mido.Message]] = []
    for event in events:
        start_tick = ticks(event.start_ql)
        end_tick = max(start_tick + 1, ticks(event.end_ql))
        timed.append(
            (
                start_tick,
                1,
                mido.Message(
                    "note_on",
                    channel=spec.channel,
                    note=event.pitch,
                    velocity=event.velocity,
                    time=0,
                ),
            )
        )
        timed.append(
            (
                end_tick,
                0,
                mido.Message(
                    "note_off",
                    channel=spec.channel,
                    note=event.pitch,
                    velocity=0,
                    time=0,
                ),
            )
        )
    timed.sort(key=lambda item: (item[0], item[1], item[2].note))
    previous_tick = 0
    for absolute_tick, _, message in timed:
        track.append(message.copy(time=absolute_tick - previous_tick))
        previous_tick = absolute_tick
    track.append(
        mido.MetaMessage(
            "end_of_track", time=max(0, ticks(LOOP_QUARTERS) - previous_tick)
        )
    )
    return track


def conductor_track() -> mido.MidiTrack:
    track = mido.MidiTrack()
    track.append(
        mido.MetaMessage("track_name", name="Conductor / Loop Map", time=0)
    )
    track.append(
        mido.MetaMessage(
            "copyright",
            text=(
                "Franz Schubert composition: public domain. OpenScore source: CC0. "
                "Procedural bank and arrangement created for Escape the Umbra."
            ),
            time=0,
        )
    )
    track.append(
        mido.MetaMessage(
            "text", text="OpenScore source SHA-256: " + base.EXPECTED_SOURCE_SHA256, time=0
        )
    )
    track.append(
        mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0)
    )
    track.append(mido.MetaMessage("key_signature", key="Gm", time=0))
    track.append(
        mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(TEMPO_QPM), time=0)
    )

    markers: list[tuple[int, str]] = [(0, "LOOP_START / structural MIDI")]
    for section in FORM_SECTIONS:
        segment = SOURCE_SEGMENTS[section.segment_key]
        markers.append(
            (
                ticks(section.destination_start_ql),
                (
                    f"{section.label}: source performed measures "
                    f"{segment.performed_measure_start}-{segment.performed_measure_end}"
                ),
            )
        )
    markers.append(
        (
            ticks(LOOP_QUARTERS),
            (
                "LOOP_END / rendered audio uses a one-measure equal-power "
                "crossfade and rotation"
            ),
        )
    )
    previous_tick = 0
    for absolute_tick, text in markers:
        track.append(
            mido.MetaMessage(
                "marker", text=text, time=absolute_tick - previous_tick
            )
        )
        previous_tick = absolute_tick
    track.append(mido.MetaMessage("end_of_track", time=0))
    return track


def write_midi(
    events_by_track: dict[str, list[ArrangedEvent]],
) -> dict[str, object]:
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    midi.tracks.append(conductor_track())
    for spec in LOOP_TRACKS:
        midi.tracks.append(midi_note_track(spec, events_by_track[spec.name]))
    midi.save(ARRANGEMENT_MIDI)

    return {
        "path": ARRANGEMENT_MIDI.name,
        "sha256": sha256(ARRANGEMENT_MIDI),
        "tempo_qpm": TEMPO_QPM,
        "ticks_per_beat": TICKS_PER_BEAT,
        "structural_duration_quarters": LOOP_QUARTERS,
        "structural_duration_seconds": seconds_for_quarters(LOOP_QUARTERS),
        "musical_voice_tracks": len(LOOP_TRACKS),
        "note_counts": {
            name: len(events) for name, events in events_by_track.items()
        },
        "pitch_ranges_midi": {
            name: [
                min(event.pitch for event in events),
                max(event.pitch for event in events),
            ]
            for name, events in events_by_track.items()
        },
    }


def deterministic_phase(seed: int, harmonic: int) -> float:
    value = (seed * 1_103_515_245 + harmonic * 12_345 + 0x9E3779B9) & 0xFFFFFFFF
    return (value / 2**32) * 2.0 * math.pi


def write_mono_wave(path: Path, samples: np.ndarray, sample_rate: int) -> None:
    pcm = np.clip(np.round(samples * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(pcm.tobytes())


def synthesize_bank_sample(spec: BankSpec) -> dict[str, object]:
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
        harmonic_envelope = start_factor + (1.0 - start_factor) * progress
        attack += amplitude * harmonic_envelope * partial

    # A deterministic, periodic bow texture made only from upper sinusoidal partials.
    bow_texture = np.zeros(loop_samples, dtype=np.float64)
    for upper in range(11, 28, 2):
        phase_offset = deterministic_phase(spec.phase_seed + 101, upper)
        bow_texture += np.sin(upper * phase + phase_offset) / upper
    sustain += 0.055 * bow_texture
    attack += 0.12 * np.exp(-5.0 * progress) * bow_texture

    sustain /= max(1e-9, float(np.max(np.abs(sustain))))
    attack /= max(1e-9, float(np.max(np.abs(attack))))
    attack_envelope = np.sin(progress * math.pi / 2.0) ** 1.7
    attack *= attack_envelope

    combined = np.concatenate((attack, sustain)) * 0.82
    quantization_max = float((1 << (spec.quantization_bits - 1)) - 1)
    combined = np.round(combined * quantization_max) / quantization_max
    destination = BANK_DIR / spec.filename
    write_mono_wave(destination, combined, BANK_SAMPLE_RATE)
    return {
        "bank_id": spec.bank_id,
        "path": str(destination.relative_to(POC_ROOT)),
        "sha256": sha256(destination),
        "sample_rate": BANK_SAMPLE_RATE,
        "channels": 1,
        "sample_width_bits": 16,
        "signal_quantization_bits": spec.quantization_bits,
        "root_midi": spec.root_midi,
        "root_frequency_hz": desired_frequency,
        "stored_effective_frequency_hz": effective_frequency,
        "loop_start_sample": loop_samples,
        "loop_end_sample_exclusive": loop_samples * 2,
        "harmonics": list(spec.harmonics),
        "phase_seed": spec.phase_seed,
        "attack_brightness": spec.attack_brightness,
        "generator": "deterministic additive sinusoidal bowed-tone synthesis",
    }


def generate_bank() -> dict[str, object]:
    BANK_DIR.mkdir(parents=True, exist_ok=True)
    samples = [synthesize_bank_sample(spec) for spec in BANK_SPECS]
    manifest = {
        "name": "Escape the Umbra Procedural Mourning Strings v1",
        "provenance": (
            "Generated locally from mathematical sinusoidal partials and fixed integer "
            "phase seeds. No recording, sample pack, SoundFont, model output, or "
            "third-party audio was used."
        ),
        "commercial_use_status": (
            "Original project-generated assets with no third-party audio rights input; "
            "intended for unrestricted use in Escape the Umbra and its distributed builds."
        ),
        "sample_rate": BANK_SAMPLE_RATE,
        "samples": samples,
    }
    BANK_MANIFEST.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    manifest["manifest_path"] = str(BANK_MANIFEST.relative_to(POC_ROOT))
    manifest["manifest_sha256"] = sha256(BANK_MANIFEST)
    return manifest


@dataclass(frozen=True)
class RenderNote:
    start_seconds: float
    end_seconds: float
    pitch: int
    velocity: int


def midi_track_name(track: mido.MidiTrack) -> str:
    for message in track:
        if message.type == "track_name":
            return message.name
    return ""


def read_midi_notes() -> dict[str, list[RenderNote]]:
    midi = mido.MidiFile(ARRANGEMENT_MIDI)
    seconds_per_tick = 60.0 / (TEMPO_QPM * midi.ticks_per_beat)
    known = {spec.name for spec in LOOP_TRACKS}
    output: dict[str, list[RenderNote]] = {}
    for track in midi.tracks:
        name = midi_track_name(track)
        if name not in known:
            continue
        active: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
        absolute_tick = 0
        notes: list[RenderNote] = []
        for message in track:
            absolute_tick += message.time
            if message.type == "note_on" and message.velocity > 0:
                active[(message.channel, message.note)].append(
                    (absolute_tick, message.velocity)
                )
            elif message.type == "note_off" or (
                message.type == "note_on" and message.velocity == 0
            ):
                key = (message.channel, message.note)
                if not active[key]:
                    raise RuntimeError(f"Unmatched note-off in {name}: {message.note}")
                start_tick, velocity = active[key].pop(0)
                notes.append(
                    RenderNote(
                        start_tick * seconds_per_tick,
                        absolute_tick * seconds_per_tick,
                        message.note,
                        velocity,
                    )
                )
        if any(active.values()):
            raise RuntimeError(f"Hanging MIDI notes in {name}")
        output[name] = sorted(notes, key=lambda item: item.start_seconds)
    return output


def load_bank_wave(sample_info: dict[str, object]) -> np.ndarray:
    path = POC_ROOT / str(sample_info["path"])
    with wave.open(str(path), "rb") as handle:
        if handle.getnchannels() != 1 or handle.getsampwidth() != 2:
            raise RuntimeError(f"Unexpected bank WAV format: {path}")
        frames = handle.readframes(handle.getnframes())
    return np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32768.0


def sampled_note(
    note: RenderNote,
    track: LoopTrackSpec,
    sample_info: dict[str, object],
    sample_data: np.ndarray,
) -> np.ndarray:
    note_seconds = max(1.0 / OUTPUT_SAMPLE_RATE, note.end_seconds - note.start_seconds)
    total_samples = max(
        1, int(round((note_seconds + track.release_seconds) * OUTPUT_SAMPLE_RATE))
    )
    time = np.arange(total_samples, dtype=np.float64) / OUTPUT_SAMPLE_RATE
    target_frequency = midi_frequency(note.pitch)
    stored_frequency = float(sample_info["stored_effective_frequency_hz"])
    bank_rate = int(sample_info["sample_rate"])
    vibrato = track.vibrato_cents * np.sin(2.0 * math.pi * track.vibrato_hz * time)
    step = (
        bank_rate
        / OUTPUT_SAMPLE_RATE
        * target_frequency
        / stored_frequency
        * np.power(2.0, vibrato / 1200.0)
    )
    positions = np.cumsum(step) - step[0]
    loop_start = int(sample_info["loop_start_sample"])
    loop_end = int(sample_info["loop_end_sample_exclusive"])
    loop_length = loop_end - loop_start
    mapped = np.where(
        positions < loop_start,
        positions,
        loop_start + np.mod(positions - loop_start, loop_length),
    )
    index0 = np.floor(mapped).astype(np.int64)
    fraction = mapped - index0
    index1 = index0 + 1
    wrapped = (index0 >= loop_start) & (index1 >= loop_end)
    index1[wrapped] = loop_start
    index1 = np.minimum(index1, len(sample_data) - 1)
    signal = sample_data[index0] * (1.0 - fraction) + sample_data[index1] * fraction

    release_start = max(1, int(round(note_seconds * OUTPUT_SAMPLE_RATE)))
    envelope = np.ones(total_samples, dtype=np.float64)
    if release_start < total_samples:
        release_progress = np.linspace(
            0.0, 1.0, total_samples - release_start, endpoint=True
        )
        envelope[release_start:] = np.cos(release_progress * math.pi / 2.0) ** 2
    extra_attack = min(total_samples, max(8, int(round(0.012 * OUTPUT_SAMPLE_RATE))))
    envelope[:extra_attack] *= np.sin(
        np.linspace(0.0, math.pi / 2.0, extra_attack, endpoint=True)
    ) ** 2
    velocity_gain = (note.velocity / 88.0) ** 1.45
    return signal * envelope * velocity_gain * track.render_gain


def moving_average(signal: np.ndarray, width: int = 9) -> np.ndarray:
    kernel = np.ones(width, dtype=np.float64) / width
    return np.convolve(signal, kernel, mode="same")


def restrained_circular_echo(mix: np.ndarray) -> tuple[np.ndarray, dict[str, object]]:
    dark = np.empty_like(mix, dtype=np.float64)
    dark[:, 0] = moving_average(mix[:, 0])
    dark[:, 1] = moving_average(mix[:, 1])
    wet = np.zeros_like(mix, dtype=np.float64)
    taps = ((0.096, 0.120), (0.192, 0.052), (0.288, 0.022))
    for delay_seconds, gain in taps:
        delay_samples = int(round(delay_seconds * OUTPUT_SAMPLE_RATE))
        delayed = np.roll(dark, delay_samples, axis=0)
        wet[:, 0] += delayed[:, 1] * gain
        wet[:, 1] += delayed[:, 0] * gain
    return mix + wet, {
        "model": "finite three-tap circular cross-stereo dark echo",
        "taps": [
            {"delay_ms": seconds * 1000.0, "gain": gain}
            for seconds, gain in taps
        ],
        "darkening_filter": "9-sample moving average before echo taps",
        "circular": True,
        "purpose": "restrained SNES-DSP-like room depth without a rhythmic repeat",
    }


def equal_power_loop_crossfade(
    audio: np.ndarray,
) -> tuple[np.ndarray, dict[str, object]]:
    overlap_samples = int(
        round(seconds_for_quarters(CROSSFADE_QUARTERS) * OUTPUT_SAMPLE_RATE)
    )
    if len(audio) <= overlap_samples * 2:
        raise RuntimeError("Audio is too short for the configured loop crossfade")
    angle = np.linspace(0.0, math.pi / 2.0, overlap_samples, endpoint=True)
    fade_out = np.cos(angle)[:, None]
    fade_in = np.sin(angle)[:, None]
    transition = audio[-overlap_samples:] * fade_out + audio[:overlap_samples] * fade_in
    # Rotate to begin immediately after the overlapped first measure. The final
    # transition then leads continuously back to that adjacent next sample.
    looped = np.concatenate(
        (audio[overlap_samples:-overlap_samples], transition), axis=0
    )
    first_last_delta = np.abs(looped[0] - looped[-1])
    typical_step = np.percentile(np.abs(np.diff(looped, axis=0)), 99.9, axis=0)
    return looped, {
        "crossfade_quarters": CROSSFADE_QUARTERS,
        "crossfade_seconds": seconds_for_quarters(CROSSFADE_QUARTERS),
        "crossfade_samples": overlap_samples,
        "render_start_rotation_quarters": CROSSFADE_QUARTERS,
        "rendered_duration_quarters": LOOP_QUARTERS - CROSSFADE_QUARTERS,
        "first_last_sample_delta": first_last_delta.tolist(),
        "p99_9_adjacent_sample_delta": typical_step.tolist(),
        "method": "one-measure equal-power tail-to-head overlap with loop-point rotation",
    }


def write_stereo_wave(path: Path, audio: np.ndarray) -> None:
    pcm = np.clip(np.round(audio * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(OUTPUT_SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def ffmpeg_vorbis_command(input_wave: Path) -> tuple[list[str], str]:
    encoders = subprocess.run(
        ["ffmpeg", "-hide_banner", "-encoders"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    if "libvorbis" in encoders:
        return (
            [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-i",
                str(input_wave),
                "-c:a",
                "libvorbis",
                "-q:a",
                "5",
                str(AUDIO_OGG),
            ],
            "FFmpeg libvorbis quality 5",
        )
    if " vorbis " in encoders:
        return (
            [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-i",
                str(input_wave),
                "-c:a",
                "vorbis",
                "-strict",
                "experimental",
                "-q:a",
                "5",
                str(AUDIO_OGG),
            ],
            "FFmpeg native Vorbis quality 5 (experimental encoder API)",
        )
    raise RuntimeError("FFmpeg has neither libvorbis nor its native Vorbis encoder")


def render_preview(bank: dict[str, object]) -> dict[str, object]:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("FFmpeg is required for Ogg Vorbis and FLAC previews")
    notes_by_track = read_midi_notes()
    bank_by_id = {
        str(sample["bank_id"]): sample for sample in bank["samples"]  # type: ignore[index]
    }
    sample_data = {
        bank_id: load_bank_wave(sample_info)
        for bank_id, sample_info in bank_by_id.items()
    }
    structural_samples = int(
        round(seconds_for_quarters(LOOP_QUARTERS) * OUTPUT_SAMPLE_RATE)
    )
    mix = np.zeros((structural_samples, 2), dtype=np.float64)

    for track in LOOP_TRACKS:
        sample_info = bank_by_id[track.bank_id]
        bank_wave = sample_data[track.bank_id]
        pan = track.pan / 127.0
        left_gain = math.cos(pan * math.pi / 2.0)
        right_gain = math.sin(pan * math.pi / 2.0)
        for note in notes_by_track[track.name]:
            voice = sampled_note(note, track, sample_info, bank_wave)
            start = int(round(note.start_seconds * OUTPUT_SAMPLE_RATE))
            end = min(structural_samples, start + len(voice))
            if end <= start:
                continue
            audible = voice[: end - start]
            mix[start:end, 0] += audible * left_gain
            mix[start:end, 1] += audible * right_gain

    # Linear pitch-shifting of low-rate console-style samples produces useful
    # grit but also ultrasonic imaging. A tiny reconstruction filter keeps the
    # audible result dark instead of brittle without erasing the sample loops.
    reconstructed = np.empty_like(mix, dtype=np.float64)
    reconstructed[:, 0] = moving_average(mix[:, 0], width=5)
    reconstructed[:, 1] = moving_average(mix[:, 1], width=5)
    echoed, echo_report = restrained_circular_echo(reconstructed)
    saturated = np.tanh(echoed * 1.08) / math.tanh(1.08)
    raw_peak = float(np.max(np.abs(saturated)))
    target_peak = 10.0 ** (-7.5 / 20.0)
    master_gain = target_peak / max(raw_peak, 1e-12)
    mastered = saturated * master_gain
    looped, crossfade_report = equal_power_loop_crossfade(mastered)
    looped = np.round(looped * 16383.0) / 16383.0
    peak = float(np.max(np.abs(looped)))
    rms = float(np.sqrt(np.mean(np.square(looped))))

    temporary = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    temporary_path = Path(temporary.name)
    temporary.close()
    try:
        write_stereo_wave(temporary_path, looped)
        subprocess.run(
            [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-i",
                str(temporary_path),
                "-c:a",
                "flac",
                "-compression_level",
                "8",
                str(AUDIO_FLAC),
            ],
            check=True,
        )
        vorbis_command, vorbis_label = ffmpeg_vorbis_command(temporary_path)
        subprocess.run(vorbis_command, check=True)
        base.normalize_ogg_serial(AUDIO_OGG, OGG_SERIAL)
    finally:
        temporary_path.unlink(missing_ok=True)

    return {
        "ogg_path": AUDIO_OGG.name,
        "ogg_sha256": sha256(AUDIO_OGG),
        "flac_path": AUDIO_FLAC.name,
        "flac_sha256": sha256(AUDIO_FLAC),
        "sample_rate": OUTPUT_SAMPLE_RATE,
        "channels": 2,
        "duration_seconds": len(looped) / OUTPUT_SAMPLE_RATE,
        "duration_quarters": LOOP_QUARTERS - CROSSFADE_QUARTERS,
        "peak_linear": peak,
        "peak_dbfs": 20.0 * math.log10(max(peak, 1e-12)),
        "rms_linear": rms,
        "master_gain": master_gain,
        "renderer": (
            "deterministic looped-sample playback from the generated procedural bank"
        ),
        "reconstruction_filter": (
            "5-sample moving average after pitch-shifted sample playback"
        ),
        "encoder": vorbis_label,
        "lossless_encoder": "FFmpeg FLAC compression level 8",
        "ogg_stream_serial": f"0x{OGG_SERIAL:08x}",
        "echo": echo_report,
        "loop_crossfade": crossfade_report,
    }


def section_report() -> list[dict[str, object]]:
    report: list[dict[str, object]] = []
    for section in FORM_SECTIONS:
        segment = SOURCE_SEGMENTS[section.segment_key]
        report.append(
            {
                **asdict(section),
                "source_start_ql": segment.source_start_ql,
                "source_end_ql": segment.source_end_ql,
                "source_preview_start_seconds": source_timestamp(
                    segment.source_start_ql
                ),
                "source_preview_end_seconds": source_timestamp(segment.source_end_ql),
                "performed_measure_start": segment.performed_measure_start,
                "performed_measure_end": segment.performed_measure_end,
                "requested_window": segment.requested_window,
            }
        )
    return report


def build(skip_audio: bool = False) -> dict[str, object]:
    events, transformation = build_track_events()
    midi_report = write_midi(events)
    bank_report = generate_bank()
    audio_report = None if skip_audio else render_preview(bank_report)
    report = {
        "version": 2,
        "source": {
            "path": str(base.SOURCE_MXL.relative_to(POC_ROOT)),
            "sha256": base.verify_immutable_source(),
            "license": "OpenScore String Quartets CC0; composition public domain",
        },
        "selection": {
            "form": "-".join(FORM),
            "sections": section_report(),
            "structural_duration_quarters": LOOP_QUARTERS,
            "structural_duration_seconds": seconds_for_quarters(LOOP_QUARTERS),
        },
        "transformation": {
            **transformation,
            "upper_voice_policy": (
                "Keep all notes longer than 0.75 quarters; deterministically omit "
                "one in five short Violin I events, one in three short first-pass "
                "Violin II events, and one in two short Violin II reprise events."
            ),
            "cello_policy": (
                "Keep every selected cello event, add 10 velocity units, lengthen "
                "gates by 8 percent subject to monophony, and derive a fifth voice "
                "exactly one octave below eligible cello pitches."
            ),
            "new_pitch_classes": False,
            "percussion": False,
        },
        "midi": midi_report,
        "procedural_bank": bank_report,
        "audio": audio_report,
        "tools": {
            "python": sys.version.split()[0],
            "numpy": np.__version__,
            "mido": getattr(mido, "__version__", "1.3.3"),
            "music21": base.music21.__version__,
        },
    }
    BUILD_REPORT.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--skip-audio", action="store_true", help="Build MIDI and sample bank only"
    )
    arguments = parser.parse_args()
    report = build(skip_audio=arguments.skip_audio)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
