# flow-01 — Automatic next section with a descent transition (owner playtest 9 note 6)

## Header
- Owner: "next section button should be automatic instead of having a button. And should play a cool animation to
  transition from one map to the next".
- Triage §6 (`spec/peer_benchmark/triage_playtest9.md`):
  - After a non-final dragon reward, CONTINUE returns to room mode (`run_scene.gd:15984`).
  - The map then offers "Next section" (`section_map_panel.gd:643`), which plays the ordinary door sequence
    (`run_scene.gd:22107`, `:27318`).
  - Section entry has no authored presentation (`start_room_map_flow.gd:9`).
- boon-01 (opening boons, run_scene overlay host + run-end flow) and map-02 (section map rev 5: generator + node
  layout in section_map_panel.gd) are accepted-pending and will land on `codex/peer-benchmark` while you work; the
  director merges them into your branch. Keep your section_map_panel.gd edits to the onward action only, and your
  run_scene.gd edits to the dragon-reward continue path, to keep conflicts small. Base `codex/peer-benchmark`.
  Owned: the dragon-reward continue path and section change in `scripts/run_scene.gd`, the onward action in
  `scripts/section_map_panel.gd`, `scripts/start_room_map_flow.gd`, a new `scripts/section_transition.gd`, tests, and
  `spec/analytics.md` (additive field).

## Change
1. **Automatic advance.**
   - After a non-final dragon reward, CONTINUE goes straight into the next section through the transition below.
   - The map's "Next section" action and its button state are removed.
   - The final dragon's `COMPLETE ASCENT` is unchanged.
   - Heal, Embers, relic and Moltshard rewards are unchanged and still granted before the reward screen.
2. **Saves.** A save made standing in a cleared boss room whose next section is not yet entered plays the transition
   immediately on load, then continues in the next section's entry room.
3. **Transition** (new `section_transition.gd` overlay; times from CONTINUE):
   - 0.00–0.70 s, descent:
     - The reward screen's existing 0.24 s fade-out runs first.
     - The board camera eases down 140 px (cubic ease-in) while a black overlay fades from 0 to 1 (cubic ease-in).
     - The current music fades out over the same 0.70 s.
   - 0.70–2.60 s, title card:
     - The next section's backdrop painting (`assets/art/backgrounds/sections/<boss_id>.png`, the art the section map
       uses) fills the screen, cover-fit, at full brightness: no map modulate.
     - It fades in from black over 0.50 s with a linear push-in from scale 1.00 to 1.05 across the full 1.90 s,
       centred.
     - A radial vignette darkens the edges to 60% black and the centre to 0%.
   - Text, centred at 1920x1080:
     - Line 1: `SECTION II` (the roman numeral of the section being entered) in the existing small-caps label role,
       22 px, letter-spaced, muted gold. Its centre is at y 470.
     - Line 2: the section title from `Graph.section(...).title`, for example "The Rime Tyrant's Court". It uses the
       display heading role at 64 px, in the parchment text colour, centred at y 540.
     - Both fade in at 0.95 s over 0.45 s while rising 8 px.
     - Section VI shows its title the same way; fog doesn't apply here.
   - 2.60–3.20 s, arrival:
     - Fade to black over 0.30 s.
     - The entry room then appears with the existing room-entry fade, and the next section's music starts as it does
       today.
   - **Skip:** from 0.40 s on, click, A, Enter, Space or Esc jumps to the arrival step. The audio handoff still happens
     once.
   - **Audio:** no new sound cue. The only audio signal is the music handoff. The boss-defeated stinger already
     played at the kill.
   - **Reduced motion:** no camera move and no push-in. Cross-fade to the title card over 0.30 s, hold 1.40 s, fade out
     over 0.30 s.
   - Input during the transition reaches only the skip.
4. **Analytics.** The existing section-entered or room-entered event gets the additive field `entry: "auto_transition"`
   (or `"resume_transition"` after a load). Document it in `spec/analytics.md`.
5. **Demo clip.** Add a `section_transition` clip to `tools/demo_clips` (`staged/demo-01/clips.json` format): kill the
   section I dragon, CONTINUE, the full transition, and two seconds in the section II entry room. Include it in the
   proof commands.

## Proof
- Tests:
  - CONTINUE enters the next entry with no map step;
  - no Next section control remains;
  - the final dragon is unchanged;
  - the load-in-cleared-boss-room path;
  - skip timing;
  - reduced-motion timings;
  - the analytics field;
  - rewards granted once.
- Exact windowed commands for the director:
  - a frame strip at 0.3, 0.9, 1.5, 2.4 and 3.0 s (real renderer, 1920x1080, 100% UI scale);
  - the demo clip.
- Full Godot and Python suites PASS.
