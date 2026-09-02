# IMSLP Score Cross-check

## Reference inspected

The OpenScore transcription was checked against the public-domain 1890 Breitkopf & Hartel complete score saved at `source/reference/IMSLP04047-SchubertStringQuartetNo14.pdf`.

Movement II occupies PDF pages 13-19, printed score pages 271-277. All seven movement pages were rendered and visually inspected.

## Findings

- The movement begins with the heading **Andante con moto**, two flats/G minor, common time, four staves in the order Violin I, Violin II, Viola, and Cello, and a soft homorhythmic opening theme. These agree with the extracted MusicXML.
- The MusicXML contains 180 measure objects numbered 1-172. Eight measure numbers are duplicated because the score prints paired first and second endings at 31, 47, 71, 79, 95, 103, 119, and 127. This agrees with the engraved score and is not a transcription duplication error.
- Expanding the written repeats and alternate endings produces 300 performed measures and 1200 quarter-note beats per part.
- Representative checks covered the opening chorale, the first animated variation after the first/second ending, the rapid repeated-note variation, the later sustained counterpoint, and the quiet final cadence immediately before **Scherzo: Allegro molto**. No pitch, rhythm, scoring, or structural discrepancy was found at those inspected points.
- The OpenScore file contains playback-only numeric tempo instructions, beginning at quarter note = 94 and changing between variations. The 1890 engraving prints the verbal heading but no corresponding numeric metronome map. The normalized MIDI retains the OpenScore playback map for traceability; `faithful_retro.mid` deliberately replaces it with one steady quarter note = 92 tempo.
- Music21 reports one source-level warning: a MusicXML `<dashes>` stop occurs without a matching start. This concerns a dashed direction/spanner, not note or rhythm data. The arrangement does not depend on dashed text spanners.

This was a full-page structural and representative-note cross-check, not a scholarly note-by-note critical edition comparison. The source remained unchanged throughout.
