# Arrangement notes - The Old Castle main-menu v05

## Menu-specific form

- v05 adds a four-measure, 8.571-second title-screen entrance before the existing loop. The intro begins with a quiet G-sharp/D-sharp veil, introduces a distant low drum in its third measure, and lets the pulse emerge in its fourth.
- The intro cello quotes the first two notes of `Castle Air` with their exact relative rhythm one octave lower. It previews rather than replaces the source melody.
- After the intro, the uninterrupted v04 selection of printed measures 7-68 begins unchanged at 84 QPM.
- The combined `arrangement.mid` and `preview.ogg` are taste-audition files. `loop.mid` preserves the separable structural loop for eventual intro-once/loop-many game playback.

## Exact melody preservation

- All five v04 source-derived loop tracks retain the same event count, onset, gate, pitch, velocity, and assignment. In the combined audition they are shifted later by exactly four measures and are otherwise event-for-event identical.
- No high-string embellishment track returns. No source melody note is removed, reharmonized, shortened, or replaced.
- The five normalized source-derived parts remain separate and unchanged; arrangement-added veil and percussion are documented independently.

## Phrase-aware funeral pulse

- The loop is divided at source-derived melodic returns, sustained arrivals, and rests: printed measures 7-18, 19-28, 29-37, 38-46, 47-50, 51-60, and 61-68.
- Each phrase opens with the familiar four-hit 6/8 pattern. Interior measures retain the bar-line war drum and second-dotted-beat tom but alternate a single ash tick between the two beat groups.
- The measure before each cadence restores both ash ticks; the cadence measure keeps only a softer low drum, allowing the strings and veil to breathe.
- The result uses 186 loop percussion events rather than v04's 248. The important low drum remains present in every measure, so the pulse is shaped rather than simply weakened.

## Umbra veil

- `Umbra Veil / G-sharp-D-sharp Breath` adds fourteen low, long events: one G-sharp2 pedal spanning each of the seven source-derived phrases and one quieter D-sharp3 entering later in each phrase.
- These are the established tonic and dominant pedal tones of the source material; they add no new pitch class or countermelody.
- The veil reuses the canonical procedural `undercrypt_bass` sample at low gain, near-center pan, 1.6-second attack and release, and restrained slow vibrato. A track-local attack setting extends the renderer's existing deterministic envelope without changing the canonical bank or any previous config's default sound.

## Delivery state

- v01-v04 remain byte-for-byte unchanged.
- v05 is an unapproved taste audition. It is not promoted or wired to the main menu.
- Per the requested workflow, strict loop-seam polishing, final hash freeze, commit, and peer review follow only after musical approval.
