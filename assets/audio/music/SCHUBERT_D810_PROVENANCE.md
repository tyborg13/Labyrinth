# Schubert D.810 Combat-Music Provenance

`schubert_d810_movement_ii_driving_loop.ogg` is an exact byte-for-byte copy of the verified version-3 audition artifact at:

`output/schubert_d810_movement_ii_retro_poc/driving_tactical_loop_preview.ogg`

- SHA-256: `bb0a7c9b30883e87f0d2c0be88fd11844056ce40c628860950a02fc51677403b`
- Composition: String Quartet No. 14 in D minor, D.810, “Death and the Maiden,” Movement II
- Composer: Franz Schubert (1797-1828)
- Composition status: public domain
- Machine-readable transcription: OpenScore String Quartets, CC0
- Arrangement and audio: project-generated work product using deterministic mathematical synthesis; no recording, commercial MIDI, SoundFont, sample pack, ROM-derived sample, or model-generated audio

Complete source URLs, retrieval evidence, immutable source hashes, and license analysis are in `output/schubert_d810_movement_ii_retro_poc/LICENSE_SOURCE.md`. Arrangement changes and procedural percussion rights are documented in `DRIVING_TACTICAL_LOOP_NOTES.md` and `DRIVING_PERCUSSION_PROVENANCE.md` in that same POC folder.

The game imports the Ogg as a looping `AudioStreamOggVorbis`; `scripts/music_library.gd` routes it only to non-boss combats.
