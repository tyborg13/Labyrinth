# Unit 5b: restore the original top-right HUD buttons

**Owner feedback:** the top-right HUD buttons (section map, character, grimoire and menu) overflow their new medallion rings and looked better before. Restore them exactly as on `master`, together with the level and embers readout beside them. That means `StatsLabel` with its original "LV n  EMBERS n" text, styling and behaviour, and the original buttons' size, styling, icons, notification dot, tooltips and hotkeys.

**Keep from unit 5 (approved):**
- relic, rite and Defiance sockets in the relic bar, with inspect-only behaviour, charge badges and READY/SPENT status rings;
- the Intents plate;
- the dialogue-input fix.

**Implementation:**
- Revert the presentation code for those top-bar nodes in `scripts/run_scene.gd` and `scenes/run_scene.tscn` to master's version.
- Delete `scripts/combat_hud_stats.gd` if nothing else uses it.
- Keep `scripts/combat_hud_socket.gd` only if the relic, rite or Defiance sockets still use it; otherwise delete it.
- Restore master's tests and assertions for these buttons and the stats label.
- Remove the unit 5 test expectations that cover the top-bar sockets.
- Update `tests/combat_hud_sockets_test.gd` and `tests/combat_hud_sockets_probe.gd` so they cover only what remains: relics, rites, Defiance, Intents and the dialogue input.

**Proof:**
- Fresh 1920×1080 captures of normal combat, boss combat with relics, keyboard and controller focus on a top-right button, and the notification dot.
- The top-right cluster must be visually identical to master. Compare against a master capture of the same probe state.
- Full suite green.
