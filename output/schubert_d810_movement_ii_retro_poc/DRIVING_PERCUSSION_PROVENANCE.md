# Procedural Percussion Bank Provenance

## Asset set

- **Name:** Escape the Umbra Procedural Funeral Pulse v1
- **Created for:** Schubert D.810 Movement II driving tactical-loop proof of concept, version 3
- **Creation method:** deterministic local mathematical synthesis by `scripts/build_driving_tactical_loop.py`
- **Source format:** generated mono PCM WAV, 16 kHz, 16-bit container with deliberately reduced 8-10-bit signal precision

## Rights and source status

The three percussion one-shots are original project-generated audio derived only from mathematical oscillator functions, fixed integer-noise seeds, envelopes, and fixed numeric parameters in the committed build script. No pre-existing audio was supplied to the generator.

The generator uses no:

- recording, performer sample, isolated drum hit, or field recording;
- commercial, freeware, or public-domain sample pack;
- SoundFont or sampler library;
- ROM, game-ripped sample, BRR data, or emulated console asset;
- model-generated audio;
- copyrighted modern arrangement or commercial MIDI.

There is therefore no third-party recording or sample-bank license to clear for these WAV files. They are project work product intended for commercial use, modification, rendering, and inclusion in Escape the Umbra and its distributed builds. This statement concerns the percussion audio; the underlying Schubert composition and OpenScore transcription provenance remain documented in `LICENSE_SOURCE.md`.

## Reproducibility and evidence

`procedural_percussion_bank/bank_manifest.json` records for each one-shot:

- filename and SHA-256;
- MIDI fallback note and descriptive role;
- sample rate, channel count, container bit depth, and frame count;
- deliberate signal-quantization precision;
- synthesis description, duration, panning, and render gain.

The low drum uses an exponentially swept sinusoidal membrane and a fixed-seed transient. The muted tom uses a shorter swept membrane plus an inharmonic upper partial. The ash tick uses high-passed fixed-seed integer noise and a quiet mathematical metallic partial. Each signal is deterministically tapered to zero at its tail.

The verifier independently checks every recorded hash, WAV property, peak bound, and zeroed tail. The whole bank is regenerated whenever `scripts/build_driving_tactical_loop.py` runs; no WAV is manually edited.

## Files

- `procedural_percussion_bank/umbra_war_drum.wav`
- `procedural_percussion_bank/bone_tom.wav`
- `procedural_percussion_bank/ash_tick.wav`
- `procedural_percussion_bank/bank_manifest.json`

## Retrieval date

Not applicable. These samples were generated locally on 2026-08-26 (America/New_York) and were not retrieved from an external source.
