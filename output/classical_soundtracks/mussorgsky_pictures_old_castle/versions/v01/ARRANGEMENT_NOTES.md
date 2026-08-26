# Arrangement notes - Pictures at an Exhibition: The Old Castle v01

## Selection and order

- Uses a 32-measure, 6/8 score-derived reduction centered on the opening lament and first broad response shown on source PDF pages 8-9 (printed pages 7-8).
- Measures 1-4 establish the printed low G-sharp drone and ostinato before the troubadour line enters.
- Measures 5-20 state the lament, its lower answer, and the rising response.
- Measures 21-32 restate the recognizable opening contour, compress the later keyboard texture into essential harmony, and cadence on G-sharp minor so the loop can return to the opening drone.
- The rest of the complete piano movement is omitted from this first game-length audition. No source repeats or alternate endings apply to the selected material.

## Transcription and harmony

- The score-specific build script is the transcription source of truth; generated MusicXML/MIDI is never hand-edited.
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
