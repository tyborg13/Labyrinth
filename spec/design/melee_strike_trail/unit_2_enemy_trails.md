# Unit 2: Enemy strike trails

This unit starts after unit 1 has landed on this branch. Read `README.md` and unit 1's module (`scripts/strike_trail_fx.gd`) first.

## Background (code map)

**Enemy melee step payloads** are built in `scripts/combat_engine.gd` (about 3615–3668) and carry `from`, `to`, `actor_key` and `element`. Per-type motion entries (`<type>_motion` with `phase`, `contact`, `direction`) are set in `run_scene.gd` `_render_board_state`. Each renderer's `attack_pose_phase(progress, contact)` maps contact 0.42 to its own authored contact pose.

**Effects that currently use the old slash sprite:**
- **Raw:** the 13 guardians' `strike`; Chainbound Gaoler Cudgel Press; Iskaldra Rime Talon; Lightning Wisp Spark Dart; Acolyte `dust_advance` and Frostglass `spear_advance` (whole-sprite lunge); enemy push/pull at distance 1.
- **Gated by a rig's `attack_trail_phase`:** Crawler, Warden, Noctyrax Void Claw, Zekarion claw (from its `strike` socket), Tharokh and Vaeloryx melee.
- **Per target tile, as dragon physical areas:** Tharokh Worldspine Claw, Vaeloryx Razor Dive and similar.
- **Separate effect:** the Harrier uses `MeleeThrustFx.draw_streak`.

**Landmarks found in the rigs:**
- Harrier and Frostglass: `weapon_tip`.
- Warden: `mace_grip` only.
- Gaoler: `chain_tip`.
- Crawler: `contacts.claw_near` / `claw_far`.
- Dragons: claw joints, plus a Zekarion `strike` landmark.
- Guardians: `blade` (Ashen Reaver); `spear` (Bell Tender, Storm Cantor); `hand_near` / `hand_far`; wing joints.
- Lightning Wisp: none.

Every enemy rig extends the protagonist rig and has a static `sample_pose`.

## Change

### 1. A small strike registry

Add a table, for example `data/strike_trails.json` or a const in a new `scripts/enemy_strike_points.gd`. Per enemy type it records:
- the trail kind;
- the strike landmark: a bone plus a source-space point, using an existing landmark where one exists;
- the inner reference (toward the hand or grip);
- the strike window in effect progress, from the rig's own contact mapping;
- which intents or actions use it.

Defaults by type:

| Kind | Enemy types |
| --- | --- |
| `streak` | Harrier, Frostglass Lancer, Bell Tender, Storm Cantor (spears) |
| `sweep` | Ashen Reaver (blade); Warden (mace; add a `mace_head` landmark from the mace sprite's far end); Gaoler (`chain_tip`, whip-like reach) |
| `rake` | Crawler; Noctyrax, Zekarion, Tharokh, Vaeloryx, Iskaldra (claws); clawed or winged guardians |
| `arc` | Lightning Wisp; Acolyte and Frostglass whole-sprite lunges; enemy push/pull; any type with no cutout attack clip |

For guardians without an obvious weapon, pick `rake` or `sweep` per creature from its art. Record the choice and the reason.

### 2. Enemy strike samples

Add a strike-samples function per enemy renderer, or one shared helper. It samples the rig's attack clip with its own `sample_pose` and `attack_pose_phase`, from progress, the same way unit 1 does for the hero. It returns tip and inner points in source space, mirrored. Map them to board space with the enemy's draw rect (`_unit_draw_rect_for_center`, `ActorPresentation.floor_anchor`, art_scale). Cache per effect.

### 3. Dispatch

- Route every listed enemy melee to `StrikeTrailFx` with the registry kind and the effect's element.
- Dragon physical-area attacks currently draw one slash per target tile. Draw a short `rake` per target tile instead, oriented from the dragon toward each tile. Keep the per-tile depth layering.
- Keep the bespoke effects unchanged: Grave Surgeon saw jab, Veilbound shadow fingers, Cinder Droplet and Cinder Ooze impacts, and the Vyraketh bite.
- Retire the old slash sheet entirely, from the loader, the startup manifest jobs and the effect frames, if nothing else uses it. Remove `MeleeThrustFx` if nothing remains.

## Keep

Enemy clocks, contacts, damage-once, sounds and reduced motion (no trail), plus the enemy `attack_trail_phase` tests. Update those tests where they asserted the old slash gating, keeping the timing intent.

## Proof

- **Unit tests:** registry coverage, so every enemy type that has a melee intent resolves to a kind; strike samples at contact for each kind, front and rear; dragon area rakes per tile.
- **Probe:** native 1920×1080 captures at progress 0.40, 0.42 and 0.48 for Harrier, Crawler, Warden, Gaoler, one guardian of each kind, Zekarion claw, a dragon area claw, Lightning Wisp and an enemy push. The design owner runs the captures.
- **Suites and benchmark:** the full Godot suite, the enemy cutout suites, and the render performance benchmark.

## Native-review fix decisions

- Single-target rakes are three contact claw marks: 46 source px long, 3.6 wide at the middle, tapered to zero at both ends, spaced 8 px apart. The middle is 15% longer. Reveal clips the fixed slashes over effect progress .36–.44; the normal trail envelope holds and fades them. Glow is 3× width at .35 centre alpha. The approved dragon per-tile area rake keeps its existing profile.
- Enemy light dimensions use the hero's board source-pixel scale multiplied by `clamp(art_scale, .9, 1.6)`. Real rig points keep their draw-rect projection; inner reach, light widths, lengths, arcs, sparks and glints use the clamped scale.
- A window's maximum pairwise strike-point distance below 24 scaled source px enables the fallback. Sweeps become the approved 44 px arc, translated so its contact point remains the real strike landmark. Streaks aim from that contact point toward the target body. Claw marks centre on the contact landmark and use the claw's incoming contact tangent, or attacker → target for a short path.
- Enemy weapon axes are accepted only within 50° of attacker → target. Other streaks use contact → target body. Gaoler's Cudgel Press uses `hand_fist` and a 48 px punch streak.
- The review's old Gaoler chain fixture spans 4.47 source px and triggers the fallback. The replacement fist actually spans 87.17 front / 70.38 rear; Ashen's authored blade spans 157.70 front / 115.90 rear. These real attacks exceed the threshold and retain their authored paths. Tests also cover an Ashen held-contact fixture to reproduce a stationary displayed landmark without forcing a false fallback on its moving attack.
- The native probe supplies the gameplay motion dictionaries (including Crawler's attack variant) and cutout routing flags, asserts the displayed clip/phase, and keeps each cutout viewport updating through three settling frames so skinning cannot leave the initial rest texture in the sheet.
