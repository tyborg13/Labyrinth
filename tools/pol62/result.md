# pol-62 verification

Release and the starting task HEAD were both `92ed73479e58c97aa091300579eeef6f0039e59c`. The release run happened before production edits. The final headless dry-run exercised both release-equivalent and patched behavior through the same probe. [Original release log](/private/tmp/labyrinth_codex/pol-62/release.log) · [Final dry-run log](/private/tmp/labyrinth_codex/pol-62/native-dry-run.log)

## 1. Opening line aim — live tie, fixed

Release already picked the line orientation with the most damaging hits. In seed 84, Volt Surge, Molten Reach and Thunderline all had two hits on either axis. The closest horizontal hit was two tiles away and the closest vertical hit was one tile away. Release opened east and the patched chooser opened south through the card click signal, number key and controller A paths. Seed 83 already opened vertically for each of those cards, with two vertical hits and one horizontal hit.

The opening chooser compares legal placements using the current resolver and the tile distance from the hero to the closest struck enemy footprint. It counts each enemy once. If hit count and distance tie, the authored opening direction stays first, followed by east, south, west and north. A no-enemy fixture kept the default east in both runs. Centered three-tile patterns put the same tiles on the board for the two directions along one axis.

Push chooses a direction for an already-selected target from the closest tile of that target's footprint. It takes the larger axis offset, uses the axis with more free travel for an exact diagonal, and takes horizontal when travel also ties. The Push chooser requires a selected target and therefore has no opening line to score. Line aim uses the specified hits, proximity and existing direction order, with proximity measured to the closest struck footprint tile. Cleaver Sweep, Grave Cleave, Tombsplitter, Flame Jet and Spear Thrust take their direction from the selected target tile and have no separate opening rotation. [Line chooser](../../scripts/line_opening_aim.gd) · [Push chooser](../../scripts/combat_engine.gd#L7320) · [Facing-derived aim](../../scripts/combat_engine.gd#L9033)

The frame numbers below are the selection input frames in the final dry-run. The probe reads the opening direction five process frames after selection. When three frames are listed, the inputs are pointer, keyboard and controller in that order. The other cards use the pointer path. Every row matched the direction in all listed input paths.

| Card | 83 release | 83 patched | 84 release | 84 patched |
| --- | --- | --- | --- | --- |
| Volt Surge | South (15/30/40) | South (15/30/40) | East (271/286/296) | South (271/286/296) |
| Molten Reach | South (50/60/70) | South (50/60/70) | East (306/316/326) | South (306/316/326) |
| Thunderline | South (80/95/105) | South (80/95/105) | East (336/351/361) | South (336/351/361) |
| Rime Shard | North (115) | North (115) | South (371) | South (371) |
| Shatterline | South (125) | South (125) | East (381) | South (381) |
| Glacier Pin | North (135) | North (135) | South (391) | South (391) |
| Windlass Volley | South (145) | South (145) | East (401) | South (401) |
| Fan of Knives | South (155) | South (155) | East (411) | South (411) |
| Wind Shear | South (165) | South (165) | East (421) | South (421) |
| Meteorfall | South (175) | South (175) | East (431) | South (431) |
| Spark Focus | East (185) | East (185) | East (441) | East (441) |
| Hoarfrost Shell | East (195) | East (195) | East (451) | East (451) |
| Borrowed Spark | East (205) | East (205) | East (461) | East (461) |
| Cinder Wall | East (215) | East (215) | East (471) | East (471) |
| Frost Lane | East (225) | East (225) | East (481) | East (481) |
| Lamp Oil | East (235) | East (235) | East (491) | East (491) |
| Earthen Rampart | East (245) | East (245) | East (501) | East (501) |

## 2. Crate and prop damage preview — stale on release

Volt Surge swept across a Tunnel Crawler plus a wooden crate and then a Tunnel Crawler plus a wooden box in seed 84. Both previews shared the same appearance and clearing frames in the forecast data and in the retained HUD paint plan. The probe observed 41 samples per transition at a 60 FPS cap. Pointer motion there enters the live board GUI handler, keyboard rotation uses the arrow keys, and controller rotation uses the bumpers after board focus is set through the live navigation handler.

| Prop | Input | Enter / leave input frame, release and patched | Enemy appearance / clear, frames since input | Prop appearance / clear, frames since input |
| --- | --- | --- | --- | --- |
| Wooden crate | Pointer | 521 / 562 | +1 / +1 | +1 / +1 |
| Wooden box | Pointer | 618 / 659 | +1 / +1 | +1 / +1 |
| Wooden crate | Keyboard | 715 / 756 | +0 / +0 | +0 / +0 |
| Wooden box | Keyboard | 812 / 853 | +0 / +0 | +0 / +0 |
| Wooden crate | Controller | 909 / 950 | +0 / +0 | +0 / +0 |
| Wooden box | Controller | 1006 / 1047 | +0 / +0 | +0 / +0 |

On release, changes in the shared damage preview map queue HUD redraw and invalidate changed terrain tiles in the same submission. Pointer motion coalesces into one deferred presentation update for both previews. Release also contains `338a61962`, which wired the terrain damage band into the HUD pulse clock. The historical 0.6 s delay did not reproduce, so its original cause is unverified. [Damage preview invalidation](../../scripts/combat_board_view.gd#L4259) · [Terrain HUD band](../../scripts/board_layer_slices.gd#L199)

## 3. Deck names — live, fixed

The five reported rows were 190 px wide in the release pre-battle and Character decks. Release tried 15, 14 and 13 px, then reset overflowing labels to 15 px. All five now fit at 12 px with the same row and label widths. Crimson Draught reproduced with a ×2 badge. At one copy it already fit at 14 px. The new fallback uses the same typography helper as the existing sizes. R6 counts stayed at zero in both strip scripts.

| Name | Width at 13 px | Width at 12 px | Inner width | Before font | After font |
| --- | ---: | ---: | ---: | ---: | ---: |
| Rite of the Mountain | 132 | 123 | 124 | 15 | 12 |
| Shattered Reflection | 134 | 123 | 124 | 15 | 12 |
| Cinderweave Guard | 127 | 117 | 124 | 15 | 12 |
| Lodestone Reversal | 125 | 115 | 124 | 15 | 12 |
| Crimson Draught ×2 | 111 | 102 | 109 | 15 | 12 |

The full table below uses the live label's font. It includes all 309 card data IDs, including items and resolved legacy aliases. The 309 names produce 927 before and after comparisons across the three badge configurations. Unbadged labels all fit at 12 px.

Badge text widths vary with the digits. The real font gives 108–109 px of name space for counts ×2–×9 and 99–104 px for counts ×10–×99. Each row below adds to the names from the wider rows. [Badge widths](/private/tmp/labyrinth_codex/pol-62/badge-widths.log)

| Inner width | Names that start trimming at this width |
| ---: | --- |
| 109 | Bone-Ward Charm (111 px), Cinderweave Guard (117 px), Gathering Rhythm (111 px), Lodestone Reversal (115 px), Rite of the Mountain (123 px), Shattered Reflection (123 px), Witchglass Double (110 px) |
| 108 | Salamander Heart (109 px) |
| 104 | Cinderline Tempo (105 px), Skybreak Current (106 px), Thorn Crown Pact (107 px), Undertaker Stand (107 px) |
| 103 | None added |
| 102 | Earthen Rampart (103 px), Rite of the Storm (103 px), Stormstring Shot (103 px) |
| 101 | Crimson Draught (102 px), Rite of Hoarfrost (102 px), Rite of Tailwinds (102 px), Stonewall Stance (102 px) |
| 100 | Warded Advance (101 px), Worldroot Stride (101 px) |
| 99 | Eye of the Storm (100 px), Firebrand Volley (100 px), Glassbone Guard (100 px), Overhead Smash (100 px), Reflected Threat (100 px), Undertow Guard (100 px) |

## Checks and proof

- `POL62 before: PASS (0 failed checks)` and `POL62 after: PASS (0 failed checks)`. The dry-run printed each of the 15 PNG paths per phase. [Final dry-run log](/private/tmp/labyrinth_codex/pol-62/native-dry-run.log)
- `DECK WIDTH COMPARISON: 309 names, 927 row/count checks, 0 differences from contract`. [Before TSV](/private/tmp/labyrinth_codex/pol-62/before-widths.tsv) · [After TSV](/private/tmp/labyrinth_codex/pol-62/after-widths.tsv)
- `MAIN DOMAIN ASSERTIONS full_scene_interaction_program: 5590`, `MAIN DOMAIN ASSERTIONS full_scene_controls_program: 216` and `MAIN DOMAIN ASSERTIONS full_scene_clock_program: 2184`. Each finished with `TEST RESULT: PASS`. [Focused aim results](/private/tmp/labyrinth_codex/pol-62/aim-focused-final.json)
- Pre-battle view, pre-battle semantics, Magic Deck and Magic Deck Input each finished with `TEST RESULT: PASS`. [Focused deck results](/private/tmp/labyrinth_codex/pol-62/focused.json)
- UI identity `Ran 25 tests in 6.222s`, `OK`. Rules text `Ran 3 tests in 0.054s`, `OK`, `PASS: Rules text lint (455 existing hits)`. [UI identity](/private/tmp/labyrinth_codex/pol-62/ui-identity.log) · [Rules text](/private/tmp/labyrinth_codex/pol-62/rules-text.log)
- `TYPED ARRAY AUDIT (pol-62): 4 scripts; 0 review candidates`. [Typed arrays](/private/tmp/labyrinth_codex/pol-62/typed-arrays.log)
- Python default selection `SELECTED MODULES: 21 of 57`, `Ran 192 tests in 28.558s`, `OK`. The optional timing cache write reported `[Errno 1] Operation not permitted` under read-only Git metadata. [Python default log](/private/tmp/labyrinth_codex/pol-62/python-default-final.log)

## Proof for the design owner

The two fixtures were generated and independently reloaded successfully. Both start in real combat on the player turn. The native launcher sets `LABYRINTH_CEL_LOOK=all`, renders an exact 1920×1080 SubViewport at 100% UI scale, and runs the proof contract on each phase. The installed cel pack reported `CEL_STATUS current`. The `before` phase enables a debug-only switch in the two changed paths.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-62 && /private/tmp/labyrinth_codex/pol-62/native.sh --fixtures
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-62 && /private/tmp/labyrinth_codex/pol-62/native.sh native
```

The first command recreates both manifests with `tools/inspection_fixture.py`. The second runs both renderer phases. Each phase saves `aim_83_{volt_surge,thunderline}.png`, `aim_84_{volt_surge,thunderline}.png`, `crate_{on,off}_{00,02,04,06,08}.png` and `deck.png` under `/private/tmp/labyrinth_codex/pol-62/before/` or `/private/tmp/labyrinth_codex/pol-62/after/`. It writes `before-manifest.json` and `after-manifest.json` beside those folders. The sandbox verified the headless dry-run and printed the output paths. The native PNGs and their visual inspection remain open. [Aim fixture](/private/tmp/labyrinth_codex/pol-62/aim.json) · [Crate and deck fixture](/private/tmp/labyrinth_codex/pol-62/crate.json) · [Capture contract](proof_contract.json)

### Chosen defaults

- Seed 83 starts the hero at `(3,5)` and two Tunnel Crawlers at `(3,2)` and `(3,3)`. Seed 84 starts the hero at `(5,5)` and crawlers at `(3,6)`, `(4,6)`, `(6,5)` and `(6,6)`, with the crate at `(5,6)` and box at `(3,4)`. Both retain their seeded room layouts.
- Aim capture centers are `(3,3)` and `(6,5)`. Preview sweep centers are `(4,6)` for the crate and `(3,5)` for the box. The pointer leaves to `(5,5)`. The deck fixture includes two Crimson Draught copies.
- The probe caps at 60 FPS and settles for 16 initial frames and five selection frames. It samples frames 0–40 after each preview input and captures frames 0–8 at two-frame intervals. The visual runner has a 120-second total cap and 20-second startup cap.
- Name measurement used rows with one, two and ten copies to sample the count badge widths.

### Design placeholders

None. Remaining 12 px trims with count badges are listed above for the owner's decision.

## Full deck width table

Widths are in pixels at 100% UI scale. Each label column shows the font size before → after. The 190 px row leaves 124 px for one copy, 109 px for ×2 and 102 px for ×10.

| Name | ID | 13 px | 12 px | Single (124 px) | ×2 (109 px) | ×10 (102 px) |
| --- | --- | ---: | ---: | --- | --- | --- |
| Anchor Slam | `anchor_slam` | 84 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Arc Flash | `arc_flash` | 61 | 56 | 15 → 15 | 15 → 15 | 15 → 15 |
| Backhand Nick | `backhand_nick` | 97 | 89 | 15 → 15 | 14 → 14 | 13 → 13 |
| Backhand Nick | `ember_jab` | 97 | 89 | 15 → 15 | 14 → 14 | 13 → 13 |
| Ball Lightning | `ball_lightning` | 91 | 84 | 15 → 15 | 15 → 15 | 14 → 14 |
| Barbed Mail | `barbed_mail` | 76 | 70 | 15 → 15 | 15 → 15 | 15 → 15 |
| Basalt Guard | `basalt_guard` | 83 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Beacon | `beacon` | 46 | 43 | 15 → 15 | 15 → 15 | 15 → 15 |
| Bitter Tonic | `bitter_tonic` | 76 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Blade Dance | `blade_dance` | 79 | 73 | 15 → 15 | 15 → 15 | 15 → 15 |
| Blessed Salve | `blessed_salve` | 86 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Blinding Bash | `blinding_bash` | 89 | 83 | 15 → 15 | 15 → 15 | 14 → 14 |
| Blood Price | `blood_price` | 72 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Bloody Lunge | `bloody_lunge` | 87 | 79 | 15 → 15 | 15 → 15 | 15 → 15 |
| Bone-Ward Charm | `bone_ward_charm` | 120 | 111 | 13 → 13 | 15 → 12 | 15 → 12 |
| Borrowed Spark | `borrowed_spark` | 104 | 96 | 15 → 15 | 13 → 13 | 15 → 12 |
| Bottled Gale | `bottled_gale` | 79 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Brace | `brace` | 36 | 34 | 15 → 15 | 15 → 15 | 15 → 15 |
| Brace the Spear | `brace_the_spear` | 100 | 94 | 15 → 15 | 14 → 14 | 13 → 13 |
| Break the Veil | `break_the_veil` | 91 | 85 | 15 → 15 | 15 → 15 | 14 → 14 |
| Bristle | `bristle` | 43 | 40 | 15 → 15 | 15 → 15 | 15 → 15 |
| Buffet | `buffet` | 42 | 38 | 15 → 15 | 15 → 15 | 15 → 15 |
| Butcher Chop | `butcher_chop` | 86 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Caltrops | `caltrops` | 54 | 50 | 15 → 15 | 15 → 15 | 15 → 15 |
| Capacitor | `capacitor` | 62 | 57 | 15 → 15 | 15 → 15 | 15 → 15 |
| Catch the Wind | `catch_the_wind` | 99 | 92 | 15 → 15 | 14 → 14 | 13 → 13 |
| Censer Swing | `censer_swing` | 87 | 81 | 15 → 15 | 15 → 15 | 15 → 15 |
| Chain Bolt | `chain_bolt` | 66 | 62 | 15 → 15 | 15 → 15 | 15 → 15 |
| Chain Catch | `chain_catch` | 77 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Chain Lock | `chain_lock` | 70 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Changing Winds | `changing_winds` | 106 | 98 | 15 → 15 | 13 → 13 | 15 → 12 |
| Charged Orb | `charged_orb` | 81 | 75 | 15 → 15 | 15 → 15 | 15 → 15 |
| Cinch Straps | `rallying_breath` | 82 | 76 | 15 → 15 | 15 → 15 | 15 → 15 |
| Cinder Bloom | `cinder_bloom` | 87 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Cinder Fusillade | `cinder_fusillade` | 105 | 97 | 15 → 15 | 13 → 13 | 15 → 12 |
| Cinder Patch | `cinder_patch` | 83 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Cinder Second | `cinder_second` | 92 | 86 | 15 → 15 | 15 → 15 | 14 → 14 |
| Cinder Trail | `cinder_trail` | 77 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Cinder Wall | `cinder_wall` | 76 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Cinderline Tempo | `cinderline_tempo` | 114 | 105 | 14 → 14 | 15 → 12 | 15 → 12 |
| Cinderweave Guard | `cinderweave_guard` | 127 | 117 | 15 → 12 | 15 → 12 | 15 → 12 |
| Cleaver Hack | `cleaver_hook` | 84 | 78 | 15 → 15 | 15 → 15 | 15 → 15 |
| Cleaver Sweep | `needle_flurry` | 93 | 86 | 15 → 15 | 15 → 15 | 14 → 14 |
| Clockwork Mark | `clockwork_mark` | 105 | 97 | 15 → 15 | 13 → 13 | 15 → 12 |
| Cloudstep Loop | `cloudstep_loop` | 98 | 90 | 15 → 15 | 14 → 14 | 13 → 13 |
| Coffin Brace | `grave_sprint` | 81 | 75 | 15 → 15 | 15 → 15 | 15 → 15 |
| Cold Grasp | `cold_grasp` | 69 | 64 | 15 → 15 | 15 → 15 | 15 → 15 |
| Cold Shoulder | `cold_shoulder` | 90 | 83 | 15 → 15 | 15 → 15 | 14 → 14 |
| Couched Lance | `couched_lance` | 96 | 89 | 15 → 15 | 14 → 14 | 13 → 13 |
| Crack the Whip | `crack_the_whip` | 99 | 92 | 15 → 15 | 14 → 14 | 13 → 13 |
| Crank Reload | `crank_reload` | 86 | 79 | 15 → 15 | 15 → 15 | 15 → 15 |
| Crimson Draught | `crimson_draught` | 111 | 102 | 14 → 14 | 15 → 12 | 15 → 12 |
| Crosswind | `crosswind` | 68 | 63 | 15 → 15 | 15 → 15 | 15 → 15 |
| Crushing Blow | `crushing_blow` | 94 | 86 | 15 → 15 | 15 → 15 | 14 → 14 |
| Crystal Mantle | `crystal_mantle` | 94 | 87 | 15 → 15 | 15 → 15 | 14 → 14 |
| Cyclone Seal | `cyclone_seal` | 80 | 75 | 15 → 15 | 15 → 15 | 15 → 15 |
| Dawnstep | `dawnstep` | 64 | 59 | 15 → 15 | 15 → 15 | 15 → 15 |
| Daybreak | `daybreak` | 62 | 57 | 15 → 15 | 15 → 15 | 15 → 15 |
| Dazzle | `dazzle` | 42 | 39 | 15 → 15 | 15 → 15 | 15 → 15 |
| Deflect | `deflect` | 46 | 43 | 15 → 15 | 15 → 15 | 15 → 15 |
| Discharge | `discharge` | 65 | 60 | 15 → 15 | 15 → 15 | 15 → 15 |
| Doppelganger | `doppelganger` | 90 | 83 | 15 → 15 | 15 → 15 | 14 → 14 |
| Dull Bolt | `dull_bolt` | 55 | 51 | 15 → 15 | 15 → 15 | 15 → 15 |
| Dust Devil | `dust_devil` | 66 | 61 | 15 → 15 | 15 → 15 | 15 → 15 |
| Dust Glide | `dust_glide` | 67 | 62 | 15 → 15 | 15 → 15 | 15 → 15 |
| Dust Skip | `dust_skip` | 62 | 57 | 15 → 15 | 15 → 15 | 15 → 15 |
| Earthen Rampart | `earthen_rampart` | 112 | 103 | 14 → 14 | 15 → 12 | 15 → 12 |
| Ember Guard | `ember_guard` | 85 | 79 | 15 → 15 | 15 → 15 | 15 → 15 |
| Ember Tithe | `ember_tithe` | 79 | 73 | 15 → 15 | 15 → 15 | 15 → 15 |
| Ember Ward | `ember_ward` | 81 | 75 | 15 → 15 | 15 → 15 | 15 → 15 |
| Empty Husk | `empty_husk` | 79 | 73 | 15 → 15 | 15 → 15 | 15 → 15 |
| Eye of the Storm | `eye_of_the_storm` | 107 | 100 | 15 → 15 | 13 → 13 | 15 → 12 |
| Fan of Knives | `fan_of_knives` | 88 | 82 | 15 → 15 | 15 → 15 | 15 → 15 |
| Fan the Flames | `fan_the_flames` | 97 | 90 | 15 → 15 | 14 → 14 | 13 → 13 |
| Far Draw | `far_draw` | 59 | 55 | 15 → 15 | 15 → 15 | 15 → 15 |
| Fault Strike | `fault_strike` | 76 | 70 | 15 → 15 | 15 → 15 | 15 → 15 |
| Field Suture | `field_suture` | 78 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Firebrand Volley | `firebrand_volley` | 108 | 100 | 14 → 14 | 13 → 13 | 15 → 12 |
| Flame Jet | `flame_jet` | 60 | 55 | 15 → 15 | 15 → 15 | 15 → 15 |
| Flash Powder | `flash_powder` | 87 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Flashsteam | `flashsteam` | 74 | 68 | 15 → 15 | 15 → 15 | 15 → 15 |
| Flowing Step | `flowing_step` | 83 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Forked Nock | `forked_nock` | 81 | 74 | 15 → 15 | 15 → 15 | 15 → 15 |
| Frost Circuit | `frost_circuit` | 81 | 75 | 15 → 15 | 15 → 15 | 15 → 15 |
| Frost Heave | `frost_heave` | 77 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Frost Lane | `frost_lane` | 68 | 62 | 15 → 15 | 15 → 15 | 15 → 15 |
| Frost Nova | `frost_nova` | 70 | 64 | 15 → 15 | 15 → 15 | 15 → 15 |
| Frost Snare | `frost_snare` | 75 | 69 | 15 → 15 | 15 → 15 | 15 → 15 |
| Frostbolt | `frostbolt` | 59 | 54 | 15 → 15 | 15 → 15 | 15 → 15 |
| Frozen Bite | `frozen_bite` | 73 | 68 | 15 → 15 | 15 → 15 | 15 → 15 |
| Gale Ward | `gale_ward` | 67 | 62 | 15 → 15 | 15 → 15 | 15 → 15 |
| Galvanize | `galvanize` | 63 | 58 | 15 → 15 | 15 → 15 | 15 → 15 |
| Gathering Rhythm | `gathering_rhythm` | 120 | 111 | 13 → 13 | 15 → 12 | 15 → 12 |
| Geode | `geode` | 39 | 36 | 15 → 15 | 15 → 15 | 15 → 15 |
| Glacier Pin | `glacier_pin` | 70 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Glacier Salts | `glacier_salts` | 81 | 75 | 15 → 15 | 15 → 15 | 15 → 15 |
| Glass Mending | `last_light` | 93 | 87 | 15 → 15 | 15 → 15 | 14 → 14 |
| Glassbone Guard | `glassbone_guard` | 109 | 100 | 14 → 14 | 13 → 13 | 15 → 12 |
| Glide | `glide` | 33 | 31 | 15 → 15 | 15 → 15 | 15 → 15 |
| Glowstone Ward | `glowstone_ward` | 107 | 99 | 15 → 15 | 13 → 13 | 15 → 12 |
| Grapple | `grapple` | 51 | 47 | 15 → 15 | 15 → 15 | 15 → 15 |
| Grave Cleave | `grave_cleave` | 83 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Grave Mortar | `grave_mortar` | 86 | 79 | 15 → 15 | 15 → 15 | 15 → 15 |
| Gravewind Gate | `shadow_gate` | 104 | 95 | 15 → 15 | 13 → 13 | 15 → 12 |
| Gravewind Step | `gravewind_step` | 103 | 94 | 15 → 15 | 13 → 13 | 15 → 12 |
| Grounding | `grounding` | 69 | 64 | 15 → 15 | 15 → 15 | 15 → 15 |
| Guarded Step | `guarded_step` | 87 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Guiding Flare | `guiding_flare` | 87 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Gust Step | `gust_step` | 62 | 57 | 15 → 15 | 15 → 15 | 15 → 15 |
| Haft Shove | `haft_shove` | 71 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Hall of Mirrors | `hall_of_mirrors` | 95 | 88 | 15 → 15 | 14 → 14 | 14 → 14 |
| Hallowed Strike | `hallowed_strike` | 104 | 95 | 15 → 15 | 13 → 13 | 15 → 12 |
| Headlong | `headlong` | 61 | 57 | 15 → 15 | 15 → 15 | 15 → 15 |
| Headsman's Toll | `headsmans_toll` | 107 | 98 | 15 → 15 | 13 → 13 | 15 → 12 |
| Hearth Rush | `hearth_rush` | 81 | 75 | 15 → 15 | 15 → 15 | 15 → 15 |
| Heel Stomp | `heel_hook` | 74 | 68 | 15 → 15 | 15 → 15 | 15 → 15 |
| Hoarfrost Shell | `hoarfrost_shell` | 99 | 92 | 15 → 15 | 14 → 14 | 13 → 13 |
| Hoarfrost Wall | `hoarfrost_wall` | 97 | 90 | 15 → 15 | 14 → 14 | 13 → 13 |
| Hoarfrost Ward | `hoarfrost_ward` | 103 | 95 | 15 → 15 | 13 → 13 | 15 → 12 |
| Hobnail Drive | `hobnail_drive` | 88 | 82 | 15 → 15 | 15 → 15 | 15 → 15 |
| Hook and Hold | `hook_and_hold` | 94 | 87 | 15 → 15 | 15 → 15 | 14 → 14 |
| Hookspine Reap | `hookspine_reap` | 103 | 95 | 15 → 15 | 13 → 13 | 15 → 12 |
| Hotfoot | `hotfoot` | 50 | 46 | 15 → 15 | 15 → 15 | 15 → 15 |
| Hourglass Sand | `hourglass_sand` | 100 | 93 | 15 → 15 | 14 → 14 | 13 → 13 |
| Hurl Spear | `hurl_spear` | 69 | 64 | 15 → 15 | 15 → 15 | 15 → 15 |
| Hurricane Palm | `hurricane_palm` | 102 | 94 | 15 → 15 | 13 → 13 | 13 → 13 |
| Hush of Winter | `hush_of_winter` | 100 | 92 | 15 → 15 | 14 → 14 | 13 → 13 |
| Ice Sculpture | `ice_sculpture` | 85 | 78 | 15 → 15 | 15 → 15 | 15 → 15 |
| Icebound Chains | `icebound_chains` | 106 | 99 | 15 → 15 | 13 → 13 | 15 → 12 |
| Icicle Lance | `icicle_lance` | 75 | 70 | 15 → 15 | 15 → 15 | 15 → 15 |
| Immolation | `immolation` | 76 | 70 | 15 → 15 | 15 → 15 | 15 → 15 |
| Incense Haze | `incense_haze` | 85 | 78 | 15 → 15 | 15 → 15 | 15 → 15 |
| Inferno Ritual | `inferno_ritual` | 91 | 84 | 15 → 15 | 15 → 15 | 14 → 14 |
| Iron Wheel | `iron_wheel` | 71 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Jaw Trap | `jaw_trap` | 58 | 53 | 15 → 15 | 15 → 15 | 15 → 15 |
| Jolt | `jolt` | 22 | 20 | 15 → 15 | 15 → 15 | 15 → 15 |
| Joust | `joust` | 33 | 30 | 15 → 15 | 15 → 15 | 15 → 15 |
| Kept Breath | `kept_breath` | 77 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Kestrel Dive | `kestrel_dive` | 79 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Kindle | `kindle` | 42 | 39 | 15 → 15 | 15 → 15 | 15 → 15 |
| Kite Bash | `kite_bash` | 61 | 57 | 15 → 15 | 15 → 15 | 15 → 15 |
| Lamp Oil | `lamp_oil` | 57 | 53 | 15 → 15 | 15 → 15 | 15 → 15 |
| Lantern Rain | `cinderburst` | 84 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Lantern Rain | `ember_rain` | 84 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Lantern Shot | `lantern_shot` | 84 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Lash | `lash` | 30 | 28 | 15 → 15 | 15 → 15 | 15 → 15 |
| Leather Roll | `leather_roll` | 78 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Loaded Toss | `loaded_toss` | 78 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Locket Chill | `locket_chill` | 76 | 69 | 15 → 15 | 15 → 15 | 15 → 15 |
| Lodestone Reversal | `lodestone_reversal` | 125 | 115 | 15 → 12 | 15 → 12 | 15 → 12 |
| Low Sweep | `hamstring_shot` | 71 | 65 | 15 → 15 | 15 → 15 | 15 → 15 |
| Magma Vent | `magma_vent` | 81 | 75 | 15 → 15 | 15 → 15 | 15 → 15 |
| Main-Gauche | `main_gauche` | 86 | 79 | 15 → 15 | 15 → 15 | 15 → 15 |
| Meteorfall | `meteorfall` | 67 | 62 | 15 → 15 | 15 → 15 | 15 → 15 |
| Mirror Charm | `mirror_charm` | 89 | 82 | 15 → 15 | 15 → 15 | 14 → 14 |
| Mirror Feint | `mirror_feint` | 78 | 73 | 15 → 15 | 15 → 15 | 15 → 15 |
| Mirror Flash | `mirror_flash` | 80 | 74 | 15 → 15 | 15 → 15 | 15 → 15 |
| Mirror Image | `mirror_image` | 85 | 79 | 15 → 15 | 15 → 15 | 15 → 15 |
| Molten Reach | `molten_reach` | 86 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Mossglass Elixir | `mossglass_elixir` | 103 | 95 | 15 → 15 | 13 → 13 | 15 → 12 |
| Nail Parry | `nail_parry` | 66 | 61 | 15 → 15 | 15 → 15 | 15 → 15 |
| Needle Thrust | `bodkin_arrow` | 91 | 84 | 15 → 15 | 15 → 15 | 14 → 14 |
| Overclock | `overclock` | 64 | 59 | 15 → 15 | 15 → 15 | 15 → 15 |
| Overhead Smash | `overhead_smash` | 108 | 100 | 14 → 14 | 13 → 13 | 15 → 12 |
| Pale Spark | `bone_dart` | 68 | 63 | 15 → 15 | 15 → 15 | 15 → 15 |
| Pale Spark | `pale_spark` | 68 | 63 | 15 → 15 | 15 → 15 | 15 → 15 |
| Palm Blade | `palm_blade` | 72 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Palm Strike | `palm_strike` | 76 | 69 | 15 → 15 | 15 → 15 | 15 → 15 |
| Parry Rhythm | `battle_rhythm` | 91 | 85 | 15 → 15 | 15 → 15 | 14 → 14 |
| Patch Up | `patch_up` | 58 | 53 | 15 → 15 | 15 → 15 | 15 → 15 |
| Petrify | `petrify` | 45 | 42 | 15 → 15 | 15 → 15 | 15 → 15 |
| Phoenix Cleave | `phoenix_cleave` | 97 | 90 | 15 → 15 | 14 → 14 | 13 → 13 |
| Pinning Quarrel | `pinning_quarrel` | 106 | 97 | 15 → 15 | 13 → 13 | 15 → 12 |
| Pitch Firebomb | `pitch_firebomb` | 98 | 90 | 15 → 15 | 14 → 14 | 13 → 13 |
| Plant Pavise | `plant_pavise` | 79 | 73 | 15 → 15 | 15 → 15 | 15 → 15 |
| Plasma Arc | `plasma_arc` | 73 | 67 | 15 → 15 | 15 → 15 | 15 → 15 |
| Polar Guard | `polar_guard` | 77 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Powder Keg | `powder_keg` | 77 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Prism Sight | `prism_sight` | 75 | 69 | 15 → 15 | 15 → 15 | 15 → 15 |
| Pyroclasm | `pyroclasm` | 68 | 63 | 15 → 15 | 15 → 15 | 15 → 15 |
| Quarry Claw | `venom_claw` | 83 | 76 | 15 → 15 | 15 → 15 | 15 → 15 |
| Quarry Dust | `grave_dust_satchel` | 81 | 75 | 15 → 15 | 15 → 15 | 15 → 15 |
| Quarry Plating | `quarry_plating` | 98 | 90 | 15 → 15 | 14 → 14 | 13 → 13 |
| Quarry Step | `quarry_step` | 80 | 73 | 15 → 15 | 15 → 15 | 15 → 15 |
| Quick Stab | `quick_stab` | 71 | 65 | 15 → 15 | 15 → 15 | 15 → 15 |
| Raise Stone | `raise_stone` | 75 | 69 | 15 → 15 | 15 → 15 | 15 → 15 |
| Raise the Anvil | `raise_the_anvil` | 97 | 90 | 15 → 15 | 14 → 14 | 13 → 13 |
| Razor Gale | `razor_gale` | 69 | 63 | 15 → 15 | 15 → 15 | 15 → 15 |
| Reflected Threat | `reflected_threat` | 108 | 100 | 14 → 14 | 13 → 13 | 15 → 12 |
| Refraction | `refraction` | 69 | 64 | 15 → 15 | 15 → 15 | 15 → 15 |
| Rekindle Edge | `rekindle_edge` | 91 | 83 | 15 → 15 | 15 → 15 | 14 → 14 |
| Reprise | `reprise` | 49 | 45 | 15 → 15 | 15 → 15 | 15 → 15 |
| Revealing Glare | `revealing_glare` | 101 | 94 | 15 → 15 | 14 → 14 | 13 → 13 |
| Ricochet Knife | `ricochet_knife` | 95 | 88 | 15 → 15 | 15 → 15 | 14 → 14 |
| Rime Hack | `rime_hack` | 69 | 64 | 15 → 15 | 15 → 15 | 15 → 15 |
| Rime Shard | `rime_shard` | 75 | 70 | 15 → 15 | 15 → 15 | 15 → 15 |
| Rime Step | `rime_step` | 65 | 60 | 15 → 15 | 15 → 15 | 15 → 15 |
| Rimefang | `rimefang` | 63 | 58 | 15 → 15 | 15 → 15 | 15 → 15 |
| Rimeplate Lock | `rimeplate_lock` | 99 | 92 | 15 → 15 | 14 → 14 | 13 → 13 |
| Riposte Lunge | `riposte_lunge` | 91 | 83 | 15 → 15 | 15 → 15 | 14 → 14 |
| Rite of Hoarfrost | `rite_of_hoarfrost` | 110 | 102 | 14 → 14 | 15 → 12 | 15 → 12 |
| Rite of Noon | `rite_of_noon` | 80 | 74 | 15 → 15 | 15 → 15 | 15 → 15 |
| Rite of Tailwinds | `rite_of_tailwinds` | 110 | 102 | 14 → 14 | 15 → 12 | 15 → 12 |
| Rite of the Mountain | `rite_of_the_mountain` | 132 | 123 | 15 → 12 | 15 → 12 | 15 → 12 |
| Rite of the Pyre | `rite_of_the_pyre` | 100 | 93 | 15 → 15 | 14 → 14 | 13 → 13 |
| Rite of the Storm | `rite_of_the_storm` | 110 | 103 | 14 → 14 | 15 → 12 | 15 → 12 |
| Rockburst | `rockburst` | 66 | 61 | 15 → 15 | 15 → 15 | 15 → 15 |
| Root Snare | `root_snare` | 70 | 65 | 15 → 15 | 15 → 15 | 15 → 15 |
| Rooted Kick | `rooted_kick` | 77 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Rooted Stance | `rooted_stance` | 92 | 84 | 15 → 15 | 15 → 15 | 14 → 14 |
| Royal Bramble | `royal_bramble` | 94 | 86 | 15 → 15 | 15 → 15 | 14 → 14 |
| Salamander Heart | `salamander_heart` | 118 | 109 | 13 → 13 | 15 → 12 | 15 → 12 |
| Sawtooth Rake | `sawtooth_flurry` | 97 | 89 | 15 → 15 | 14 → 14 | 13 → 13 |
| Scorch | `scorch` | 44 | 41 | 15 → 15 | 15 → 15 | 15 → 15 |
| Searing Light | `searing_light` | 87 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Seek the Light | `seek_the_light` | 91 | 85 | 15 → 15 | 15 → 15 | 14 → 14 |
| Seeker's Mark | `seekers_mark` | 91 | 84 | 15 → 15 | 15 → 15 | 14 → 14 |
| Seer's Candle | `seers_candle` | 86 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Serrated Slip | `serrated_slip` | 84 | 78 | 15 → 15 | 15 → 15 | 15 → 15 |
| Shadow Step | `shadow_step` | 83 | 76 | 15 → 15 | 15 → 15 | 15 → 15 |
| Shatter | `shatter` | 49 | 45 | 15 → 15 | 15 → 15 | 15 → 15 |
| Shatter Swing | `shatter_swing` | 92 | 85 | 15 → 15 | 15 → 15 | 14 → 14 |
| Shattered Reflection | `shattered_reflection` | 134 | 123 | 15 → 12 | 15 → 12 | 15 → 12 |
| Shatterline | `shatterline` | 73 | 68 | 15 → 15 | 15 → 15 | 15 → 15 |
| Shield Charge | `shield_charge` | 89 | 82 | 15 → 15 | 15 → 15 | 14 → 14 |
| Shield Wall | `shield_wall` | 73 | 68 | 15 → 15 | 15 → 15 | 15 → 15 |
| Shiver Shot | `shiver_shot` | 75 | 69 | 15 → 15 | 15 → 15 | 15 → 15 |
| Shrapnel Bomb | `nail_bomb` | 99 | 90 | 15 → 15 | 14 → 14 | 13 → 13 |
| Shrug Off | `shrug_off` | 64 | 59 | 15 → 15 | 15 → 15 | 15 → 15 |
| Sidestep Slash | `sidestep_slash` | 93 | 86 | 15 → 15 | 15 → 15 | 14 → 14 |
| Skate | `skate` | 36 | 33 | 15 → 15 | 15 → 15 | 15 → 15 |
| Skybolt | `skybolt` | 49 | 45 | 15 → 15 | 15 → 15 | 15 → 15 |
| Skybreak Current | `skybreak_current` | 115 | 106 | 14 → 14 | 15 → 12 | 15 → 12 |
| Sleet Squall | `sleet_squall` | 76 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Slipstream Cut | `slipstream_cut` | 95 | 88 | 15 → 15 | 14 → 14 | 13 → 13 |
| Smelling Salts | `smelling_salts` | 92 | 85 | 15 → 15 | 15 → 15 | 14 → 14 |
| Smoke Bomb | `smoke_bomb` | 83 | 76 | 15 → 15 | 15 → 15 | 15 → 15 |
| Snake Eyes | `snake_eyes` | 72 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Snare Coil | `snare_coil` | 66 | 61 | 15 → 15 | 15 → 15 | 15 → 15 |
| Spark Dart | `spark_dart` | 70 | 65 | 15 → 15 | 15 → 15 | 15 → 15 |
| Spark Focus | `spark_focus` | 78 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Spear Thrust | `spear_thrust` | 84 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Spike Check | `spike_check` | 77 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Spike Mantle | `spike_mantle` | 83 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Spur Spark | `spur_spark` | 72 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Spur Trip | `hamstring_slice` | 61 | 56 | 15 → 15 | 15 → 15 | 15 → 15 |
| Spur Vault | `spur_vault` | 70 | 64 | 15 → 15 | 15 → 15 | 15 → 15 |
| Squall | `squall_shot` | 41 | 38 | 15 → 15 | 15 → 15 | 15 → 15 |
| Static Lash | `static_lash` | 71 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Static Mantle | `static_mantle` | 86 | 79 | 15 → 15 | 15 → 15 | 15 → 15 |
| Static Pivot | `static_pivot` | 74 | 69 | 15 → 15 | 15 → 15 | 15 → 15 |
| Static Rush | `static_rush` | 74 | 68 | 15 → 15 | 15 → 15 | 15 → 15 |
| Static Ward | `static_ward` | 77 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Stoke | `stoke` | 36 | 33 | 15 → 15 | 15 → 15 | 15 → 15 |
| Stolen Moment | `stolen_moment` | 97 | 90 | 15 → 15 | 14 → 14 | 13 → 13 |
| Stone Plate | `stone_plate` | 73 | 67 | 15 → 15 | 15 → 15 | 15 → 15 |
| Stone Ward | `stone_ward` | 76 | 70 | 15 → 15 | 15 → 15 | 15 → 15 |
| Stonefist | `stonefist` | 59 | 55 | 15 → 15 | 15 → 15 | 15 → 15 |
| Stonewall Stance | `stonewall_stance` | 111 | 102 | 14 → 14 | 15 → 12 | 15 → 12 |
| Storm Beacon | `storm_beacon` | 89 | 83 | 15 → 15 | 15 → 15 | 14 → 14 |
| Storm Jar | `storm_jar` | 62 | 57 | 15 → 15 | 15 → 15 | 15 → 15 |
| Storm Relay | `storm_relay` | 79 | 73 | 15 → 15 | 15 → 15 | 15 → 15 |
| Storm Salvo | `storm_salvo` | 78 | 72 | 15 → 15 | 15 → 15 | 15 → 15 |
| Stormstring Shot | `stormstring_shot` | 112 | 103 | 14 → 14 | 15 → 12 | 15 → 12 |
| Straw Double | `straw_double` | 87 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Sun Flash | `sun_flash` | 63 | 58 | 15 → 15 | 15 → 15 | 15 → 15 |
| Sunlance | `sunlance` | 60 | 55 | 15 → 15 | 15 → 15 | 15 → 15 |
| Sunpath Stride | `sunpath_stride` | 98 | 89 | 15 → 15 | 14 → 14 | 13 → 13 |
| Sweeping Haft | `sweeping_haft` | 95 | 88 | 15 → 15 | 14 → 14 | 14 → 14 |
| Sworn Oath | `sworn_oath` | 76 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Tectonic Maul | `tectonic_maul` | 90 | 83 | 15 → 15 | 15 → 15 | 14 → 14 |
| Tempest Form | `tempest_form` | 92 | 85 | 15 → 15 | 15 → 15 | 14 → 14 |
| Thorn Crown Pact | `thorn_crown_pact` | 115 | 107 | 13 → 13 | 15 → 12 | 15 → 12 |
| Thorn Skewer | `thorn_skewer` | 90 | 83 | 15 → 15 | 15 → 15 | 14 → 14 |
| Threaded Path | `threaded_path` | 94 | 88 | 15 → 15 | 15 → 15 | 14 → 14 |
| Throwing Net | `throwing_net` | 89 | 82 | 15 → 15 | 15 → 15 | 14 → 14 |
| Thunderclap | `thunderclap` | 82 | 76 | 15 → 15 | 15 → 15 | 15 → 15 |
| Thunderline | `thunderline` | 80 | 74 | 15 → 15 | 15 → 15 | 15 → 15 |
| Thunderstone | `thunderstone` | 91 | 84 | 15 → 15 | 15 → 15 | 14 → 14 |
| Tombsplitter | `tombsplitter` | 84 | 78 | 15 → 15 | 15 → 15 | 15 → 15 |
| Trapdoor | `gate_gambit` | 60 | 55 | 15 → 15 | 15 → 15 | 15 → 15 |
| Trapdoor | `trapdoor` | 60 | 55 | 15 → 15 | 15 → 15 | 15 → 15 |
| Tremor | `tremor` | 48 | 45 | 15 → 15 | 15 → 15 | 15 → 15 |
| Undertaker Stand | `undertaker_stand` | 116 | 107 | 13 → 13 | 15 → 12 | 15 → 12 |
| Undertow Guard | `undertow_guard` | 108 | 100 | 15 → 15 | 13 → 13 | 15 → 12 |
| Unhorse | `unhorse` | 55 | 50 | 15 → 15 | 15 → 15 | 15 → 15 |
| Unpick | `threadbare_guard` | 46 | 42 | 15 → 15 | 15 → 15 | 15 → 15 |
| Unsealed Gale | `unsealed_gale` | 91 | 84 | 15 → 15 | 15 → 15 | 14 → 14 |
| Updraft | `updraft` | 51 | 48 | 15 → 15 | 15 → 15 | 15 → 15 |
| Vacuum Line | `vacuum_line` | 85 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
| Vigil | `vigil` | 31 | 28 | 15 → 15 | 15 → 15 | 15 → 15 |
| Voidsilk Molt | `voidsilk_molt` | 85 | 78 | 15 → 15 | 15 → 15 | 15 → 15 |
| Volt Surge | `volt_surge` | 68 | 63 | 15 → 15 | 15 → 15 | 15 → 15 |
| Vortex | `vortex` | 44 | 41 | 15 → 15 | 15 → 15 | 15 → 15 |
| Waning Pulse | `waning_pulse` | 89 | 82 | 15 → 15 | 15 → 15 | 15 → 15 |
| Warded Advance | `warded_advance` | 110 | 101 | 14 → 14 | 15 → 12 | 15 → 12 |
| Whetstone | `whetstone` | 70 | 65 | 15 → 15 | 15 → 15 | 15 → 15 |
| Whirlwind Slash | `whirlwind_slash` | 108 | 99 | 14 → 14 | 13 → 13 | 15 → 12 |
| White Silence | `white_silence` | 89 | 82 | 15 → 15 | 15 → 15 | 15 → 15 |
| Wildfire Halo | `wildfire_halo` | 87 | 80 | 15 → 15 | 15 → 15 | 15 → 15 |
| Wind Shear | `wind_shear` | 76 | 70 | 15 → 15 | 15 → 15 | 15 → 15 |
| Windbreak | `windbreak` | 72 | 66 | 15 → 15 | 15 → 15 | 15 → 15 |
| Windlass Volley | `windlass_volley` | 104 | 96 | 15 → 15 | 13 → 13 | 15 → 12 |
| Witchglass Double | `witchglass_double` | 120 | 110 | 13 → 13 | 15 → 12 | 15 → 12 |
| Worldbreak | `worldbreak` | 77 | 71 | 15 → 15 | 15 → 15 | 15 → 15 |
| Worldroot Stride | `worldroot_stride` | 110 | 101 | 14 → 14 | 15 → 12 | 15 → 12 |
| Worldspine | `worldspine` | 75 | 69 | 15 → 15 | 15 → 15 | 15 → 15 |
| Yank | `yank` | 33 | 31 | 15 → 15 | 15 → 15 | 15 → 15 |
| Zephyr Feint | `zephyr_feint` | 82 | 77 | 15 → 15 | 15 → 15 | 15 → 15 |
