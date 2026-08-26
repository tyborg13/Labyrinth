# Complete-movement transcription audit

## Authority and scope

The sole musical authority is the checked-in public-domain 1918 Breitkopf & Härtel reprint of the 1886 Bessel solo-piano edition. `Il vecchio castello` occupies PDF pages 8-10, printed pages 7-9. The movement has 106 printed measures in 6/8.

No third-party MusicXML, MIDI, modern arrangement, or performance recording was imported. The three raw MusicXML files in `omr_raw/` were generated inside this project with `homr` 0.7.0 from the checked-in scan and are retained so the transformation is inspectable and repeatable.

## Page and measure map

| Scan location | Printed systems, measures per system | Global measure span |
| --- | --- | --- |
| PDF 8 / printed 7 | 1-5: 6, 6, 6, 6, 6 | 1-30 |
| PDF 9 / printed 8 | 1-6: 7, 6, 6, 7, 6, 7 | 31-69 |
| PDF 10 / printed 9 | 1-6: 6, 6, 7, 7, 6, 5 | 70-106 |

The frozen page inputs contain 30, 39, and 37 measures respectively, matching those printed barlines exactly. `scripts/build_full_arrangement.py` rejects any different hash, page count, or total count.

## Deterministic cleanup

The optical pass identifies four stable principal voices: two upper-staff voices and two lower-staff voices. Rare extra OMR voices are engraving doublings or recognition artifacts and are excluded from this practical reduction.

OMR sometimes encodes a whole-measure rest as four quarter notes or allows simultaneous voices to overflow or underfill a printed barline. The builder normalizes each principal voice to exactly three quarter notes per measure by:

1. preserving recognized pitch/chord order and note duration until the printed barline;
2. retaining recognized grace-note groups immediately before their principal note;
3. trimming only duration that crosses that barline; and
4. filling an underfull remainder with silence.

The generated build report lists every affected measure, source voice, and raw duration. This is a practical, source-checked game transcription, not a critical or scholarly engraving; the immutable scan should be consulted if a later edit depends on an inner-note or articulation detail.

## Arrangement boundary

The normalized v02 score retains all 106 measures in source order. The arrangement does not cut, reorder, repeat, reharmonize, or construct a new cadence. It maps the recognized piano voices onto five procedural bowed voices, uses octave placement to fit those instruments, and simplifies dense chord voicings where a monophonic game voice cannot carry every simultaneous piano note. The leading melody, rhythmic placement, meter, bass motion, harmonic progression, and formal sequence remain source-derived.
