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

Add a strike-samples function per enemy renderer, or one shared helper. It samples the rig's attack clip with its own `sample_pose` and `attack_pose_phase`, from progress, the same way unit 1 does for the hero. It returns tip and inner points in source space, mirrored. Map them to board space with the enemy's draw rect (`_unit_draw_rect_for_center`, `ActorPresentation.floor_anchor`, art_scale). Cache non-empty authored samples per renderer/type, kind, intent/attack variant, facing/mirror and contact boundary. Cache resolved source geometry separately from live board projection.

### 3. Dispatch

- Route every listed enemy melee to `StrikeTrailFx` with the registry kind and the effect's element.
- Dragon physical-area attacks currently draw one slash per target tile. Draw a short `rake` per target tile instead, oriented from the dragon toward each tile. Keep the per-tile depth layering.
- Keep the bespoke effects unchanged: Grave Surgeon saw jab, Veilbound shadow fingers, Cinder Droplet and Cinder Ooze impacts, and the Vyraketh bite.
- Retire the old slash sheet entirely, from the loader, the startup manifest jobs and the effect frames, if nothing else uses it. Remove `MeleeThrustFx` if nothing remains.

## Keep

Enemy clocks, contacts, damage-once and sounds remain unchanged. Reduced motion keeps static, fully revealed claw marks per target tile for dragon physical-area attacks; all other enemy melee draws no strike trail. Bespoke effects keep their existing reduced presentation. Retired slash-gating helpers and their obsolete suite assertions are removed; authored pose/contact timing tests remain.

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

### Third native-review round

- Every enemy streak whose real contact landmark is more than .6 board tile widths from the target body centre instead leads at that centre and points attacker → target. Near contact landmarks keep their previous behavior, lengths and profile.
- Enemy arcs use the exact echo construction, `.33–.56` visual window and `.42` visual peak, scaled by the enemy size floor. Gameplay result/contact clocks are unchanged; the previous push/pull retiming to `.50` made the arc faint at the reviewed `.40/.42` frames.
- Ashen Hooked Sweep is correctly posed, but the reviewed `.40/.42/.48` blade tip spans only 5.45 front / 4.87 rear source px after its `.38` result. Its full windup span hid that held contact. For this area variant, test the actual contact plus the next `.10` of progress; below 24 scaled px, draw the echo-style target arc. The rig animation remains unchanged.
- The frozen static-floor-cache oracle retains its independent cache algorithms while sharing current additive hero/enemy dispatch and dragon physical-area routing. It no longer loads or references slash-sheet assets or `MeleeThrustFx`.


### Peer-review implementation fixes

- Palette/seed changes reuse non-empty pose samples per renderer instance, type, kind, intent/variant, facing/mirror and contact. Iskaldra's talon only uses action/facing, so target distance is excluded from its sampling key. Relative target/size changes refresh resolved source geometry without resampling; framing changes refresh board projection.
- Zero envelopes skip pose sampling/resolution, with the `.36` claw reveal start and canonical arc window. Resolved source samples remain immutable across frames; `Geometry.resolve()` and typed sample conversion run only when that resolution changes.
- Dragon area lights are allocated with their retained front-effect canvases, and their draw time is attributed to `scene_tile_effects`. Reduced physical areas use full, stationary contact marks per tile; all other enemy melee has no reduced trail.
- Attack feedback boundaries share `AttackFxLibrary.feedback_start_progress()`, preserving RunScene's existing dragon-area precedence and all kind/style clocks. The retired slash sheet, unused gating helpers and unread effect flags are removed.

Matched headless benchmark against `3da1cc766`, at 1920×1080: Harrier, Crawler, Warden, Storm Cantor, Ashen area, Zekarion and Iskaldra. Each case uses 24 new palette/seed attacks in one facing, then 128 calls cycling `.40/.42/.48`. Values below are ranges of per-enemy medians in milliseconds; sync measures `_sync_dynamic_render_state(false, false, ["presentation"])`, excluding native draw/GPU cost.

| CPU path | Before | After |
| --- | --- | --- |
| New attack in a reused facing | 2.578–4.155 | .160–.268 |
| Warm `prepare()` | .201–.324 | .152–.263 |
| Retained presentation sync | .232–.354 | .179–.297 |
| Hidden `.20` `prepare()` | .075–.097 | .010–.012 |

Each case went from 24 source builds to one. The first unseen motion/facing still pays its single pose-sampling cost; subsequent palette/seed changes reuse it. A frozen copy of the old helper fails the palette/seed reuse check (two builds where one is expected); the current helper passes.
