# Source license - Pictures at an Exhibition: The Old Castle

- Composition: Pictures at an Exhibition - The Old Castle
- Composer: Modest Mussorgsky (1839-1881)
- Underlying composition public-domain evidence: Modest Mussorgsky died in 1881; the solo-piano suite was first published by V. Bessel & Co. in 1886, and the Sibley Music Library marks its 1918 Breitkopf & Härtel reprint public domain.
- Immutable machine-readable source URL: https://doi.org/10.5281/zenodo.15571083
- Source format: MIDI export of the one-part solo-piano score in PDMX v9 (archive member mid/11/49/QmTV1L2x37h7VPCZNdqXCuAJq2ykz61ZxfpmnWUoWG8qLF.mid)
- Machine-readable transcription license: CC0 1.0 Universal
- License evidence: PDMX v9 metadata for score 5952494 identifies the solo-piano score as downloadable, public domain, and cc-zero; PDMX marks the row no-license-conflict and all-valid.
- Date retrieved: 2026-08-26
- Saved unchanged as: `source/mussorgsky_pictures_at_an_exhibition_pdmx_cc0.mid`
- Immutable MIDI SHA-256: `e8c7fe31e8ff267a8fa4f4ca5edd076955e49cd89548d7367a588e163079cc34`
- Local PDMX evidence: `source/PDMX_RECORD.json`
- PDMX score page: https://musescore.com/frank_luna/scores/5952494

## Public-domain visual reference

- Persistent catalogue record: https://hdl.handle.net/1802/13415
- Immutable scan URL: https://urresearch.rochester.edu/fileDownloadForInstitutionalItem.action?itemId=13118&itemFileId=30373
- Scan format: 1918 Breitkopf & Härtel reprint of the 1886 Bessel solo-piano edition
- Saved unchanged as: `source/mussorgsky_pictures_at_an_exhibition_breitkopf_1918_reprint.pdf`
- Immutable scan SHA-256: `0a73559cd865083558f6e5923dddae4390069883dad795725c19f18646e58b71`

## Transcription and arrangement boundary

The unchanged PDMX v9 MIDI is the machine-readable source. Its preserved evidence record identifies the exact archive member, dataset and archive hashes, score ID, public score URL, CC0 license, lack of a license conflict, and all-valid status. The build selects the `Il vecchio castello` interval from tick 274080 through tick 428160: 107 complete 6/8 measures, including the final measure's tied bass sustain and fermata rest.

The public-domain scan remains the visual reference. `scripts/build_full_arrangement.py` checks the opening lament event-by-event, one pitch/onset anchor at the start of every printed system, the final G-sharp-minor cadence, the bass G-sharp tied into the last measure, both movement boundaries, the source note counts, and both immutable hashes. The normalized score is a five-voice outer-line reduction of the source MIDI, not a scholarly re-engraving of every piano chord tone.

No modern copyrighted arrangement, commercial MIDI, audio recording, SoundFont, sample pack, ROM/rip, or generated-model audio was used. The v02 arrangement uses the CC0 transcription and the repository's procedural instrument bank.

To the extent that the project-authored extraction, reduction, and normalized score outputs contain copyrightable expression, this repository contribution dedicates them to the public domain under [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).

Musical source credit for public-facing use:

> Modest Mussorgsky, *Pictures at an Exhibition: The Old Castle* (1874), original solo-piano composition; CC0 solo-piano transcription from PDMX v9, cross-checked against the public-domain 1918 Breitkopf & Härtel reprint preserved by the Sibley Music Library.
