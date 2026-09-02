# Arrangement Notes

## Intent and scope

This is a faithful first proof of concept for restrained tactical-battle music. It uses the complete Movement II, including all written repeats and alternate endings. It does not create a gameplay loop, rewrite the form, reharmonize Schubert, add percussion, or introduce a new countermelody.

The arrangement is approximately 13:03 and uses five monophonic musical voices at most.

## Transformations

### 1. Movement extraction and repeat realization

The script locates the `II. / Andante con moto` heading in the unchanged OpenScore file and stops before `III. / Scherzo`. The normalized MusicXML preserves the 180 notated measure objects and all four original staves. MIDI playback expands repeats and alternate endings to 300 performed measures.

### 2. Steady tactical tempo

`faithful_retro.mid` uses a single tempo of quarter note = 92. This is close to the OpenScore file's initial playback tempo of 94, but removes its unprinted variation-by-variation playback tempo changes. The steady pace is intended to remain mournful and thoughtful without losing forward motion during tactical decision-making.

The normalized MIDI is separate and retains the OpenScore playback tempo events for source traceability.

### 3. Four original lines become four bounded retro voices

Each original staff maps directly to one arranged MIDI track:

| Original part | Arranged voice | GM fallback program | Selection rule for notated double-stops/chords |
| --- | --- | --- | --- |
| Violin I | Pulse I | Lead 1 (Square) | Highest pitch |
| Violin II | Pulse II | Lead 1 (Square) | Highest pitch |
| Viola | Triangle | Ocarina fallback | Lowest pitch |
| Cello | Low Triangle | Synth Bass 1 fallback | Lowest pitch |

The selection rule is the main density reduction. Single notes remain at their original pitches and times. When a staff contains a chord, double-stop, or simultaneous divisi voices, one pitch is retained so that each staff stays monophonic. The upper selection in the violins protects melodic identity; the lower selection in viola and cello protects the harmonic foundation. No surviving source pitch is transposed.

The normalized MusicXML and MIDI preserve every original pitch separately; this reduction applies only to `faithful_retro.mid`.

### 4. Cello-weighted fifth voice

The only added musical voice is `Sub-Bass Shadow / Cello -8ve`. It exactly doubles eligible cello notes one octave below, omitting transpositions below MIDI note 28 to avoid unusable subsonic mud. It adds no new pitch class or rhythm. Verification compares every bass-shadow onset to the source-derived cello track.

The main cello voice also receives a small velocity emphasis and the strongest track-volume setting. The shadow is deliberately quieter, so the result reads as depth rather than a new bass line.

### 5. Restrained dynamics and articulation

Printed dynamics are mapped into a compressed MIDI-velocity range. The normal range is approximately 38-78, with modest accent bumps and a five-point cello emphasis. This keeps the large formal variations perceptible without producing symphonic or arcade-style jumps.

Staccato, staccatissimo, detached-legato, and tenuto markings change note gates. Other notes use a short release gap for pulse clarity. Source crescendos and diminuendos are represented primarily through their surrounding dynamic marks rather than continuous MIDI expression ramps.

### 6. Timbre and stereo layout

The MIDI program changes are portable General MIDI fallback hints, not a claim that every MIDI player will sound the same. The provided preview is the reference timbre:

- Violin I: softened limited-harmonic pulse, slightly right
- Violin II: darker narrow pulse/triangle blend, slightly left
- Viola: triangle, near center-right
- Cello: triangle/sine blend, near center-left
- Cello shadow: sine-dominant sub voice, centered

There is no drum track, noise percussion, bright arpeggiator, pitch-bend vibrato, or tempo humanization. The dry, economical texture is intentional.

### 7. Sample-free preview render

The renderer generates its waveforms mathematically at 44.1 kHz stereo and applies short per-note attack/release envelopes plus gentle master saturation. It loads no samples, SoundFont, recorded impulse response, or third-party performance. The compact Ogg Vorbis preview and lossless FLAC reference come from the same generated PCM.

## What was deliberately not changed

- pitches of retained source notes
- harmony or key progression
- thematic order
- variation order
- repeat structure
- counterpoint between the four source staves
- meter
- full-movement form

## Known limitations

- Chord and double-stop reduction necessarily drops some inner or doubled pitches in the arranged MIDI. The normalized files retain them for later versions.
- General MIDI playback will vary by device; audition the Ogg or FLAC preview for the intended procedural timbre.
- The full movement is not edited into a seamless game loop. A later version should choose a form-aware loop or adaptive entry/exit points rather than cutting blindly.
- The source carries one unmatched dashed-direction warning. It does not affect note data or the rendered arrangement.

## Possible second-version directions

1. **Sparse tactical loop:** Build a 4-6 minute form from the theme and the darker sustained variations, with a quieter pulse bed and carefully authored seamless loop points.
2. **More authentically sampled SNES palette:** Keep this five-voice orchestration but render it through a specifically cleared or commissioned low-memory instrument bank, adding restrained console-style echo.
3. **Cello-led threat version:** Give the cello and sub voice more foreground presence, thin the two pulse voices during planning passages, and reserve denser upper counterpoint for enemy-pressure peaks.
