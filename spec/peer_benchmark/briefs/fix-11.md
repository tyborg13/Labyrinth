# fix-11 — The last vague no-action labels, and a reason hold that survives a stall (fb-01 follow-ups)

## Header
- fb-01 (merged 7c817a86a) made enemies say why they didn't act, and retired "Cancelled" in `intent_callouts.gd`.
  The owner asked for this ("sometimes they're just out of range … we just need to make sure it's all very obvious"),
  and remembered the word as "interrupted". Three gaps are left; fb-01's handoff
  (`tests/fb_01_implementation.md`, "Open issues / other no-action paths") lists the first.
  1. **Tether**: the Arc Thrall's Tether still says **"Cancelled"**. It shows as the intent row on the board
     (`tether_view.gd` `cancelled_rows`) and as the action banner during playback (`tether_view.gd` `animate`,
     `tether.gd` `animation_step` `label`).
  2. **Guardians**: a guardian whose committed footprint has no live tile left shows **"Interrupted"**
     (`guardian_combat_rules.gd` ~420, `interrupted` when `live_tiles` is empty). This happens when the guardian was
     displaced and every footprint tile is now in a wall, off the grid or out of line of sight. Nothing in the game
     interrupts anything, so the word is wrong.
  3. **Clock**: `IntentCallouts.play` times the 0.8 s hold on the wall clock from the call (`Time.get_ticks_usec()`,
     ~241). A frame stall at the first callout (a shader compile, a busy machine) can use up the hold before it is
     drawn. fix-08 (merged 63be03c6c) fixed the same bug in `contextual_combat_prompt.gd`.
- Base `codex/peer-benchmark`. Risk tier: standard. Owned:
  - `scripts/enemy_mechanics/tether.gd`, `scripts/enemy_mechanics/tether_view.gd`;
  - `scripts/guardian_combat_rules.gd` (the interrupted label and step only);
  - `scripts/enemy_no_action_reason.gd`, `scripts/intent_callouts.gd`;
  - the step decoration and playback lines in `scripts/run_scene.gd` that fb-01 added (~24454, ~33480), additive only;
  - `spec/analytics.md` (new reason values);
  - tests.

## Change
1. **Tether reasons, from the resolver.** When the Tether's plan is cancelled, `tether.gd` decides the reason from
   the plan's own geometry, after its align move, and puts `no_action_reason` on the step:

   | Case | `no_action_reason` | Text |
   |---|---|---|
   | No living partner Thrall | `no_partner` | No partner |
   | A partner lives, but none shares a row or column | `not_aligned` | Not in line |
   | In line, but farther than `max_length` | `out_of_range` | Out of range |
   | In line and in range, but a wall or terrain sits between | `no_line_of_sight` | No line of sight |

   - Several partners: use the reason for the nearest partner by Manhattan distance, then the lowest id (the order
     `choose` already sorts by).
   - Shock is already its own status reason (fb-01). An attack disabled by Shock keeps `shocked` and gets no second
     reason. A Thrall that dies before acting shows nothing.
   - Add `no_partner` and `not_aligned` to `REASON_TEXT`, with no icon. The other two reuse fb-01's entries.
2. **Tether presentation.**
   - Intent row: `cancelled_rows` shows the reason's text token in place of "Cancelled", from the same reason function
     (one function, so the row and the playback can never disagree).
   - Playback: no "Cancelled" banner. The reason plays as fb-01's callout over the Thrall: 0.8 s opaque, real time,
     and the next actor waits. A Thrall that moves to align and still can't fire shows the reason after the move.
   - The string "Cancelled" no longer appears in any player-facing path. Add a test that searches the scripts for it.
3. **Guardian footprint.** When `live_tiles` is empty (the old `interrupted`), the step carries
   `no_action_reason: "no_line_of_sight"` and plays fb-01's "No line of sight" callout with its hold. "Interrupted"
   is retired as a label.
   - Keep the internal `interrupted` field if other code reads it. Only the player-facing label and the playback
     change.
   - "Summon blocked" and "Snuff · spawn blocked" stay as they are.
4. **A stall-proof hold.** `IntentCallouts.play` counts the hold from the callout's first drawn frame, on capped
   unscaled frame time, as fix-08 does (`MAX_PRESENTATION_DELTA_SECONDS = 0.1`, an `ignore_time_scale` timer, or
   fix-08's equivalent). At a steady 60 fps, the timing is unchanged: the same 0.8 s hold and 0.3 s fade, the same
   frame for the next actor. Under a stall, the callout shows for its full hold once drawn. The Redirected callout
   gets the same clock.
5. **Analytics.** The two new values go into `enemy_action_resolved.no_action_reason` (additive) and
   `spec/analytics.md`.

## Keep
- fb-01's text, icons, layout above the board HUD and Umbra privacy.
- The Tether's rules, the align move and its beam visuals. Guardian rules and footprints.
- The Windows `Array[T]` rule: typed helpers, never bare literals for typed assignments.

## Proof
- Engine tests, one per Tether reason, from a constructed state: the right reason, the intent row token and the
  playback callout text. Add one case that moves to align and still fails, and one where Shock disables the attack.
- A guardian test: a displaced guardian with an empty footprint gives `no_line_of_sight` and no "Interrupted".
- Clock tests: one that fails on today's code (a long first frame skips most of the hold) and passes after; one at a
  steady 60 fps with the same end frame as today.
- The UI identity lint passes.
- Real renderer, 1920×1080: one capture each of "No partner" and "Not in line" mid-hold, plus the windowed command.
  The director judges them.
- Focused only; the director runs the full suites at merge.

## Out of scope
- New statuses or rules. Hero-side messages. Fire/Bleed deaths, unmet surface requirements, and the other paths
  fb-01 listed: report any you can name, but don't change them.
