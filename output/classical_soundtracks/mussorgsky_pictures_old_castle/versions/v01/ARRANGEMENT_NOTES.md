# Arrangement notes - Pictures at an Exhibition: The Old Castle v01

## Selection and order

Source coordinates below use the scan's PDF page number, the printed page number, the system counted from the top, and bars counted left-to-right within that system. The edition does not print continuous movement bar numbers.

- Builder measures 1-4 condense PDF 8 (printed page 7), system 1, source bars 1-6. The source has six accompaniment-only introduction bars; v01 keeps its G-sharp drone and ostinato character but shortens the introduction by two bars before the troubadour line enters.
- Builder measures 5-12 reduce the first lament entrance from PDF 8 (printed page 7), system 2, source bars 1-6, continuing through system 3, source bars 1-2. Melodic contour and the bass drone are retained while piano doublings are removed.
- Builder measures 13-20 condense the rising response from PDF 8 (printed page 7), system 3, source bars 3-5, and system 4, source bars 1-5. This is an eight-bar game reduction of that span, not a bar-for-bar copy.
- Builder measures 21-28 are a constructed reprise: measures 21-23 restate builder measures 5-7, while measures 24-28 reshape fragments from PDF 8 (printed page 7), systems 4-5, into a shorter answer over essential source harmony.
- Builder measures 29-32 are a constructed loop close assembled from the lower-answer contour already used in builder measures 11-12 and the tonic/dominant material of PDF 8 (printed page 7), system 5. They are not four consecutive source bars; the final G-sharp-minor cadence is authored so the crossfade can return to builder measure 1.
- Material after PDF 8 (printed page 7), system 5—including the remainder on PDF pages 9-10 (printed pages 8-9)—is omitted from v01. `normalized/full_score.*` and the normalized part therefore represent this selected, reordered 32-measure reduction, not the complete movement.

## Transcription and harmony

- The score-specific build script is the project-authored reduction source of truth; generated MusicXML/MIDI is never hand-edited.
- The melodic contour, G-sharp drone, 6/8 meter, modal minor inflections, tonic/dominant centers, and essential chord tones remain recognizable.
- Dense piano doublings and inner chord tones are reduced to one harmony line plus one ostinato line. This is an explicit pitch-density reduction, not a scholarly note-for-note edition.
- No new functional harmony or transposition is introduced. The audition remains in G-sharp minor; the cello melody is voiced one octave below the source-reduction register and the selective violin echo one octave above it.

## Voice allocation and balance

- `Grave Cello / Troubadour` leads the lament at medium-soft velocity.
- `Veiled Violin / Castle Air` sustains quiet upper chord tones, then takes a selective octave echo during the middle response so upper-string activity remains audible without masking the cello.
- `Ashen Violin / Lute Ostinato` translates the piano's six-eighth ostinato into short, dry bowed pulses.
- `Hollow Viola / Stone Harmony` holds one essential inner chord tone per measure.
- `Undercrypt Bass / G-sharp Drone` retains the low tonic drone and lightly acknowledges each measure's harmonic root.
- Practical melodic density stays at five bowed voices; only the violin echo briefly doubles the cello contour.

## Performance, timbre, and loop treatment

- Tempo is flattened to 72 quarter notes per minute (48 dotted-quarter beats per minute), preserving the `Andante molto cantabile e con dolore` character. The arrangement is 80 seconds structurally and 70 seconds after the overlap is folded into the delivered loop.
- Note gates are deliberately separated on the ostinato and connected on the lament. Dynamics are restrained; cello and bass lead, violin echo remains secondary.
- The canonical `classical_dark_fantasy_v1` bank is used without modification. Track-specific gain, pan, release, vibrato, echo, and reconstruction settings live in `track.json`.
- Percussion is supportive only: a quiet low drum every two measures, muted bone tom every four measures, and ash tick only at four structural cadences.
- A four-measure 10-second equal-power crossfade joins the tonic cadence back into the opening G-sharp drone. Shorter experimental rotations were rejected because the native Vorbis decode exceeded the repository's first/last seam threshold; 10 seconds passes for both Ogg and FLAC while keeping the overlapping phrases in the same G-sharp-minor cadence/drone field.
- v01 is the first audition, so there is no previous version to replace or compare.
