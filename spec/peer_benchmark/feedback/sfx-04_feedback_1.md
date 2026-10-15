# sfx-04 feedback 1 (director)

Keep everything you did (trigger alignment, no serialization, priority drop/steal, leading-silence trims). Do not commit.

## Root cause of the owner's blink complaint (found by the director)
The blink trigger is on time, but the sample is the problem: `move.blink_01.ogg` is 2.08 s long with a slow swell — it
first reaches −6 dB of its peak at 692 ms and peaks at 981 ms — while the blink visual lasts 6 × 0.04 s = 0.24 s. The
sound's body arrives after the blink is over. Leading-silence trimming cannot catch this; the audit must measure the
**perceived onset and peak**, not just the first sample above −45 dBFS. Many cues share the problem (time to −6 dB of
peak, director measurement with a 5 ms envelope): surface.ice 481 ms, spell.ice 457, surface.rubble 387, move.blink 322
(early window), vocal.beast 314, spell.air 298, illusion.spawn 257, radiance.light 228, cast.arcane 183, death.spirit
182, deck.shuffle 179, death.avian 169, status.shock 154, spell.shadow 148, shop.sell 140, hit.claw 139, heal 134,
event.choose 132.

## Rule (director decision)
1. For every cue × call site, the audit records: the sample's peak time (max of a 5 ms RMS envelope) and its perceived
   onset (first time the envelope reaches −6 dB of that peak), and the visual's **climax** time after the trigger: the
   impact/hit frame for hits and statuses, the vanish→arrive switch for blinks/teleports (for `move.blink`: the frame
   the hero disappears from the origin), the burst/contact frame for spells and casts, the death pop for deaths, the
   input response for UI.
2. **Peak alignment:** where the sample's peak comes later than the visual climax (plus 30 ms), rebuild the cue through
   `tools/sfx_lab` with its head trimmed so that the trimmed sample's peak lands within 0–30 ms after the climax; keep
   at least 15 ms of the pre-peak build-up (no clipped transient), apply a 3 ms fade-in, keep the tail. Record the trim
   in the build provenance as sfx-04.
3. **Perceived-onset caps** where no climax applies or after alignment: impacts, hits, blocks, status applications,
   deaths and UI ≤ 40 ms from trigger; movement, blinks, casts and spells ≤ 60 ms. Trim heads the same way to meet the cap.
4. Loops and ambient beds are exempt; one-shot `surface.*` cues are not (their visual is the surface appearing).
5. Do not change levels: after trimming, re-measure loudness with the sfx-03 100 ms short-window measure and keep each
   cue within ±0.5 LU of its current value (adjust gain only to restore the previous loudness).
6. Add the peak/onset columns to `sync_audit.md`, a regression test asserting the caps and the peak alignment for every
   cue × call site, and extend the listening checklist with every cue changed by this rule (cue, old onset/peak →
   new, visual climax).
7. Update the unowned `tests/sfx_cue_coverage_probe.gd` expectations for the stagger/wing timing you changed (you now
   own it), keeping its intent.

Proof: the sync harness, onset/peak tests, sound-lab tests, SFX bank, threats_at_rest, full suite.
