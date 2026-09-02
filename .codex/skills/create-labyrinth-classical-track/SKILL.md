---
name: create-labyrinth-classical-track
description: "Create, revise, render, verify, audition, or integrate provenance-safe classical soundtrack adaptations for Escape the Umbra. Use when sourcing a public-domain composition, normalizing MusicXML/MIDI, arranging a new retro/dark-fantasy track, rebalancing an existing classical remix, using the procedural instrument bank, adding restrained percussion, preserving audition versions, documenting licenses, or promoting approved music into game contexts."
---

# Create a Labyrinth classical track

Use the repository pipeline in `spec/classical_soundtrack_pipeline.md` and the style reference in `output/schubert_d810_movement_ii_retro_poc/driving_tactical_loop.track.json`. Work inside the repository's required `$parallel-labyrinth-task` workflow for substantive changes.

## Establish the mode

Choose one and keep the scope explicit:

- **New track:** create a new non-overwriting workspace with `tools/classical_soundtrack.py scaffold`.
- **Revision:** add a new `versions/vNN/`; never replace a prior audition.
- **Promotion:** verify an already approved version, copy its exact Ogg, document provenance, then wire only the requested game contexts.

Read `references/review_checklist.md` before implementation. Read the full pipeline spec when creating a track or changing the bank/renderer.

## Gate the source before arranging

Search in this order: OpenScore CC0, another reputable CC0 or explicit public-domain machine-readable source, then a public-domain IMSLP score plus reproducible transcription. Save the original file unchanged under `source/` and record its immutable URL and SHA-256.

Do not use a modern copyrighted arrangement, commercial MIDI, recording, SoundFont, sample pack, ROM/rip, or generated-model audio. If any rights are ambiguous, stop using that source and find another. Set the positive `source.rights_basis` enum to `cc0` or `public_domain`; never infer permission from a label that merely mentions those terms. Do not set `source.rights_status` to `cleared` until `LICENSE_SOURCE.md` and `track.json` contain matching evidence.

## Build reproducibly

Preserve normalized full-score MusicXML/MIDI and the original instrumental parts separately. Put score-specific musical decisions in `scripts/build_arrangement.py`; do not hand-edit generated MIDI. Keep harmony, themes, upper-string action, and counterpoint recognizable on the first pass. Favor the cello/low register without masking violins. Keep practical melodic density near four to six voices and percussion supportive.

Use the canonical `classical_dark_fantasy_v1` procedural bank. Change track-specific gain, pan, release, vibrato, echo, and percussion mappings in `track.json`. Do not alter the canonical bank in place; create a new version if synthesis changes any sample hash.

Run `doctor`, the score-specific build, `render`, and `verify`. Freeze hashes for the build script, arrangement notes, normalized full score, every original part, and MIDI. Render experiments to a temporary output directory; rendering refuses to replace different audition bytes. After user approval, set `approval.status` plus approver/date/version, choose a fixed Vorbis encoder, set expected Ogg/FLAC hashes, rerun verification, and retain the MIDI, Ogg, FLAC, render report, verification report, and complete arrangement notes.

## Audition and integrate

Give the user the versioned MIDI and Ogg, a concise change summary, and two or three specific follow-up directions. Pause for taste feedback rather than iterating blindly.

For promotion, verify first and copy with the `promote` command. Add provenance alongside the game asset, update the intended `MusicLibrary` routes, preserve boss routing unless explicitly requested, run focused import/routing tests, and provide a playable inspection fixture. Obtain peer signoff on the exact committed HEAD before requesting publication approval.
