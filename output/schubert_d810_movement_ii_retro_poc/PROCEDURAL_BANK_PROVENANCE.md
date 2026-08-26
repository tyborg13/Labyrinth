# Procedural Bank Provenance

## Asset set

- **Name:** Escape the Umbra Procedural Mourning Strings v1
- **Created for:** Schubert D.810 Movement II active tactical-loop proof of concept
- **Creation method:** deterministic local synthesis by `scripts/build_active_tactical_loop.py`
- **Source format:** generated mono PCM WAV, 16 kHz, 16-bit container with deliberately reduced 9-11-bit signal precision

## Rights and source status

The five bank samples are original project-generated audio derived solely from mathematical sinusoidal functions and fixed integer parameters in the committed build script. No pre-existing audio was supplied to the generator.

Specifically, the generator uses no:

- musical recording or isolated performer note;
- commercial or freeware sample pack;
- SoundFont;
- ROM, game-ripped BRR data, or emulated console asset;
- audio-model output;
- copyrighted modern arrangement.

There is therefore no third-party recording or sample-bank license to clear for these WAV files. They are created as project work product for commercial use, modification, pitch-shifting, looping, rendering, and inclusion in Escape the Umbra builds. This statement concerns the sample-bank audio; the underlying Schubert composition and OpenScore transcription provenance remain documented separately in `LICENSE_SOURCE.md`.

## Reproducibility and evidence

`procedural_bank/bank_manifest.json` records for each sample:

- filename and SHA-256;
- root MIDI pitch and tuning frequency;
- sample rate, channel count, and bit depth;
- sustain-loop start and end samples;
- harmonic amplitudes;
- deterministic phase seed;
- attack-brightness and quantization parameters.

The verifier independently checks every recorded hash and WAV property. The entire bank is regenerated every time `scripts/build_active_tactical_loop.py` runs; no WAV is manually edited.

## Files

- `procedural_bank/veiled_violin_a4.wav`
- `procedural_bank/ashen_violin_d4.wav`
- `procedural_bank/hollow_viola_c3.wav`
- `procedural_bank/grave_cello_c2.wav`
- `procedural_bank/undercrypt_bass_e1.wav`
- `procedural_bank/bank_manifest.json`

## Retrieval date

Not applicable. These samples were generated locally on 2026-08-25 (America/New_York) and were not retrieved from an external source.
