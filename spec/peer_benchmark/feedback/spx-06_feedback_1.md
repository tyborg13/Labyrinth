# spx-06 feedback 1 (director, 2026-10-21): review of 463c6a0c5

Checkpoint 463c6a0c5 (your r0, committed by the director). The director's native captures show all six pressures
reading on the board. Fix the code review's findings (`/private/tmp/labyrinth_codex/review/spx-06-463c6a0c5.md`):

1. **Blocking: the headwind preview can hide lethal damage.** The forecast runs on the live player-turn state, but
   end-of-turn resolution first expires activation flags (`combat_engine.gd` around 2265). The reviewer's Cinder Trail
   case previews 2 HP left, then the headwind pushes the hero onto Fire and leaves 0. Forecast and resolution must share
   the same pre-pressure end-turn preparation, for every pressure, not only the wind. Add this case as an integration
   regression, plus one more per pressure where the end-turn preparation could change the outcome.
2. **Presentation carries only what is drawn.** `snare_pressure_view.gd` stores `wind_preview.state`, a whole resolver
   state; the native mismatch is `wind_preview.state.analytics`. Project only drawn tiles, displacement paths and
   collision markers into presentation (and into any memo), and make the probe compare that projection.
3. **The surviving mutant.** The wind-specific Sealbinder anchor check is redundant with the forced-movement guard.
   Remove it, and keep a test proving Sealbinders never move under headwind.
4. **Snare-room frame spikes.** The reviewer's real-frame sweep hit 16.1 ms (earth), 21.7 ms (air) and 18.6 ms
   (lightning) whole-frame maxima in Snare fixtures. Measure the same sweep at the base (integration d96eadf4f) and at
   your HEAD. If your change raised them, fix it. If they are pre-existing, report the top costs and stop there.

Proof: the new regressions failing before and passing after; preview equals outcome for all six; the frame table, base
versus HEAD; Snare, Snare UI, Warband, wind-lock, EN02 and EN03 suites. Focused tests only, plus both full suites once
at the end.
