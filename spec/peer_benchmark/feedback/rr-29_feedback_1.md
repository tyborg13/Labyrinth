# rr-29 feedback 1 (director)

Good first pass: the re-cut at 0 px, the tear gates on all 724 frames, and the `block` frames 9–41 draw-order fix. Your
four open questions are decided below. The owner's second note on the hair also changed two inputs.

1. **New inputs (owner, 2026-10-20: the front hair "looks situated too far back").**
   - Integration now carries:
     - the round-2 front raw, `staged/mq11/paint/hollow_mimic_front_mq11_raw.png` (hair forward around the face);
     - its prompt, `staged/paintovers/hollow_mimic_front_mq11b.md`;
     - its exact references, `staged/mq11/paint/refs_hollow_mimic_front_mq11b/`;
     - the matching maquette data with native acceptance **director_08**.
   - The director merged integration into your branch.
   - The director_08 delivery, the native captures without the .blend, is at
     `tests/mq11_proof/director_08/hollow_mimic/capture/` in your worktree.
   - Re-cut the front from these. The rear raw is unchanged, still round 1 r2.
   - Rest stays at 0 px against both paintings.
2. **`TODO_DESIGN_pendulum_travel`.**
   - The director raised the swing in `staged/rr-29/motion_tracks.json`: `upper_deg` near **16**, far **14**, and the `envelope` in item 3.
   - The 2.5× travel gate stays. Report the new travel.
3. **`TODO_DESIGN_pendulum_terminal_lag`.**
   - New data field: `arm_swing.envelope = {"ramp_fraction": 0.12, "ease": "smoothstep"}`.
   - The swing amplitude and the forearm lag ramp in over the first 12% of the clip and out over the last 12%, so both
     arms start and end exactly at rest.
   - Gate: frame 0 and the last frame equal the rest pose.
4. **`TODO_DESIGN_mq11_prompt_source`.**
   - Follow the Thrall precedent (`maquettes/arc_thrall/prompt_front_r2_fix.md`).
   - Add byte-identical copies of the staged prompts to `spec/art_identity/maquettes/hollow_mimic/`:
     `prompt_front_mq11b.md`, `prompt_rear_mq11.md`, `prompt_rear_mq11_r2.md`.
   - Point each job's `prompt_source` at them. You're authorized to add these three files.
5. **`TODO_DESIGN_mq11_rear_residue`.** The two green-tinted texels are key residue, not paint.
   - Recolour each to the mean of its non-green-dominant 4-neighbours as a recorded post-step in the rear job.
   - Report the before and after values. Then the residue gate must pass with no exception.
6. **Historical pins.** The rr-20 and rr-28 assertions that pin old Mimic production data get the int-04/int-05
   treatment:
   - each checks its own unit's commit range;
   - today's tree is not pinned.
   - Don't weaken their own-range checks.
7. Focused tests, then both full suites once. List the director's windowed commands.
