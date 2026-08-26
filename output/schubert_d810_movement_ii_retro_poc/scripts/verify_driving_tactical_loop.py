#!/usr/bin/env python3
"""Verify version-3 provenance, balance changes, MIDI, bank, and audio."""

from __future__ import annotations

from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import sys
import wave

if sys.version_info < (3, 12):
    raise SystemExit(
        "This verification requires Python 3.12 or newer; "
        f"found {sys.version.split()[0]}"
    )

import mido
import numpy as np

import build_active_tactical_loop as version_two
import build_arrangement as base
import build_driving_tactical_loop as driving
import verify_active_tactical_loop as verify_two


POC_ROOT = Path(__file__).resolve().parents[1]
VERIFICATION_REPORT = POC_ROOT / "DRIVING_TACTICAL_LOOP_VERIFICATION.json"

# These constants lock the earlier audition choices.  Version 3 is additive.
PRIOR_VERSION_HASHES = {
    "faithful_retro.mid": "2c9a7303ef50cb244bb94b95cc367d730590ab15e4ce77ffa806e8b70269fd66",
    "faithful_retro_preview.ogg": "93ff01b2b6ef31e52965fdbf240c7b64a692871301370c517a7cafcda7a65a0f",
    "faithful_retro_preview.flac": "ecd02002cff366f1152febe588713a5dd870a840bed44a1c5b7c7bb0f04c6409",
    "normalized/movement_ii_four_parts.musicxml": "03eae6073fab5f208829746631b87740b041383c893529349875f346900ba5a6",
    "normalized/movement_ii_four_parts.mid": "874d96d94e256126c0a569516c6f678d29b8638d5bf8f5fe27147d177fa509cf",
    "active_tactical_loop.mid": "9a69b30ab27ff24c10fcd54d81f4d5485f1c6a27fca77fb732e41f32bfff76b8",
    "active_tactical_loop_preview.ogg": "41116fd9726d8d50ca85326420233b7838947230d678f38d76eb92c80d62dbb4",
    "active_tactical_loop_preview.flac": "0219033378a4aaa074ed70e899089ebe0a5294d95afcac9d69dafe67656e6051",
    "ACTIVE_TACTICAL_LOOP_REPORT.json": "7b13c4a6e02e33db0b6deaecf3610f8aa4d1fc0d8326285c346b8e6b1891dac5",
    "ACTIVE_TACTICAL_LOOP_VERIFICATION.json": "de6b2c6d0799c32cbc7c41e7f272e24feff0b8cc32d085d9ef6251849dc022f3",
    "ACTIVE_TACTICAL_LOOP_NOTES.md": "478dbf5b27ebac76a2177f2d86d0ab48a01b106480900e5d5b123a30e899eaa6",
    "PROCEDURAL_BANK_PROVENANCE.md": "c1f051125dee68d07f7baf1961253328a2e5409244cfbb62451c11214e6f143b",
    "procedural_bank/bank_manifest.json": "6e47f373b7c7f91dbe97f356f95b48497415aa7e31f7bbc15d0491b07dce5ac5",
    "procedural_bank/ashen_violin_d4.wav": "61582413be61cd25d182bdb1645c83af6b663070d9be9730525a02bc1ec890a0",
    "procedural_bank/grave_cello_c2.wav": "17eb59965eabbe0a910585f100296ce56cd868884d440139a3b5c7b13df40f09",
    "procedural_bank/hollow_viola_c3.wav": "9cac0ff97b72b9822e4774fdd4d270b8f4b719f5662e27035519715b07f70c74",
    "procedural_bank/undercrypt_bass_e1.wav": "2b1a1a07e74969533c0ef2766602633fcb6180a12ae6fa3dddc6dbdb1264679e",
    "procedural_bank/veiled_violin_a4.wav": "c683d2911eba6adb35e58027b1dd363f5057996a789f06f8a4aa604d9092ffc8",
}


def verify_prior_versions_unchanged() -> dict[str, str]:
    actual: dict[str, str] = {}
    for relative, expected in PRIOR_VERSION_HASHES.items():
        digest = version_two.sha256(POC_ROOT / relative)
        assert digest == expected, f"Prior artifact changed: {relative}"
        actual[relative] = digest
    return actual


def expected_string_signatures(
    events: list[version_two.ArrangedEvent],
) -> list[tuple[int, int, int, int]]:
    return sorted(
        (
            driving.ticks(event.start_ql),
            max(driving.ticks(event.start_ql) + 1, driving.ticks(event.end_ql)),
            event.pitch,
            event.velocity,
        )
        for event in events
    )


def expected_percussion_signatures(
    events: list[driving.PercussionEvent],
) -> list[tuple[int, int, int, int]]:
    return sorted(
        (
            driving.ticks(event.start_ql),
            max(driving.ticks(event.start_ql) + 1, driving.ticks(event.end_ql)),
            event.pitch,
            event.velocity,
        )
        for event in events
    )


def verify_balance_and_retention(
    strings: dict[str, list[version_two.ArrangedEvent]],
) -> dict[str, object]:
    prior, _ = version_two.build_track_events()
    per_track: dict[str, object] = {}
    for index, spec in enumerate(driving.TRACKS):
        before = prior[spec.name]
        after = strings[spec.name]
        assert len(before) == len(after)
        lift = driving.STRING_VELOCITY_LIFT[spec.name]
        amplitude_ratios: list[float] = []
        for old, new in zip(before, after, strict=True):
            assert (
                new.start_ql,
                new.duration_ql,
                new.pitch,
                new.source_start_ql,
                new.source_end_ql,
                new.source_pitch,
                new.source_track,
                new.section_label,
            ) == (
                old.start_ql,
                old.duration_ql,
                old.pitch,
                old.source_start_ql,
                old.source_end_ql,
                old.source_pitch,
                old.source_track,
                old.section_label,
            )
            assert new.velocity == min(127, old.velocity + lift)
            old_gain = version_two.LOOP_TRACKS[index].render_gain
            amplitude_ratios.append(
                (spec.render_gain / old_gain)
                * ((new.velocity / old.velocity) ** 1.45)
            )
        if index < 2:
            assert min(amplitude_ratios) > 1.0
        else:
            assert min(amplitude_ratios) == 1.0
            assert spec == version_two.LOOP_TRACKS[index]
        per_track[spec.name] = {
            "event_count": len(after),
            "velocity_lift": lift,
            "minimum_per_note_amplitude_ratio_vs_version_2": min(amplitude_ratios),
            "maximum_per_note_amplitude_ratio_vs_version_2": max(amplitude_ratios),
            "all_timing_pitch_and_source_fields_identical_to_version_2": True,
        }
    return {
        "tracks": per_track,
        "all_3212_string_events_retained": sum(len(events) for events in strings.values()) == 3212,
        "cello_bass_viola_specs_identical_to_version_2": True,
    }


def verify_midi() -> dict[str, object]:
    midi = mido.MidiFile(driving.ARRANGEMENT_MIDI)
    assert midi.type == 1
    assert midi.ticks_per_beat == driving.TICKS_PER_BEAT
    expected_names = [
        "Conductor / Loop Map",
        *[spec.name for spec in driving.TRACKS],
        driving.PERCUSSION_TRACK_NAME,
    ]
    names = [driving.midi_track_name(track) for track in midi.tracks]
    assert names == expected_names
    assert len(set(names)) == len(names)
    by_name = dict(zip(names, midi.tracks, strict=True))
    strings, transformation = driving.adjusted_string_events()
    percussion = driving.percussion_events()

    actual_by_track: dict[str, list[tuple[int, int, int, int]]] = {}
    for index, spec in enumerate(driving.TRACKS):
        track = by_name[spec.name]
        signatures = verify_two.midi_note_signatures(track)
        assert signatures == expected_string_signatures(strings[spec.name])
        assert verify_two.absolute_track_end(track) == driving.ticks(driving.LOOP_QUARTERS)
        assert {message.channel for message in track if message.type == "note_on" and message.velocity > 0} == {index}
        active_end = -1
        for start, end, _, _ in signatures:
            assert start >= active_end, f"Unexpected polyphony in {spec.name}"
            active_end = end
        actual_by_track[spec.name] = signatures

    percussion_track = by_name[driving.PERCUSSION_TRACK_NAME]
    percussion_signatures = verify_two.midi_note_signatures(percussion_track)
    assert percussion_signatures == expected_percussion_signatures(percussion)
    assert {signature[2] for signature in percussion_signatures} == {36, 41, 42}
    assert {
        message.channel
        for message in percussion_track
        if message.type == "note_on" and message.velocity > 0
    } == {9}
    assert verify_two.absolute_track_end(percussion_track) == driving.ticks(driving.LOOP_QUARTERS)
    percussion_active_end = -1
    for start, end, _, _ in percussion_signatures:
        assert start >= percussion_active_end
        percussion_active_end = end
    actual_by_track[driving.PERCUSSION_TRACK_NAME] = percussion_signatures

    conductor = by_name["Conductor / Loop Map"]
    assert not [message for message in conductor if message.type == "note_on"]
    markers = [message.text for message in conductor if message.type == "marker"]
    assert markers[0].startswith("LOOP_START")
    assert markers[-1].startswith("LOOP_END")
    for section in version_two.FORM_SECTIONS:
        assert any(marker.startswith(section.label + ":") for marker in markers)
    assert verify_two.absolute_track_end(conductor) == driving.ticks(driving.LOOP_QUARTERS)

    melodic_polyphony = verify_two.max_global_polyphony(
        {name: signatures for name, signatures in actual_by_track.items() if name != driving.PERCUSSION_TRACK_NAME}
    )
    total_polyphony = verify_two.max_global_polyphony(actual_by_track)
    assert melodic_polyphony == 5
    assert total_polyphony == 6
    source_mapping = verify_two.verify_source_mapping(strings)
    return {
        "sha256": version_two.sha256(driving.ARRANGEMENT_MIDI),
        "track_names": names,
        "total_tracks": len(midi.tracks),
        "string_note_channels_zero_based": [0, 1, 2, 3, 4],
        "percussion_note_channel_zero_based": 9,
        "percussion_note_channel_human_number": 10,
        "string_note_counts": {spec.name: len(actual_by_track[spec.name]) for spec in driving.TRACKS},
        "percussion_note_count": len(percussion_signatures),
        "percussion_note_numbers": sorted({signature[2] for signature in percussion_signatures}),
        "maximum_simultaneous_melodic_voices": melodic_polyphony,
        "maximum_simultaneous_voices_including_percussion": total_polyphony,
        "duration_quarters": driving.LOOP_QUARTERS,
        "duration_seconds": driving.seconds_for_quarters(driving.LOOP_QUARTERS),
        "form": "-".join(version_two.FORM),
        "markers": markers,
        "source_mapping": source_mapping,
        "thinning": transformation["thinning"],
        "balance_and_retention": verify_balance_and_retention(strings),
    }


def verify_percussion_pattern() -> dict[str, object]:
    events = driving.percussion_events()
    by_section: dict[str, list[driving.PercussionEvent]] = defaultdict(list)
    by_bank: dict[str, int] = defaultdict(int)
    for event in events:
        by_section[event.section_label].append(event)
        by_bank[event.bank_id] += 1
    assert dict(sorted(by_bank.items())) == {
        "ash_tick": 352,
        "bone_tom": 176,
        "umbra_war_drum": 208,
    }
    assert {label: len(items) for label, items in sorted(by_section.items())} == {
        "A1": 80,
        "A2": 80,
        "B1": 192,
        "B2": 192,
        "C1": 192,
    }
    assert all(event.start_ql < driving.LOOP_QUARTERS for event in events)
    return {
        "total_events": len(events),
        "counts_by_bank_id": dict(sorted(by_bank.items())),
        "counts_by_section": {label: len(items) for label, items in sorted(by_section.items())},
        "A_sections_are_sparser_than_B_and_C_per_measure": True,
        "low_drum_beats": [1, 3],
        "new_compositional_pitch_content": False,
    }


def verify_percussion_bank() -> dict[str, object]:
    report = json.loads(driving.BUILD_REPORT.read_text(encoding="utf-8"))
    bank_report = report["procedural_percussion_bank"]
    manifest_bytes = driving.PERCUSSION_MANIFEST.read_bytes()
    assert hashlib.sha256(manifest_bytes).hexdigest() == bank_report["manifest_sha256"]
    manifest = json.loads(manifest_bytes)
    provenance = manifest["provenance"]
    for forbidden_or_excluded in ("No recording", "sample pack", "SoundFont", "ROM", "model output", "third-party audio"):
        assert forbidden_or_excluded in provenance
    verified: list[dict[str, object]] = []
    assert len(manifest["samples"]) == 3
    for sample in manifest["samples"]:
        path = driving.POC_ROOT / sample["path"]
        assert version_two.sha256(path) == sample["sha256"]
        with wave.open(str(path), "rb") as handle:
            metadata = {
                "channels": handle.getnchannels(),
                "sample_width": handle.getsampwidth(),
                "sample_rate": handle.getframerate(),
                "frames": handle.getnframes(),
            }
            data = np.frombuffer(handle.readframes(handle.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
        assert metadata == {
            "channels": 1,
            "sample_width": 2,
            "sample_rate": driving.PERCUSSION_SAMPLE_RATE,
            "frames": sample["frames"],
        }
        assert len(data) > 100
        assert np.max(np.abs(data)) <= 0.81
        assert abs(float(data[-1])) < 0.002
        verified.append({"bank_id": sample["bank_id"], "sha256": sample["sha256"], **metadata, "final_sample_absolute": abs(float(data[-1]))})
    return {
        "manifest_sha256": bank_report["manifest_sha256"],
        "provenance": provenance,
        "commercial_use_status": manifest["commercial_use_status"],
        "samples": verified,
    }


def verify_audio() -> dict[str, object]:
    report = json.loads(driving.BUILD_REPORT.read_text(encoding="utf-8"))
    audio = report["audio"]
    assert audio is not None
    ogg_hash = version_two.sha256(driving.AUDIO_OGG)
    flac_hash = version_two.sha256(driving.AUDIO_FLAC)
    assert ogg_hash == audio["ogg_sha256"]
    assert flac_hash == audio["flac_sha256"]
    assert verify_two.ogg_serials(driving.AUDIO_OGG) == {driving.OGG_SERIAL}
    ogg_probe = verify_two.ffprobe(driving.AUDIO_OGG)
    flac_probe = verify_two.ffprobe(driving.AUDIO_FLAC)
    for probe, codec in ((ogg_probe, "vorbis"), (flac_probe, "flac")):
        assert probe["streams"][0]["codec_name"] == codec
        assert int(probe["streams"][0]["sample_rate"]) == driving.OUTPUT_SAMPLE_RATE
        assert probe["streams"][0]["channels"] == 2
        assert abs(float(probe["format"]["duration"]) - audio["duration_seconds"]) < 0.02
    verify_two.strict_decode(driving.AUDIO_OGG)
    verify_two.strict_decode(driving.AUDIO_FLAC)
    peak = verify_two.max_volume_db(driving.AUDIO_FLAC)
    assert peak < -0.1
    assert abs(peak - audio["peak_dbfs"]) < 0.15
    silence = verify_two.long_silence_events(driving.AUDIO_FLAC)
    assert not silence
    decoded = {
        "ogg_vorbis": verify_two.decoded_pcm_continuity(driving.AUDIO_OGG),
        "lossless_flac": verify_two.decoded_pcm_continuity(driving.AUDIO_FLAC),
    }
    for container in decoded.values():
        for seam, typical in zip(
            container["first_last_sample_delta"],
            container["p99_9_adjacent_sample_delta_histogram_upper_bound"],
        ):
            assert seam < 0.015
            assert seam <= typical
    stems = audio["pre_master_stem_rms"]
    assert stems["upper_strings_violin_i_ii"] > stems["percussion"]
    assert stems["low_strings_cello_and_bass"] > stems["upper_strings_violin_i_ii"]
    assert audio["percussion_reconstruction_filter"].endswith("otherwise dry")
    return {
        "ogg": ogg_probe,
        "flac": flac_probe,
        "ogg_sha256": ogg_hash,
        "flac_sha256": flac_hash,
        "ogg_serial": f"0x{driving.OGG_SERIAL:08x}",
        "strict_decode": True,
        "independent_peak_dbfs": peak,
        "silence_events_at_minus_60_dbfs_over_750ms": silence,
        "duration_seconds": audio["duration_seconds"],
        "pre_master_stem_rms": stems,
        "pre_encode_loop_crossfade": audio["loop_crossfade"],
        "decoded_container_loop_seams": decoded,
        "echo": audio["echo"],
    }


def verify() -> dict[str, object]:
    assert base.verify_immutable_source() == base.EXPECTED_SOURCE_SHA256
    report = {
        "ok": True,
        "source_sha256": base.EXPECTED_SOURCE_SHA256,
        "prior_versions_unchanged": verify_prior_versions_unchanged(),
        "midi": verify_midi(),
        "percussion_pattern": verify_percussion_pattern(),
        "procedural_percussion_bank": verify_percussion_bank(),
        "audio": verify_audio(),
    }
    VERIFICATION_REPORT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return report


def main() -> int:
    print(json.dumps(verify(), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
