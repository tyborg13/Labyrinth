# Chopin Op. 35 Death-Music Provenance

`chopin_op35_funeral_march_death_loop.ogg` is an exact byte-for-byte copy of the strictly verified v05 artifact at:

`output/classical_soundtracks/chopin_op35_funeral_march/versions/v05/preview.ogg`

- SHA-256: `f005bda46c395579b32f0afeb749b5e16775efa2ecee5203e2a4bacd872b2569`
- Duration: 29.092 seconds (decoded Ogg)
- Composition: *Piano Sonata No. 2 in B-flat minor, Op. 35*, Movement III, `Marche funèbre`
- Composer: Frédéric Chopin (1810–1849)
- Composition status: public domain
- Machine-readable transcription: PDMX v9 complete solo-piano score, CC0 1.0 Universal, no-license-conflict and all-valid metadata
- Arrangement and audio: project-generated work product using the repository's deterministic procedural instrument bank; no recording, commercial MIDI, SoundFont, sample pack, ROM-derived sample, or model-generated audio

The v05 MIDI and rendered audio are byte-for-byte identical to the project-owner-approved v04 audition. The arrangement is one contiguous eight-measure span corresponding to source measures 93–100, uniformly transposed down three semitones from B-flat minor to G minor. The initial melody preserves v04's intervals, rhythms, durations, harmony, and voice relationships. Only the recognizable late Grave Cello and Veiled Violin lead in source measures 99–100 is suppressed; there are no reordered measures or authored bridges.

The v05 render freezes the FFmpeg native Vorbis encoder and a 0.9091-second equal-power loop crossfade. Strict verification records decoded seam ratios of 0.152 or lower against the configured maximum of 1.0, strict decode success, source and procedural-bank hashes, note counts, duration, peak, and silence checks in `versions/v05/VERIFICATION.json`.

Complete source URLs, retrieval evidence, immutable source hashes, license analysis, arrangement history, and approval metadata live under `output/classical_soundtracks/chopin_op35_funeral_march/`. The game imports this Ogg as a looping `AudioStreamOggVorbis`. `scripts/music_library.gd` routes it only to terminal defeat, and `scripts/run_scene.gd` begins a 0.6-second combat-music fade-out at the start of the player death animation before fading this track in over 1.2 seconds.
