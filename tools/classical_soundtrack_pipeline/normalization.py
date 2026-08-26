from __future__ import annotations

from pathlib import Path
import re

from music21 import converter, stream

from .common import PipelineError, sha256


def load_score(source_path: Path, opus_index: int | None = None) -> stream.Score:
    """Load one score; callers select score-specific movement bounds afterward."""
    parsed = converter.parse(source_path)
    if isinstance(parsed, stream.Opus):
        scores = list(parsed.scores)
        if opus_index is None:
            raise PipelineError(f"{source_path} contains {len(scores)} scores; choose an opus index explicitly")
        if opus_index < 0 or opus_index >= len(scores):
            raise PipelineError(f"Opus index {opus_index} is outside 0..{len(scores) - 1}")
        return scores[opus_index]
    if not isinstance(parsed, stream.Score):
        raise PipelineError(f"Expected a score in {source_path}, found {type(parsed).__name__}")
    return parsed


def _part_stem(part: stream.Part, index: int) -> str:
    label = (part.partName or part.id or f"part_{index + 1}").lower()
    slug = re.sub(r"[^a-z0-9]+", "_", str(label)).strip("_")
    return f"{index + 1:02d}_{slug or f'part_{index + 1}'}"


def write_normalized_score(score: stream.Score, destination: Path, expand_repeats: bool = True) -> dict[str, object]:
    """Export a selected movement as full-score MusicXML/MIDI and separate parts."""
    destination.mkdir(parents=True, exist_ok=True)
    parts_dir = destination / "parts"
    parts_dir.mkdir(parents=True, exist_ok=True)
    normalized = score.expandRepeats() if expand_repeats else score
    full_xml = destination / "full_score.musicxml"
    full_midi = destination / "full_score.mid"
    normalized.write("musicxml", fp=str(full_xml))
    normalized.write("midi", fp=str(full_midi))
    part_reports: list[dict[str, object]] = []
    for index, part in enumerate(normalized.parts):
        stem = _part_stem(part, index)
        part_score = stream.Score(id=f"normalized_{stem}")
        part_score.insert(0, part)
        xml_path = parts_dir / f"{stem}.musicxml"
        midi_path = parts_dir / f"{stem}.mid"
        part_score.write("musicxml", fp=str(xml_path))
        part_score.write("midi", fp=str(midi_path))
        part_reports.append({
            "name": part.partName or str(part.id),
            "musicxml_path": str(xml_path),
            "musicxml_sha256": sha256(xml_path),
            "midi_path": str(midi_path),
            "midi_sha256": sha256(midi_path),
        })
    if not part_reports:
        raise PipelineError("Selected score contains no parts")
    return {
        "expanded_repeats": expand_repeats,
        "part_count": len(part_reports),
        "full_score_musicxml": str(full_xml),
        "full_score_musicxml_sha256": sha256(full_xml),
        "full_score_midi": str(full_midi),
        "full_score_midi_sha256": sha256(full_midi),
        "parts": part_reports,
    }
