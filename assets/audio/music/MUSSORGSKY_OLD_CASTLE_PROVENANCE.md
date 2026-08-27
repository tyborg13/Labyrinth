# Mussorgsky `The Old Castle` Main-Menu Music Provenance

`mussorgsky_old_castle_main_menu.ogg` is an exact byte-for-byte copy of the strictly verified v07 artifact at:

`output/classical_soundtracks/mussorgsky_pictures_old_castle/versions/v07/preview.ogg`

- SHA-256: `57fabef2f4298b22ef7477e18b261702152483c9cb7aabe43acd99ece952fdc8`
- Duration: 131.541 seconds (decoded Ogg)
- Composition: `Il vecchio castello` (`The Old Castle`) from *Pictures at an Exhibition* (1874)
- Composer: Modest Mussorgsky (1839-1881)
- Composition status: public domain
- Machine-readable transcription: PDMX v9 score 5952494, CC0 1.0 Universal, no-license-conflict and all-valid metadata
- Arrangement and audio: project-generated work product using the repository's deterministic procedural instrument bank; no recording, commercial MIDI, SoundFont, sample pack, ROM-derived sample, or model-generated audio

The arrangement uses one contiguous span of printed measures 7-68 at 84 QPM. Its five source-derived string voices preserve the score's melody, measure order, harmony, and phrase structure; project-authored additions are a restrained four-hit 6/8 percussion layer and a slow G-sharp3/D-sharp4 low-mid veil. The promoted v07 MIDI is byte-for-byte identical to the project-owner-approved v06 audition.

The v07 render uses the frozen FFmpeg native Vorbis encoder path and a 1.3167-second equal-power loop crossfade. Strict verification records decoded seam ratios of 0.161 or lower against the configured maximum of 1.0, strict decode success, source and procedural-bank hashes, note counts, duration, peak, and silence checks in `versions/v07/VERIFICATION.json`.

Complete immutable source URLs, source and scan hashes, license evidence, arrangement history, and approval metadata live under `output/classical_soundtracks/mussorgsky_pictures_old_castle/`. The game imports this Ogg as a looping `AudioStreamOggVorbis`; `scripts/main_menu.gd` requests it directly for the production main menu, while `scripts/music_library.gd` preserves all combat, room, and boss routing.
