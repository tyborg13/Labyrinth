# Complete-movement transcription audit

## Sources and boundary

The machine-readable source is the unchanged, no-license-conflict CC0 solo-piano MIDI from PDMX v9 recorded in `source/PDMX_RECORD.json`. The checked-in public-domain 1918 Breitkopf & Härtel scan is the visual reference.

In the complete-suite MIDI, `Il vecchio castello` begins at absolute tick 274080 with a 6/8 meter, five-sharp key signature, and movement tempo marker. The printed movement ends at tick 428160; the next movement's meter marker begins at tick 430560. With 480 ticks per quarter and 1440 ticks per 6/8 measure, the selected interval contains 107 measures. Measure 106 holds the final G-sharp-minor cadence and measure 107 is the printed fermata rest.

## Page and measure map

| Scan location | Printed systems, measures per system | Global measure span |
| --- | --- | --- |
| PDF 8 / printed 7 | 1-5: 6, 6, 6, 6, 6 | 1-30 |
| PDF 9 / printed 8 | 1-6: 7, 6, 6, 7, 6, 7 | 31-69 |
| PDF 10 / printed 9 | 1-6: 6, 6, 7, 7, 6, 6 | 70-107 |

The final silent bar is visually present after the last sounding cadence. It was omitted by the first OMR-derived draft, which is why that rejected draft reported 106 rather than 107 measures.

## Source anchors and deterministic extraction

`scripts/build_full_arrangement.py` rejects any change to the source MIDI, PDMX evidence record, or reference scan. It then checks:

1. the exact movement and next-movement boundary markers;
2. 575 non-zero treble-staff events and 593 non-zero bass-staff events in the selected movement;
3. the printed opening lament, including the two-note ornament in measure 9;
4. one pitch/onset group at the start of each of the scan's 17 printed systems;
5. the complete G-sharp-minor cadence in measure 106; and
6. the absence of a new note onset in the final fermata-rest measure.

Every checked anchor is written to `versions/v02/BUILD_REPORT.json`. Generated MusicXML part identifiers and encoding dates are frozen, so rebuilds do not change across processes or calendar dates.

## Reduction boundary

The preserved CC0 MIDI contains the original piano source. The normalized and arranged outputs retain the highest and lowest sounding pitch at each onset on each staff, which preserves the leading line, bass motion, chord boundaries, rhythm, and harmonic outer voices while reducing dense piano chords to four practical bowed lines. The leading treble line is also doubled one octave lower by the cello, yielding five timbral lines in the game arrangement. The audition MIDI keeps exact source ticks; normalized notation rounds only playback gate endpoints to a 15-tick (1/128-note) MusicXML grid so one-tick MuseScore articulation gaps do not become unportable 2048th-note rests.

There are no cuts, reordered passages, inserted repeats, reharmonizations, blanket timing trims, or constructed cadence. Source onset ticks and playback durations are retained; whole-piece tempo is deliberately flattened to 72 quarter notes per minute for this first audition. This is a practical, source-checked game reduction rather than a critical edition, so the immutable scan remains authoritative if a later iteration depends on an omitted inner chord tone, articulation, or engraving detail.
