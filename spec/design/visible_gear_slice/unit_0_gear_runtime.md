# Unit 0: Gear visual runtime

## Header

- Read first: [README](README.md), `spec/protagonist_cutout_runtime.md`, `.codex/skills/create-labyrinth-cutout/references/motion-and-integration.md` (production integration section).
- Target mockup: `mockups/standin_loadouts.png`. The stand-in art is deliberately crude; final art will replace it at the same paths and sizes. Judge placement, layering and visibility rules, not paint.
- Baseline: `baseline/combat_board.png`, `baseline/character_gear.png`.
- Data you consume (authored by the design owner, do not redesign): `assets/units/protagonist_cutout/gear_visuals.json` and the PNGs under `assets/units/protagonist_cutout/gear/` (`keep` imports already written).
- Code involved: `scripts/protagonist_cutout/rig.gd`, `scripts/protagonist_cutout/renderer.gd`, `scripts/combat_board_view.gd` (protagonist renderer, illusion renderers, player shadow/HUD anchor texture), `scripts/run_scene.gd` (`_build_equipment_portrait_panel`, `_equipped_equipment_for_board`), `scripts/asset_loader.gd`.
- Do not touch `scripts/protagonist_cutout/motion.gd`, `scripts/attack_fx_library.gd`, `run_scene.gd` `_protagonist_attack_motion`, or `experiments/`. Unit 1 and Unit 2 own those.

## Change

1. **Registry loader**: new `scripts/protagonist_cutout/gear_visuals.gd` (`extends RefCounted`, static API, JSON parsed once and cached). It validates the schema at load and reports errors with `push_error`; a broken entry falls back to the slot default and never crashes the run. API (names are the contract Unit 2 will call):
   - `resolve(equipped: Dictionary) -> Dictionary`: slot -> item id for the five slots. An equipped item absent from the registry resolves to `slot_defaults[slot]`. A slot that is missing or empty in `equipped` resolves to the slot default for `weapon`, `armor` and `boots` (the body always has these) and to `""` (nothing drawn) for `offhand` and `trinket`.
   - `signature(equipped) -> String`: stable string of the resolved loadout.
   - `weapon_motion(equipped) -> String`: the resolved weapon's `motion` (`"sword"` default).
   - `is_two_handed(equipped) -> bool`: resolved weapon `hands == 2`.
   - `offhand_kind(equipped) -> String`: `"shield"`, `"hand"` or `""`. It is `""` when the weapon is two-handed.
   - `ops_for_facing(equipped, facing) -> Dictionary`: `{replace: Array, attach: Array, weapon_grip: Dictionary}` in source coordinates, with the offhand omitted when two-handed. `weapon_grip` is `{}` unless the weapon entry declares one (Unit 2 will add `weapon_grip` landmarks; just pass them through).
2. **Rig gear layer** (`rig.gd`). Add `apply_gear(ops: Dictionary)`. It is opt-in: enemy rigs that extend this script never call it, and their loading and pose paths must be byte-for-byte unchanged in behaviour.
   - On load, remember each replaceable node's base texture and base position: Sprite2D parts by part name, Polygon2D meshes by their `replaces_part`.
   - `apply_gear` first restores every base texture/position and frees previous gear attachments, then applies `replace` entries. A rigid Sprite2D takes the new texture and, if given, the new `offset` (converted to bone-local exactly as `load_rig` does). A Polygon2D mesh takes only the texture. A mesh replacement whose PNG size differs from the base texture is an error: log it and keep the base texture.
   - Add `attach` entries as Sprite2D children of the named Bone2D: `centered = false`, position = `offset - joint_position(bone)`, global `z_index`, `z_as_relative = false`, nearest filtering, `set_meta("gear_attachment", item_id)`, plus the entry's `hide_in_clips` list as metadata.
   - Calling `apply_gear({})` restores the bare rig exactly.
   - Visibility rules, applied every time a pose is applied (`apply_pose(clip, phase)` and the reaction path in `cutout_reaction_playback.gd`): an attachment whose `hide_in_clips` contains the current clip is hidden while that clip shows the crossbow, i.e. exactly while the `weapon_l` bone is visible. All other attachments, including shields during `cast`, `shoot`, `block`, `hit`, walking and reduced-motion stills, stay visible. `death` keeps them visible.
3. **Renderer** (`renderer.gd`):
   - `set_gear(equipped: Dictionary)`: no-op when `GearVisuals.signature` is unchanged. Otherwise apply `ops_for_facing` to both facing rigs, re-render once (`UPDATE_ONCE`), and invalidate the rest texture. Store the signature; add `"gear"` (the signature) and `"offhand_visible"` to `snapshot()`.
   - `weapon_motion() -> String` and `offhand_kind() -> String` for the current gear (Unit 2 will use them).
   - `rest_texture() -> Texture2D`: the front, unmirrored, neutral rest pose with current gear, in the same 255×255 registration as `REST_PATH`. Bake it with one GPU readback per gear signature (cache by signature), never per frame. Until the first bake completes, return the static `REST_PATH` texture.
4. **Default look**: the starting loadout now draws the Splintered Shield and the Cracked Lantern. The bare layout's `rest_source` PNGs and their digests stay as they are (they describe the gearless rig). Commit one additional static PNG, `assets/units/protagonist_cutout/front/front_default_gear_rest.png` (`keep` import), produced by baking the default loadout through the real renderer, for the default loadout's shadow/HUD/Character-screen texture. Cover it with the existing precomputed unit-shadow cache, so the starting hero keeps the cached shadow path.
5. **Board wiring** (`combat_board_view.gd`):
   - When `presentation.equipped_equipment` changes (and on roster refresh), call `set_gear` on the protagonist renderer and on every illusion and illusion-preview renderer. Create new illusion renderers with the current gear before their first `present`. Illusions are echoes of the hero and wear his gear.
   - The player's shadow and HUD anchor texture (`_unit_hud_anchor_texture`, `_unit_textures["player"]` consumers) use the renderer's `rest_texture()`. A gear change therefore updates the shadow silhouette, using the existing exact extraction path for non-default loadouts (a one-time cost per gear change). Never read the live viewport per frame. Keep the cached path for the default loadout.
6. **Character screen** (`run_scene.gd` `_build_equipment_portrait_panel`): call `set_gear` with `_run_state.equipped_equipment` before the first `present`. The placeholder texture shown before the cutout's first frame is the gear rest texture (or the default-gear PNG). Equipping or unequipping from the pack updates the figure.
7. **Every other `ProtagonistCutout` instance** (grep the project): give it the run's gear.
8. **Draw order**: use the registry `z_index` values. Front parrying dagger (`z_index` 48 on `hand_l`): the left fist must draw over its grip and the dagger must not draw over the left sleeve. If equal-z ordering against the `arm_l` mesh makes that ambiguous, resolve it with node order and prove it in a zoomed capture; do not change the registry numbers.
9. **Packaging**: `gear_visuals.json` sits in `assets/units/protagonist_cutout/` (already matched by the export include filter). Verify gear PNGs and the JSON load in a production-only PCK with the unmodified export runtime, extending the existing protagonist export smoke check if there is one.
10. **Spec**: add a short "Visible equipment" section to `spec/protagonist_cutout_runtime.md` describing the registry, the fallback rules, the API above and the rest-texture rule.

## Keep

- All existing protagonist motion, timing, facing and reflection, illusion ownership, reduced-motion behaviour, save/resume, analytics, rules text and input paths.
- Enemy cutout rigs and renderers unchanged.
- Existing pose regression tests (idle/walk/attack/cast/shoot transforms) must pass unmodified: gear adds no bone motion.
- No per-frame viewport readback, and no per-frame allocation in the gear path.
- Windows typed-array rule (AGENTS.md).

## Proof

- New focused suite `tests/suites/protagonist_gear_suite.gd` (with the repo's usual runner entry) covering:
  - every registry file exists and loads; every mesh replacement matches its base size;
  - resolve/fallback rules, including an out-of-slice item and empty offhand/trinket;
  - `apply_gear({})` after any loadout restores every base texture and position exactly;
  - two-handed hides the offhand;
  - a held offhand is hidden exactly while `weapon_l` is visible in `shoot` and visible in `cast`;
  - shields are visible in `cast`, `shoot`, `block` and `hit`;
  - `set_gear` with an unchanged signature does not re-render;
  - `rest_texture` bakes once per signature;
  - an enemy rig loads identically.
- Run the protagonist cutout suites, the illusion suite, the shadow-cache and performance tests the board already has, and the full Godot suite. Report exact result lines.
- New real-renderer probe `tests/protagonist_gear_probe.gd` at 1920×1080 (SubViewport capture) through `tools/visual_probe_runner.py`. Loadouts:
  - **L0** default (sword, splintered shield, patched cloak, skirmisher boots, lantern).
  - **L1** war_maul + ward_kite + undertaker_plate + ironshod_sabatons + crown_of_thorns. The kite is equipped but hidden by the two-hander.
  - **L2** sawtooth_knife + parrying_dagger + cinderweave_mail + emberstriders + war_dancer_sash.
  - **L3** training_sword + ward_kite + patched_cloak + skirmisher_boots + war_dancer_sash.
  - **L4** out-of-slice items (grave_greatsword, tower_shield, quarrymail, worldroot_greaves, bone_dice): must look like L0.

  Captures:
  - For each loadout, the combat board with the hero idle (front), and a rear-facing frame (a walk toward northeast, or a non-idle clip presented with a northeast direction).
  - L0 and L2 in a `shoot` frame at phase 0.42 (crossbow visible; the parrying dagger hidden for L2, the shield visible for L0) and in a `cast` frame at 0.42.
  - L0 in `block` at 0.25.
  - L2 with an active illusion on the board.
  - The Character screen Gear tab for L1 and L2.
  - L1 in reduced motion.

  Name the files so the loadout and state are obvious. Also write a 3× nearest-neighbour crop of the hero region next to each board capture.
- An inspection fixture command set for the handoff (just report the commands; the design owner will verify):
  - a `character` room with every slice item in `--equipment-inventory`;
  - three `combat` fixtures using `--equip` for L0, L1 and L2.
