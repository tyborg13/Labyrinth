# Source and License Record

## Composition

- **Composition:** String Quartet No. 14 in D minor, D.810, "Death and the Maiden," Movement II (Andante con moto)
- **Composer:** Franz Schubert (1797-1828)
- **Underlying composition status:** Public domain. Schubert died in 1828, so the composition is public domain in jurisdictions whose copyright term is life plus 100 years or shorter. The referenced 1890 edition also predates the current United States public-domain cutoff.
- **Modern arrangement used as a source:** None
- **Commercial MIDI used as a source:** None
- **Audio recording or performance used as a musical source:** None

## Machine-readable musical source

- **Source project:** OpenScore String Quartets
- **Corpus catalogue:** https://fourscoreandmore.org/openscore/stringquartets/
- **Repository:** https://github.com/OpenScore/StringQuartets
- **Immutable repository revision:** `91c780acf1502e7b4f745dc100836c501f41d8e3`
- **Immutable source URL:** https://raw.githubusercontent.com/OpenScore/StringQuartets/91c780acf1502e7b4f745dc100836c501f41d8e3/scores/Schubert%2C_Franz/String_Quartet_in_D_minor%2C_D.810%2C_Op.14_%28%E2%80%9CDeath_and_the_Maiden%E2%80%9D%29/sq7397765.mxl
- **Source format:** Compressed MusicXML (`.mxl`), MuseScore/OpenScore score ID `7397765`
- **Saved unchanged as:** `source/openscore_sq7397765.mxl`
- **SHA-256:** `c1370ff43b2272b88e04d41d3cc31ca6717a982eaa09cc5540a5952b4f3c1bd5`
- **Date retrieved:** 2026-08-25 (America/New_York)

### License status and evidence

The OpenScore String Quartets repository README states that the scores are released under Creative Commons Zero (CC0) and points to its `LICENSE.txt`. The repository license is CC0 1.0 Universal.

- **Repository license page:** https://github.com/OpenScore/StringQuartets/blob/91c780acf1502e7b4f745dc100836c501f41d8e3/LICENSE.txt
- **Local unchanged license evidence:** `source/OpenScore_LICENSE_CC0-1.0.txt`
- **License-file SHA-256:** `a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`
- **CC0 deed:** https://creativecommons.org/publicdomain/zero/1.0/

OpenScore requests a courtesy credit and link for public-facing uses. That request is not a CC0 license condition, but the recommended credit is:

> Musical source: OpenScore String Quartets (CC0), score 7397765. Original composition by Franz Schubert (public domain).

The source rights are explicit rather than inferred: the machine-readable transcription is CC0, and the underlying composition is public domain. This source therefore passed the project's provenance gate for commercial-use arrangement work.

## Public-domain reference edition

- **Reference:** *Franz Schubert's Werke*, Series V, No. 14, edited by Joseph Hellmesberger Sr. and Eusebius Mandyczewski
- **Publisher/date:** Breitkopf & Hartel, Leipzig, 1890
- **IMSLP work page:** https://imslp.org/wiki/String_Quartet_in_D_minor%2C_D.810_%28Schubert%2C_Franz%29
- **Direct PDF:** https://vmirror.imslp.org/files/imglnks/usimg/6/67/IMSLP04047-SchubertStringQuartetNo14.pdf
- **IMSLP file number:** `#04047`
- **IMSLP status:** Public Domain
- **Saved unchanged as:** `source/reference/IMSLP04047-SchubertStringQuartetNo14.pdf`
- **SHA-256:** `55db640f6b3ec6715a0bd5527ed3f26cca181036a4e848a32027dd7d29bef48e`
- **Date retrieved:** 2026-08-25 (America/New_York)

This PDF was used only as a public-domain visual reference to check movement boundaries, scoring, repeat/ending structure, representative pitches and rhythms, dynamics, and the final cadence. It was not processed by optical music recognition and was not the machine-readable musical source.

## Preview-audio provenance

The preview contains no sampled instrument set, SoundFont, performance, or recording. `scripts/build_arrangement.py` synthesizes every sample deterministically from mathematical pulse, triangle, sine, and limited-harmonic additive waveforms. The stereo positioning and amplitude envelopes are also generated in the script.

- `faithful_retro_preview.ogg` is encoded from that generated PCM with FFmpeg's native Vorbis encoder at quality 5.
- `faithful_retro_preview.flac` is a lossless reference encoded from the same generated PCM with FFmpeg FLAC compression level 8.
- Encoding changes the container/compression only; it contributes no third-party musical or performance content.

The arrangement and procedural-rendering code were newly created for this proof of concept. No external audio asset license is required for either preview.

## Integrity

`scripts/build_arrangement.py` refuses to transform the OpenScore input unless its SHA-256 matches the value above. `scripts/verify_outputs.py` verifies the source, license, and IMSLP reference hashes before validating derived files. `SOURCE_SHA256SUMS.txt` records all three immutable inputs.

This record documents provenance rather than providing jurisdiction-specific legal advice.
