# Classical track review checklist

## Provenance

- Original composition is public domain in the intended commercial distribution scope.
- Machine-readable transcription is CC0 or explicitly public domain.
- Immutable source URL, format, retrieval date, evidence, local filename, and SHA-256 agree between `track.json` and `LICENSE_SOURCE.md`.
- Original source is unchanged under `source/`; modern arrangements, commercial MIDI, recordings, sample packs, SoundFonts, ROM content, and model audio were not used.
- A public-domain score edition was used to spot-check movement, parts, repeats/endings, pitches/rhythm, dynamics, and cadence where practical.

## Musical build

- Full normalized MusicXML/MIDI and separate original parts exist.
- The score-specific script recreates the versioned MIDI from immutable inputs.
- Arrangement notes enumerate selections, ordering, omissions, repeats, octave doubling, pitch/harmony changes, balance, timbre, percussion, and loop treatment.
- First-pass harmony, thematic identity, chamber interplay, and upper-string activity remain legible.
- Cello/low material leads without masking the violins; percussion drives without dominating.
- Every audition is separately named/versioned.

## Render and delivery

- Canonical bank manifest and all WAV hashes pass.
- MIDI hash, named tracks, and expected note counts pass.
- Ogg and FLAC strict-decode; duration, peak, long-silence, and expected-hash checks pass.
- Audition handoff includes MIDI, Ogg, short changes, and two or three next directions.
- Only an explicitly approved version is promoted to game assets.
- Game provenance, loop import, intended music routes, focused tests, and playable inspection are complete.
