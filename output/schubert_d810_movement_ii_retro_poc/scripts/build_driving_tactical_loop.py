#!/usr/bin/env python3
"""Build version 3: brighter upper strings plus restrained procedural percussion.

This additive build reads the immutable source and the version-2 string bank, but
writes only separately named version-3 artifacts.  No earlier audition file is
rebuilt or modified.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
from dataclasses import asdict, dataclass, replace
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

import build_active_tactical_loop as active
import build_arrangement as base


POC_ROOT = Path(__file__).resolve().parents[1]
ARRANGEMENT_MIDI = POC_ROOT / "driving_tactical_loop.mid"
AUDIO_OGG = POC_ROOT / "driving_tactical_loop_preview.ogg"
AUDIO_FLAC = POC_ROOT / "driving_tactical_loop_preview.flac"
BUILD_REPORT = POC_ROOT / "DRIVING_TACTICAL_LOOP_REPORT.json"
PERCUSSION_BANK_DIR = POC_ROOT / "procedural_percussion_bank"
PERCUSSION_MANIFEST = PERCUSSION_BANK_DIR / "bank_manifest.json"

TEMPO_QPM = active.TEMPO_QPM
TICKS_PER_BEAT = active.TICKS_PER_BEAT
OUTPUT_SAMPLE_RATE = active.OUTPUT_SAMPLE_RATE
PERCUSSION_SAMPLE_RATE = 16_000
LOOP_QUARTERS = active.LOOP_QUARTERS
CROSSFADE_QUARTERS = active.CROSSFADE_QUARTERS
OGG_SERIAL = 0x53383330  # ASCII "S830": Schubert/version 3/loop 0.


# The cello, bass, viola, gates, timbres, panning, and vibrato are exactly the
# version-2 settings.  Only the two upper render gains and MIDI velocities move.
TRACKS = (
    replace(active.LOOP_TRACKS[0], render_gain=0.52, volume=86),
    replace(active.LOOP_TRACKS[1], render_gain=0.43, volume=78),
    active.LOOP_TRACKS[2],
    active.LOOP_TRACKS[3],
    active.LOOP_TRACKS[4],
)
STRING_VELOCITY_LIFT = {
    TRACKS[0].name: 3,
    TRACKS[1].name: 4,
    TRACKS[2].name: 0,
    TRACKS[3].name: 0,
    TRACKS[4].name: 0,
}


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


PERCUSSION_SPECS = (
    PercussionSpec(
        "umbra_war_drum",
        "umbra_war_drum.wav",
        36,
        "Low war drum",
        0.72,
        0.25,
        61,
        10,
        "exponentially swept sinusoidal membrane plus deterministic transient",
    ),
    PercussionSpec(
        "bone_tom",
        "bone_tom.wav",
        41,
        "Muted bone tom",
        0.38,
        0.17,
        70,
        10,
        "short swept sinusoidal membrane with an inharmonic upper partial",
    ),
    PercussionSpec(
        "ash_tick",
        "ash_tick.wav",
        42,
        "Ash tick",
        0.085,
        0.065,
        76,
        8,
        "high-passed deterministic integer-noise burst with a quiet metallic partial",
    ),
)
PERCUSSION_TRACK_NAME = "Funeral Pulse / Procedural Percussion"


@dataclass(frozen=True)
class PercussionEvent:
    start_ql: float
    duration_ql: float
    pitch: int
    velocity: int
    bank_id: str
    section_label: str
    role: str

    @property
    def end_ql(self) -> float:
        return self.start_ql + self.duration_ql


@dataclass(frozen=True)
class RenderNote:
    start_seconds: float
    end_seconds: float
    pitch: int
    velocity: int


def ticks(quarters: float) -> int:
    return active.ticks(quarters)


def seconds_for_quarters(quarters: float) -> float:
    return active.seconds_for_quarters(quarters)


def adjusted_string_events() -> tuple[
    dict[str, list[active.ArrangedEvent]], dict[str, object]
]:
    version_two, transformation = active.build_track_events()
    adjusted: dict[str, list[active.ArrangedEvent]] = {}
    for spec in TRACKS:
        lift = STRING_VELOCITY_LIFT[spec.name]
        adjusted[spec.name] = [
            replace(event, velocity=max(1, min(127, event.velocity + lift)))
            for event in version_two[spec.name]
        ]
    return adjusted, transformation


def percussion_events() -> list[PercussionEvent]:
    """Write a section-aware pulse: sparse in A, fuller in B/C, never frantic."""
    events: list[PercussionEvent] = []
    for section in active.FORM_SECTIONS:
        bar_count = int(round((section.destination_end_ql - section.destination_start_ql) / 4.0))
        for bar_index in range(bar_count):
            bar = section.destination_start_ql + bar_index * 4.0
            opening_accent = 5 if bar_index == 0 else 0
            events.extend(
                [
                    PercussionEvent(bar, 0.34, 36, 72 + opening_accent, "umbra_war_drum", section.label, "downbeat"),
                    PercussionEvent(bar + 2.0, 0.32, 36, 62, "umbra_war_drum", section.label, "midbar drive"),
                ]
            )
            if section.segment_key == "A":
                events.append(
                    PercussionEvent(bar + 3.0, 0.18, 41, 43, "bone_tom", section.label, "restrained backbeat")
                )
                tick_offsets = (1.5, 3.5)
                tick_velocity = 24
            else:
                events.extend(
                    [
                        PercussionEvent(bar + 1.0, 0.18, 41, 43, "bone_tom", section.label, "backbeat"),
                        PercussionEvent(bar + 3.0, 0.18, 41, 48 if section.segment_key == "C" else 45, "bone_tom", section.label, "backbeat"),
                    ]
                )
                tick_offsets = (0.5, 1.5, 2.5, 3.5)
                tick_velocity = 27 if section.segment_key == "C" else 25
            for offset in tick_offsets:
                events.append(
                    PercussionEvent(bar + offset, 0.08, 42, tick_velocity, "ash_tick", section.label, "offbeat motion")
                )
    return sorted(events, key=lambda event: (event.start_ql, event.pitch))


def conductor_track() -> mido.MidiTrack:
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name="Conductor / Loop Map", time=0))
    track.append(
        mido.MetaMessage(
            "copyright",
            text=(
                "Franz Schubert composition: public domain. OpenScore source: CC0. "
                "Procedural string/percussion banks and arrangement created for Escape the Umbra."
            ),
            time=0,
        )
    )
    track.append(mido.MetaMessage("text", text="OpenScore source SHA-256: " + base.EXPECTED_SOURCE_SHA256, time=0))
    track.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
    track.append(mido.MetaMessage("key_signature", key="Gm", time=0))
    track.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(TEMPO_QPM), time=0))
    markers: list[tuple[int, str]] = [(0, "LOOP_START / structural MIDI")]
    for section in active.FORM_SECTIONS:
        segment = active.SOURCE_SEGMENTS[section.segment_key]
        markers.append(
            (
                ticks(section.destination_start_ql),
                f"{section.label}: source performed measures {segment.performed_measure_start}-{segment.performed_measure_end}",
            )
        )
    markers.append((ticks(LOOP_QUARTERS), "LOOP_END / rendered audio uses a one-measure equal-power crossfade and rotation"))
    previous = 0
    for absolute, label in markers:
        track.append(mido.MetaMessage("marker", text=label, time=absolute - previous))
        previous = absolute
    track.append(mido.MetaMessage("end_of_track", time=0))
    return track


def percussion_midi_track(events: list[PercussionEvent]) -> mido.MidiTrack:
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name=PERCUSSION_TRACK_NAME, time=0))
    track.append(
        mido.MetaMessage(
            "instrument_name",
            name="Original procedural one-shots; GM percussion notes are fallback mapping only",
            time=0,
        )
    )
    track.append(mido.Message("control_change", channel=9, control=7, value=93, time=0))
    track.append(mido.Message("control_change", channel=9, control=10, value=64, time=0))
    timed: list[tuple[int, int, mido.Message]] = []
    for event in events:
        start = ticks(event.start_ql)
        end = max(start + 1, ticks(event.end_ql))
        timed.append((start, 1, mido.Message("note_on", channel=9, note=event.pitch, velocity=event.velocity, time=0)))
        timed.append((end, 0, mido.Message("note_off", channel=9, note=event.pitch, velocity=0, time=0)))
    timed.sort(key=lambda item: (item[0], item[1], item[2].note))
    previous = 0
    for absolute, _, message in timed:
        track.append(message.copy(time=absolute - previous))
        previous = absolute
    track.append(mido.MetaMessage("end_of_track", time=max(0, ticks(LOOP_QUARTERS) - previous)))
    return track


def write_midi(
    strings: dict[str, list[active.ArrangedEvent]],
    percussion: list[PercussionEvent],
) -> dict[str, object]:
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    midi.tracks.append(conductor_track())
    for spec in TRACKS:
        midi.tracks.append(active.midi_note_track(spec, strings[spec.name]))
    midi.tracks.append(percussion_midi_track(percussion))
    midi.save(ARRANGEMENT_MIDI)
    return {
        "path": ARRANGEMENT_MIDI.name,
        "sha256": active.sha256(ARRANGEMENT_MIDI),
        "tempo_qpm": TEMPO_QPM,
        "ticks_per_beat": TICKS_PER_BEAT,
        "structural_duration_quarters": LOOP_QUARTERS,
        "structural_duration_seconds": seconds_for_quarters(LOOP_QUARTERS),
        "string_note_counts": {name: len(events) for name, events in strings.items()},
        "percussion_note_count": len(percussion),
        "track_count_including_conductor": len(midi.tracks),
    }


def deterministic_noise(length: int, seed: int) -> np.ndarray:
    state = seed & 0xFFFFFFFF
    output = np.empty(length, dtype=np.float64)
    for index in range(length):
        state = (1_664_525 * state + 1_013_904_223) & 0xFFFFFFFF
        output[index] = ((state >> 8) / float(1 << 24)) * 2.0 - 1.0
    return output


def tail_taper(signal: np.ndarray, milliseconds: float = 12.0) -> np.ndarray:
    count = min(len(signal), max(8, int(round(milliseconds * PERCUSSION_SAMPLE_RATE / 1000.0))))
    signal[-count:] *= np.cos(np.linspace(0.0, math.pi / 2.0, count)) ** 2
    return signal


def synthesize_percussion(spec: PercussionSpec) -> np.ndarray:
    count = int(round(spec.duration_seconds * PERCUSSION_SAMPLE_RATE))
    time = np.arange(count, dtype=np.float64) / PERCUSSION_SAMPLE_RATE
    progress = time / spec.duration_seconds
    if spec.bank_id == "umbra_war_drum":
        frequency = 47.0 + 66.0 * np.exp(-8.0 * progress)
        phase = np.cumsum(2.0 * math.pi * frequency / PERCUSSION_SAMPLE_RATE)
        membrane = np.sin(phase) + 0.24 * np.sin(2.03 * phase + 0.4)
        transient = deterministic_noise(count, 0x810036) * np.exp(-95.0 * time)
        envelope = (1.0 - np.exp(-time / 0.0035)) * np.exp(-4.8 * progress)
        signal = membrane * envelope + 0.11 * transient
    elif spec.bank_id == "bone_tom":
        frequency = 82.0 + 62.0 * np.exp(-10.0 * progress)
        phase = np.cumsum(2.0 * math.pi * frequency / PERCUSSION_SAMPLE_RATE)
        membrane = np.sin(phase) + 0.18 * np.sin(2.71 * phase + 0.8)
        envelope = (1.0 - np.exp(-time / 0.0025)) * np.exp(-6.3 * progress)
        signal = membrane * envelope
    else:
        noise = deterministic_noise(count + 1, 0xA55042)
        high_passed = np.diff(noise)
        metallic = np.sin(2.0 * math.pi * 1760.0 * time + 0.3)
        envelope = np.exp(-11.0 * progress)
        signal = (0.78 * high_passed + 0.22 * metallic) * envelope
    signal = tail_taper(signal)
    signal /= max(1e-12, float(np.max(np.abs(signal))))
    signal *= 0.80
    quantization_max = float((1 << (spec.signal_quantization_bits - 1)) - 1)
    return np.round(signal * quantization_max) / quantization_max


def generate_percussion_bank() -> dict[str, object]:
    PERCUSSION_BANK_DIR.mkdir(parents=True, exist_ok=True)
    samples: list[dict[str, object]] = []
    for spec in PERCUSSION_SPECS:
        path = PERCUSSION_BANK_DIR / spec.filename
        signal = synthesize_percussion(spec)
        active.write_mono_wave(path, signal, PERCUSSION_SAMPLE_RATE)
        samples.append(
            {
                **asdict(spec),
                "path": str(path.relative_to(POC_ROOT)),
                "sha256": active.sha256(path),
                "sample_rate": PERCUSSION_SAMPLE_RATE,
                "channels": 1,
                "sample_width_bits": 16,
                "frames": len(signal),
                "generator": "deterministic local mathematical synthesis",
            }
        )
    manifest = {
        "name": "Escape the Umbra Procedural Funeral Pulse v1",
        "provenance": (
            "Generated locally from mathematical oscillators, fixed integer-noise seeds, "
            "and deterministic envelopes. No recording, sample pack, SoundFont, ROM, "
            "model output, or third-party audio was used."
        ),
        "commercial_use_status": (
            "Original project-generated assets with no third-party audio rights input; "
            "intended for unrestricted use in Escape the Umbra and its distributed builds."
        ),
        "sample_rate": PERCUSSION_SAMPLE_RATE,
        "samples": samples,
    }
    PERCUSSION_MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    manifest["manifest_path"] = str(PERCUSSION_MANIFEST.relative_to(POC_ROOT))
    manifest["manifest_sha256"] = active.sha256(PERCUSSION_MANIFEST)
    return manifest


def midi_track_name(track: mido.MidiTrack) -> str:
    return active.midi_track_name(track)


def read_midi_notes() -> dict[str, list[RenderNote]]:
    midi = mido.MidiFile(ARRANGEMENT_MIDI)
    seconds_per_tick = 60.0 / (TEMPO_QPM * midi.ticks_per_beat)
    known = {spec.name for spec in TRACKS} | {PERCUSSION_TRACK_NAME}
    output: dict[str, list[RenderNote]] = {}
    for track in midi.tracks:
        name = midi_track_name(track)
        if name not in known:
            continue
        active_notes: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
        absolute = 0
        notes: list[RenderNote] = []
        for message in track:
            absolute += message.time
            if message.type == "note_on" and message.velocity > 0:
                active_notes[(message.channel, message.note)].append((absolute, message.velocity))
            elif message.type == "note_off" or (message.type == "note_on" and message.velocity == 0):
                key = (message.channel, message.note)
                if not active_notes[key]:
                    raise RuntimeError(f"Unmatched note-off in {name}: {message.note}")
                start, velocity = active_notes[key].pop(0)
                notes.append(RenderNote(start * seconds_per_tick, absolute * seconds_per_tick, message.note, velocity))
        if any(active_notes.values()):
            raise RuntimeError(f"Hanging MIDI notes in {name}")
        output[name] = sorted(notes, key=lambda note: (note.start_seconds, note.pitch))
    return output


def load_mono_wave(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as handle:
        if handle.getnchannels() != 1 or handle.getsampwidth() != 2:
            raise RuntimeError(f"Unexpected WAV format: {path}")
        frames = handle.readframes(handle.getnframes())
    return np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32768.0


def resample_one_shot(signal: np.ndarray, source_rate: int) -> np.ndarray:
    count = max(1, int(round(len(signal) * OUTPUT_SAMPLE_RATE / source_rate)))
    source_positions = np.linspace(0.0, len(signal) - 1, count, endpoint=True)
    return np.interp(source_positions, np.arange(len(signal)), signal)


def stereo_rms(audio: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(audio))))


def add_panned(destination: np.ndarray, start: int, voice: np.ndarray, pan: int) -> None:
    end = min(len(destination), start + len(voice))
    if end <= start:
        return
    audible = voice[: end - start]
    normalized_pan = pan / 127.0
    destination[start:end, 0] += audible * math.cos(normalized_pan * math.pi / 2.0)
    destination[start:end, 1] += audible * math.sin(normalized_pan * math.pi / 2.0)


def ffmpeg_vorbis_command(input_wave: Path) -> tuple[list[str], str]:
    encoders = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], check=True, capture_output=True, text=True).stdout
    if "libvorbis" in encoders:
        encoder = ["-c:a", "libvorbis", "-q:a", "5"]
        label = "FFmpeg libvorbis quality 5"
    elif " vorbis " in encoders:
        encoder = ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "5"]
        label = "FFmpeg native Vorbis quality 5 (experimental encoder API)"
    else:
        raise RuntimeError("FFmpeg has neither libvorbis nor its native Vorbis encoder")
    return ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(input_wave), *encoder, str(AUDIO_OGG)], label


def render_preview(percussion_bank: dict[str, object]) -> dict[str, object]:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("FFmpeg is required for Ogg Vorbis and FLAC previews")
    string_manifest = json.loads(active.BANK_MANIFEST.read_text(encoding="utf-8"))
    for sample in string_manifest["samples"]:
        path = POC_ROOT / sample["path"]
        if active.sha256(path) != sample["sha256"]:
            raise RuntimeError(f"Version-2 string-bank sample drifted: {path}")
    string_bank = {sample["bank_id"]: sample for sample in string_manifest["samples"]}
    string_waves = {bank_id: active.load_bank_wave(info) for bank_id, info in string_bank.items()}
    percussion_by_pitch = {int(sample["midi_note"]): sample for sample in percussion_bank["samples"]}
    percussion_waves = {
        pitch: resample_one_shot(load_mono_wave(POC_ROOT / info["path"]), int(info["sample_rate"]))
        for pitch, info in percussion_by_pitch.items()
    }
    notes = read_midi_notes()
    structural_samples = int(round(seconds_for_quarters(LOOP_QUARTERS) * OUTPUT_SAMPLE_RATE))
    string_mix = np.zeros((structural_samples, 2), dtype=np.float64)
    upper_stem = np.zeros_like(string_mix)
    low_stem = np.zeros_like(string_mix)
    percussion_mix = np.zeros_like(string_mix)

    for index, track in enumerate(TRACKS):
        sample_info = string_bank[track.bank_id]
        bank_wave = string_waves[track.bank_id]
        for note in notes[track.name]:
            active_note = active.RenderNote(note.start_seconds, note.end_seconds, note.pitch, note.velocity)
            voice = active.sampled_note(active_note, track, sample_info, bank_wave)
            start = int(round(note.start_seconds * OUTPUT_SAMPLE_RATE))
            add_panned(string_mix, start, voice, track.pan)
            if index < 2:
                add_panned(upper_stem, start, voice, track.pan)
            elif index >= 3:
                add_panned(low_stem, start, voice, track.pan)

    for note in notes[PERCUSSION_TRACK_NAME]:
        info = percussion_by_pitch[note.pitch]
        velocity_gain = (note.velocity / 88.0) ** 1.25
        voice = percussion_waves[note.pitch] * float(info["render_gain"]) * velocity_gain
        start = int(round(note.start_seconds * OUTPUT_SAMPLE_RATE))
        add_panned(percussion_mix, start, voice, int(info["pan"]))

    reconstructed = np.empty_like(string_mix)
    reconstructed[:, 0] = active.moving_average(string_mix[:, 0], width=5)
    reconstructed[:, 1] = active.moving_average(string_mix[:, 1], width=5)
    echoed_strings, echo_report = active.restrained_circular_echo(reconstructed)
    # Keep the pulse drier and more immediate than the strings.  A three-sample
    # reconstruction filter tempers the deliberately low-rate/noisy one-shots.
    dry_drums = np.empty_like(percussion_mix)
    dry_drums[:, 0] = active.moving_average(percussion_mix[:, 0], width=3)
    dry_drums[:, 1] = active.moving_average(percussion_mix[:, 1], width=3)
    combined = echoed_strings + dry_drums
    saturated = np.tanh(combined * 1.08) / math.tanh(1.08)
    raw_peak = float(np.max(np.abs(saturated)))
    target_peak = 10.0 ** (-7.5 / 20.0)
    master_gain = target_peak / max(raw_peak, 1e-12)
    mastered = saturated * master_gain
    looped, crossfade_report = active.equal_power_loop_crossfade(mastered)
    looped = np.round(looped * 16383.0) / 16383.0
    peak = float(np.max(np.abs(looped)))
    rms = stereo_rms(looped)

    temporary = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    temporary_path = Path(temporary.name)
    temporary.close()
    try:
        active.write_stereo_wave(temporary_path, looped)
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(temporary_path), "-c:a", "flac", "-compression_level", "8", str(AUDIO_FLAC)],
            check=True,
        )
        vorbis_command, vorbis_label = ffmpeg_vorbis_command(temporary_path)
        subprocess.run(vorbis_command, check=True)
        base.normalize_ogg_serial(AUDIO_OGG, OGG_SERIAL)
    finally:
        temporary_path.unlink(missing_ok=True)

    return {
        "ogg_path": AUDIO_OGG.name,
        "ogg_sha256": active.sha256(AUDIO_OGG),
        "flac_path": AUDIO_FLAC.name,
        "flac_sha256": active.sha256(AUDIO_FLAC),
        "sample_rate": OUTPUT_SAMPLE_RATE,
        "channels": 2,
        "duration_seconds": len(looped) / OUTPUT_SAMPLE_RATE,
        "duration_quarters": LOOP_QUARTERS - CROSSFADE_QUARTERS,
        "peak_linear": peak,
        "peak_dbfs": 20.0 * math.log10(max(peak, 1e-12)),
        "rms_linear": rms,
        "master_gain": master_gain,
        "pre_master_stem_rms": {
            "upper_strings_violin_i_ii": stereo_rms(upper_stem),
            "low_strings_cello_and_bass": stereo_rms(low_stem),
            "percussion": stereo_rms(percussion_mix),
        },
        "renderer": "deterministic looped procedural strings plus deterministic procedural percussion one-shots",
        "string_reconstruction_filter": "5-sample moving average after pitch-shifted sample playback",
        "percussion_reconstruction_filter": "3-sample moving average; percussion otherwise dry",
        "encoder": vorbis_label,
        "lossless_encoder": "FFmpeg FLAC compression level 8",
        "ogg_stream_serial": f"0x{OGG_SERIAL:08x}",
        "echo": echo_report,
        "loop_crossfade": crossfade_report,
    }


def percussion_pattern_report(events: list[PercussionEvent]) -> dict[str, object]:
    by_bank: dict[str, int] = defaultdict(int)
    by_section: dict[str, int] = defaultdict(int)
    for event in events:
        by_bank[event.bank_id] += 1
        by_section[event.section_label] += 1
    return {
        "description": "Low drum on beats 1/3; muted tom backbeats; quiet offbeat ash ticks with sparser A sections.",
        "channel_zero_based": 9,
        "channel_human_number": 10,
        "counts_by_bank_id": dict(sorted(by_bank.items())),
        "counts_by_section": dict(sorted(by_section.items())),
        "total_events": len(events),
    }


def build(skip_audio: bool = False) -> dict[str, object]:
    strings, transformation = adjusted_string_events()
    drums = percussion_events()
    midi_report = write_midi(strings, drums)
    percussion_bank = generate_percussion_bank()
    audio_report = None if skip_audio else render_preview(percussion_bank)
    gain_changes = {
        TRACKS[0].name: {
            "version_2_render_gain": active.LOOP_TRACKS[0].render_gain,
            "version_3_render_gain": TRACKS[0].render_gain,
            "render_gain_change_db": 20.0 * math.log10(TRACKS[0].render_gain / active.LOOP_TRACKS[0].render_gain),
            "midi_velocity_lift": STRING_VELOCITY_LIFT[TRACKS[0].name],
        },
        TRACKS[1].name: {
            "version_2_render_gain": active.LOOP_TRACKS[1].render_gain,
            "version_3_render_gain": TRACKS[1].render_gain,
            "render_gain_change_db": 20.0 * math.log10(TRACKS[1].render_gain / active.LOOP_TRACKS[1].render_gain),
            "midi_velocity_lift": STRING_VELOCITY_LIFT[TRACKS[1].name],
        },
    }
    report = {
        "version": 3,
        "source": {
            "path": str(base.SOURCE_MXL.relative_to(POC_ROOT)),
            "sha256": base.verify_immutable_source(),
            "license": "OpenScore String Quartets CC0; composition public domain",
        },
        "selection": {
            "form": "-".join(active.FORM),
            "sections": active.section_report(),
            "structural_duration_quarters": LOOP_QUARTERS,
            "structural_duration_seconds": seconds_for_quarters(LOOP_QUARTERS),
        },
        "transformation": {
            **transformation,
            "version_two_string_content_retained": True,
            "upper_voice_balance_changes": gain_changes,
            "cello_and_bass_settings_changed_from_version_two": False,
            "percussion": percussion_pattern_report(drums),
            "new_schubert_pitch_classes": False,
        },
        "midi": midi_report,
        "procedural_string_bank": {
            "path": str(active.BANK_MANIFEST.relative_to(POC_ROOT)),
            "sha256": active.sha256(active.BANK_MANIFEST),
            "status": "reused unchanged from version 2",
        },
        "procedural_percussion_bank": percussion_bank,
        "audio": audio_report,
        "tools": {
            "python": sys.version.split()[0],
            "numpy": np.__version__,
            "mido": getattr(mido, "__version__", "1.3.3"),
            "music21": base.music21.__version__,
        },
    }
    BUILD_REPORT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-audio", action="store_true", help="Build MIDI and percussion bank only")
    arguments = parser.parse_args()
    print(json.dumps(build(skip_audio=arguments.skip_audio), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
