# Unit 5: Weapon draw order and the steep polearm carry

Owner review of the full-pass art (2026-10-06):

1. **Rear view: weapons behind the body.** "We continue to have the issue of drawing weapons in the front in rear view, so you can see them through his arm." In the rear facing, the main weapon belongs to the far arm, like the offhand. Draw every main-hand weapon (`weapon_r` replacements and the default sword) and the shooting crossbow BEHIND the whole body in the rear facing: z 5, below the rear offhand (6) and the far arm (7). The front facing is unchanged: weapons stay at z 66 under the fist (67).
   - Implement this as a per-facing `z_index` on `weapon_r` replacements in the registry (`"z_index"` on the replace entry; the design owner sets it). The rig applies it to the `weapon_r` sprite and restores the base z on `apply_gear({})`.
   - Change the default sword's rear `z_index` and the rear `crossbow` part in `rear.json` to 5.
   - Check that no clip changes z at runtime.
2. **Steep outward carry for polearms and the bow** (owner chose "steep", option A). Spear, lance, halberd and bow rest leaning steeply OUTWARD: through the fist, head up past the near shoulder, butt down by the foot, never crossing the body. Front weapon axis (−0.30, −0.95); rear (0.30, −0.95). The design owner updates the art and `weapon_grip` landmarks; the clips must read the rest axis from the landmarks (they already do).
   - The fist turns to hold the pole: in the `idle`, `walk`, `block`, `hit`, `death` and rest poses, rotate `hand_r` so the weapon's rest axis matches its landmark direction. Use the new direction minus the sword's rest direction, applied as a hand rotation with the weapon following. Keep the sword, heavy and stab weapons exactly as now.
   - Add the hand rotation through the existing `_separate_grip` split, so the glove turns by 15% and the weapon bone takes the rest, as for the sword.
   - Verify that the registered grip stays within 0.001 px of the fist through idle and walk.
3. **Thrust from the new rest.** `attack_thrust` already lowers the pole to the attack line from its rest axis. Confirm it still reads correctly from the steep rest: lower to level by 0.20, cock, drive, recover to the steep rest by 1.0. Add a test.
4. **Bow from the new rest.** The bow shot raises it from the steep rest to perpendicular-to-aim and back. Add a test.

Proof:
- Extend the suites for rear z 5 on every weapon and the crossbow, the restore on clear, the pole/bow rest axis matching the landmarks in idle and walk, the grip registration, and the unchanged legacy poses for sword, heavy and stab.
- Run the full suite, the PCK build and the export-template run.
- Add to the motion probe: rear idle and walk for the sword, maul, spear and bow, and a front idle for the spear, lance, halberd and bow.
- Native capture is the design owner's: check that the probe parses and give the command.
