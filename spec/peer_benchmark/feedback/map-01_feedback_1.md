# map-01 feedback 1

Director ran `tests/section_map_probe.gd` natively: revision 4 renders (4 lanes, no fog in I–V, fog kept in VI).
Captures: output/peer-benchmark-2026-10-12/proof/map-01/. Decisions and ownership:

1. **Ownership granted** to update the Guardian tests/suites (single-Guardian assertions + the suite summary) and the
   Graftwright checks for revision 4: multiple Guardian nodes per section (≤ 1 per route), Graftwright eligibility
   counts mystery-combat rooms as fights. Keep the legacy assertions for revision ≤ 3 fixtures. The full suite must
   pass.
2. **Mystery tooltip** (panel label functions now in scope): name "Unknown room"; normal state line; once scouted:
   name "Unknown room · <Type name>" (e.g. "Unknown room · Event", "Unknown room · Standard combat").
3. **Mystery door emblem**: a physical door leading to a mystery room shows the Unknown-room emblem; when scouted, the
   scouted type's emblem. (Door adapter in scope.)
4. **Section VI landmarks** (fog kept): the treasure row, the Hearth row, every Guardian node and the boss are
   landmarks visible through the fog.
5. **Section VI Scout**: targets are the legacy ones (outlined, unrevealed, reachable rooms); scouting a mystery there
   reveals its hidden type like in I–V.
6. **Depth bands**: as even as possible with the remainder going to LATER bands (S−1 = 9 → 3/3/3; 10 → 3/3/4;
   11 → 3/4/4), then your capacity repair moves overflowing steps later. Update the spec wording to match.
7. **Probe**: "Scout highlights unknown rooms rather than travel choices" fails — in revision 4 Scout targets are
   unentered reachable mystery rooms; fix the probe (or the behaviour if it highlights something else) so it asserts
   that, and make the probe's manual advances resolve mystery rooms.
8. **Presentation tweaks** (section_map_panel/node): (a) deterministic node jitter for revision 4 (not entry/boss):
   x ±16 px, y ±12 px from a hash of the room coord, applied after lane/step placement; (b) revealed future rooms
   (not visited, not currently available) draw their medallion icon at 85% opacity instead of today's muted level, so
   room types are scannable; available/current/visited styles unchanged.
Rerun: section_map v2 suite, section_map suite, dragon_boss suite, guardian suites, graftwright suite, full suite.
The director reruns the native probe.
