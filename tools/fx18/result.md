# fx-18 result

Base `7d1ba7df9` on `codex/fx-18`. Implementation and proof files are uncommitted.

## Spell sites

The selector uses the resolved step's protected dragon profile. Burst names come from the fx-12 element mapping.

| Dragon | Resolved site | Geometry | Playback |
| --- | --- | --- | --- |
| Vyraketh | Cinder Breath (`cinderfall/aoe`) | Breath | Fire sweep |
| Vyraketh | Crownfire (`detonate_cinders`) | Ground | Fire spread |
| Vyraketh | Meteorfall's ranged follow-up (`kindle_ground/ranged`) | Breath | Fire at contact |
| Tharokh | Bedrock Breath (`bedrock_breath/aoe`) | Breath | Earth sweep |
| Tharokh | Faultline (`terrain_burst`) | Ground | Earth spread |
| Tharokh | Faultline's ranged follow-up (`faultline/ranged`) | Breath | Earth at contact |
| Vaeloryx | Skyhook (`skyhook/ranged` with Pull) | Breath | Air at contact |
| Vaeloryx | Hollow Gale and Eye of the Storm (`aoe`, plus the profile's `gale_force` selector) | Ground | Air spread |
| Vaeloryx | Eye of the Storm's melee follow-up | Ground in the protected profile | Air at contact |
| Iskaldra | Whiteout Lance (`whiteout_lance/aoe`) | Breath | Ice sweep |
| Iskaldra | Crystal Mantle's ranged follow-up | Breath | Ice at contact |
| Iskaldra | Shatterstorm (`shatterstorm/aoe`) | Ground | Ice spread |
| Zekarion | Storm Lash (`storm_claw/ranged`) and Call Wisps' ranged hit | Breath | Lightning at contact |
| Zekarion | Overload (`tempest_breath/ranged`) | Ground | Lightning at contact |

The original table omitted the Meteorfall ranged shot, Faultline ranged shot and Eye of the Storm melee follow-ups. All three meet the profile rule. The current Hollow Gale and Eye of the Storm declarations emit `aoe` steps. The same selector covers a legacy `gale_force` step with that ground profile.

Meteorfall's cinder marking and Cinder Maw's cinder marking continue through fx-15. Skybreak and player Meteorfall keep their falling-strike paths. Stonewake, Worldspine Claw, Razor Dive, Rime Talon, Cinder Maw's melee and Crownfire's melee still use their physical paths. Worldspine Pulse uses its own presentation. Crystal Mantle's armor, Call Wisps' summons and other utility actions keep their existing paths. Noctyrax's Starless Breath, Night Coil and Last Eclipse keep the shadow painter. Void Claw retains its physical path.

## Acceptance

1. Each eligible step feeds its resolved cells to the existing rear/front player. The API owns placement, visibility, and Health, Block, Stoneskin, Mantle, Defiance and defeat row selection.
2. Breath rings use Chebyshev distance from the resolved footprint. The RunScene submission starts each ring on the first existing action frame that reaches its specified progress. A single-target breath starts on contact. Ground batches share the fx-12 area centre and capped Manhattan delay. Batching covers areas above the card-area tile cap. Reduced motion uses the fx-12 still on contact.
3. The schedule submits without waiting. Existing area and strike plans can claim individual tiles. The existing targeted-replacement marker can claim a direct hit. Hidden-source clipping keeps the original target and ring geometry for burst planning and the fx-12 renderer applies current visibility.
4. Eligible spells skip the procedural travel, release glow and impact painters. The shadow submissions retain their original arguments. The implementation uses the protected fx-12 API and shader as provided.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-18 && /private/tmp/labyrinth_codex/fx-18/native.sh
```

The command runs `tools/visual_probe_runner.py` with the fx-15 60 fps MovieWriter clock, `LABYRINTH_CEL_LOOK=all`, the HUD, and the fx-18 image contract. It prints the before/after paths for each case under `/private/tmp/labyrinth_codex/fx-18/native/{before,after}/<case>/`. Each take writes `strip.png` (5760×720), `native-evidence.png` (1920×1080), `take.json`, and `manifest.json`. The 60 fps clip is `/private/tmp/labyrinth_codex/fx-18/native/cinder-breath-whiteout-lance.mp4`. Each strip samples the existing release and contact frames, with the requested offsets rounded to the 60 fps capture clock. The camera uses the projected bounds of the resolved area.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-18 && /private/tmp/labyrinth_codex/fx-18/native.sh --dry-run
```

The headless run writes `take.json` for each case and witness under `/private/tmp/labyrinth_codex/fx-18/headless/`. Before takes load the three presentation scripts from `7d1ba7df9`, with local resource paths rebound and the duplicate global class declaration removed for loading in the same project.

- `FX-18 VERIFY PASS (0 failures)`. Proof covers every listed spell action and the three profile-matched follow-ups, six capture times in all ten before/after takes, and both 150-frame recording segments. Cinder Breath and Whiteout Lance both submitted the nearest ring on frame 20 and the farthest ring with the numbers on frame 35. The fog witness stamped 10 of 14 fan cells. The reduced witness showed one still on each of 14 cells at contact. The Block and defeated-illusion witnesses selected the hit row and an empty fan tile selected the floor row. Starless Breath and Night Coil each matched 26 shadow submissions against base.
- Cinder Breath, Bedrock Breath, Hollow Gale, Whiteout Lance and Overload each matched base at 66 authored and 66 rendered action frames. Their respective completion frames were 73, 74, 76, 73 and 71 in both versions.
- `FX-18 FOCUSED dragon_area_presentation PASS`, `FX-18 FOCUSED dragon_feedback1 PASS`, `FX-18 FOCUSED dragon_pressure_mechanics PASS` and `FX-18 FOCUSED PASS (0 failures)`.
- The UI identity lint ran 25 tests and reported `OK`. The rules-text lint reported `PASS: Rules text lint (16 existing hits)`.
- The Python default group selected 22 modules. The first run reported `Ran 194 tests in 38.636s` and `FAILED (failures=1)`. The final group run reported `Ran 194 tests in 53.579s` and `FAILED (failures=2)`. The base sidecar failure appeared in both runs. The final run also hit `Child did not start` in the task-runner process cleanup test. Retrying that module alone reported `Ran 15 tests in 11.018s` and `OK`.

## Chosen defaults

The proof uses inherited seed 7262026 and 60 fps sampling. The fixtures in `cases.gd` use dragon rooms at depth 4 or 24, the hero at (4,4), the dragon at (4,1), and fuel at (3,4) and (5,4). The Eye of the Storm melee witness places the hero one tile closer. The hero has 30 Health and 20 Block in the fully blocked witness. Illusion ID 91 has 1 Health, spires have 4 Health, and Shatterstorm starts with two armor layers. The shadow call witness uses a 126 px tile and seed 91. The recording uses two 150-frame segments and the native runner uses the fx-15 300-second capture timeout.

## Open issues

- The windowed captures and recording await a desktop run with macOS window-server access.
- The fx-17 implementation is absent from this base. Headless proof exercises the existing targeted-replacement marker in addition to fx-12 and fx-15 claim paths.
- The Python default group reports the base checkout's missing `tools/flt01/fight_probe.gd.uid` and `tools/flt01/renderer_check.gd.uid`.

No `TODO_DESIGN_*` placeholders.
