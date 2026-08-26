from __future__ import annotations

import json
from pathlib import Path
import re

from .common import PipelineError, write_json


def _slug(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    if not slug:
        raise PipelineError("track id must contain letters or digits")
    return slug


def create_scaffold(root: Path, track_id: str, title: str, composer: str, bank_manifest: Path) -> Path:
    track_id = _slug(track_id)
    destination = (root / track_id).resolve()
    if destination.exists():
        raise PipelineError(f"Refusing to overwrite existing track directory: {destination}")
    (destination / "source").mkdir(parents=True)
    (destination / "normalized" / "parts").mkdir(parents=True)
    (destination / "versions" / "v01").mkdir(parents=True)
    (destination / "scripts").mkdir(parents=True)
    relative_bank = Path(__import__("os").path.relpath(bank_manifest.resolve(), destination))
    config = {
        "schema_version": 1,
        "track_id": track_id,
        "title": title,
        "composer": composer,
        "approval": {
            "status": "audition",
            "version": "v01",
            "approved_by": "",
            "approved_on": "",
        },
        "source": {
            "rights_status": "source_required",
            "composition_public_domain": False,
            "composition_public_domain_evidence": "",
            "composer": composer,
            "composition": title,
            "source_url": "",
            "source_format": "",
            "transcription_license": "",
            "license_evidence": "",
            "date_retrieved": "",
            "path": "source/REPLACE_WITH_IMMUTABLE_SOURCE",
            "sha256": "",
            "license_file": "LICENSE_SOURCE.md",
        },
        "arrangement": {
            "version": "v01",
            "midi_path": "versions/v01/arrangement.mid",
            "midi_sha256": "",
            "notes_file": "versions/v01/ARRANGEMENT_NOTES.md",
            "expected_note_counts": {},
        },
        "reproducibility": {
            "build_script": {"path": "scripts/build_arrangement.py", "sha256": ""},
            "arrangement_notes": {"path": "versions/v01/ARRANGEMENT_NOTES.md", "sha256": ""},
            "normalized_full_score_musicxml": {"path": "normalized/full_score.musicxml", "sha256": ""},
            "normalized_full_score_midi": {"path": "normalized/full_score.mid", "sha256": ""},
            "expected_part_count": 0,
            "normalized_parts": [],
        },
        "render": {
            "bank_manifest": str(relative_bank),
            "tempo_mode": "fixed_qpm",
            "tempo_qpm": 92,
            "sample_rate": 44100,
            "output_basename": "versions/v01/preview",
            "target_peak_dbfs": -7.5,
            "vorbis_encoder": "auto",
            "saturation_drive": 1.08,
            "output_signal_quantization_bits": 15,
            "crossfade_seconds": 2.608695652173913,
            "ogg_stream_serial": "0x45545531",
            "string_reconstruction_filter_width": 5,
            "percussion_reconstruction_filter_width": 3,
            "echo": {
                "darkening_filter_width": 9,
                "taps": [
                    {"delay_seconds": 0.096, "gain": 0.12},
                    {"delay_seconds": 0.192, "gain": 0.052},
                    {"delay_seconds": 0.288, "gain": 0.022},
                ],
            },
            "tracks": [],
            "percussion": {"midi_track": "", "notes": {}},
        },
        "verification": {
            "duration_tolerance_seconds": 0.02,
            "peak_tolerance_db": 0.05,
            "max_silence_seconds": 0.75,
            "max_loop_seam_to_p99_9_ratio": 1.0,
        },
        "expected_outputs": {},
    }
    write_json(destination / "track.json", config)
    (destination / "LICENSE_SOURCE.md").write_text(
        f"# Source license — {title}\n\n"
        "> STOP: do not arrange or render until every field below is complete, the rights are unambiguous, and `source.rights_status` in `track.json` is `cleared`.\n\n"
        f"- Composition: {title}\n"
        f"- Composer: {composer}\n"
        "- Underlying composition public-domain evidence: TODO\n"
        "- Source URL: TODO\n"
        "- Source format: TODO\n"
        "- Machine-readable transcription license: TODO (must explicitly be CC0 or public domain)\n"
        "- License evidence: TODO\n"
        "- Date retrieved: TODO (YYYY-MM-DD)\n"
        "- Immutable source SHA-256: TODO\n\n"
        "Keep the original downloaded file byte-for-byte unchanged under `source/`. Do not use a modern arrangement, commercial MIDI, or audio recording as the musical source.\n",
        encoding="utf-8",
    )
    (destination / "versions" / "v01" / "ARRANGEMENT_NOTES.md").write_text(
        f"# Arrangement notes — {title} v01\n\n"
        "Document all selection, cuts/repeats, voice allocation, octave changes, gate/velocity changes, added percussion, tempo decisions, harmony changes, and loop treatment. State explicitly what remains unchanged.\n",
        encoding="utf-8",
    )
    (destination / "scripts" / "build_arrangement.py").write_text(
        "#!/usr/bin/env python3\n"
        '"""Score-specific, reproducible arrangement build. Never hand-edit generated outputs."""\n\n'
        "from pathlib import Path\n\n"
        "# Use classical_soundtrack_pipeline.normalization.load_score and\n"
        "# write_normalized_score after selecting the intended movement.\n"
        "TRACK_ROOT = Path(__file__).resolve().parents[1]\n\n"
        "def main() -> int:\n"
        "    raise SystemExit(\"Implement the score-specific MusicXML/MIDI transformation after source clearance; see spec/classical_soundtrack_pipeline.md.\")\n\n"
        "if __name__ == \"__main__\":\n"
        "    raise SystemExit(main())\n",
        encoding="utf-8",
    )
    (destination / "README.md").write_text(
        f"# {title}\n\n"
        "Start with `LICENSE_SOURCE.md`, preserve the immutable download under `source/`, normalize all original parts under `normalized/parts/`, and keep every audition under a new `versions/vNN/` directory. The repo skill `$create-labyrinth-classical-track` contains the complete workflow.\n",
        encoding="utf-8",
    )
    return destination
