# txt-37 verification

1. **One source.** The creature page asks the combat board for its ordered badges with base creature data and lists the trait entries. The row gets its icon and text from each badge. Gale Herald’s body-only tooltip uses the registered icon label, Gust. Burst retains its counted title and area diagram, and Split retains its counted title and sentence. The existing board badge producers and Grimoire data are untouched. [Creature page](../../scripts/grimoire_creature_page.gd#L41), [Combat badge builder](../../scripts/combat_board_view.gd#L17853)
2. **Every creature.** The live Grimoire panel was checked before and after against badges built from fresh base combat actors. The 18 release pages had identical rows before and after. All 44 pages in the txt-36 overlay now match their combat badge tokens in order, including the row textures and tooltip copy. The overlay was read from `codex/txt-36:data/grimoire.json` at `0b147b95b` into an isolated temporary file. [Page probe](pages.gd)
3. **Groundsplit.** The glossary line is false as a description of the full attack area. Groundsplit damaged the player at Manhattan distance 2 from either owned Outcrop. The glossary and resolver were left untouched. [Groundsplit witness](groundsplit.gd), [Glossary line](../../data/glossary.json#L490)

## Changed pages

| Creature | Before | After |
| --- | --- | --- |
| Gale Herald | Anchored | Gust, Anchored |
| Glacial Mirror | No Traits section | Reflect |
| Gust Shrike | No Traits section | Flying |
| Storm Capacitor | No Traits section | Charge, with the badge’s base `0/3` |

Storm Capacitor’s immobility and Stoneback Mite’s on-death Rubble have no combat trait badge. Burrow Grub’s Burrow badge appears after the creature burrows during combat, and Command depends on a live Warband captain. Neither has a base badge. [Immobility predicate](../../scripts/enemy_mechanics/capacitor.gd#L12), [Rubble death hook](../../scripts/combat_engine.gd#L8635), [Burrow badge](../../scripts/enemy_mechanics/burrow_view.gd#L91), [Command predicate](../../scripts/enemy_mechanics/unit_traits.gd#L51)

## Complete comparison

Each cell lists icon-token IDs in the order returned or displayed. An em dash denotes an empty list.

| Creature ID | Combat base badge tokens | Page before | Page after |
| --- | --- | --- | --- |
| `acolyte` | — | — | — |
| `arc_thrall` | — | — | — |
| `ash_hound` | — | — | — |
| `ashen_reaver` | — | — | — |
| `bell_tender` | — | — | — |
| `bile_bloomer` | — | — | — |
| `briar_weaver` | — | — | — |
| `burrow_grub` | — | — | — |
| `chainbound_gaoler` | — | — | — |
| `cinder_droplet` | — | — | — |
| `cinder_ooze` | `splits` | `splits` | `splits` |
| `craghide` | — | — | — |
| `crawler` | — | — | — |
| `ember_hoarder` | `burst` | `burst` | `burst` |
| `ember_tick` | `burst` | `burst` | `burst` |
| `frostglass_lancer` | — | — | — |
| `gale_herald` | `wind, anchored` | `anchored` | `wind, anchored` |
| `gallows_roc` | `anchored` | `anchored` | `anchored` |
| `glacial_mirror` | `reflect` | — | `reflect` |
| `gloam_stalker` | — | — | — |
| `grave_surgeon` | — | — | — |
| `gust_shrike` | `flying` | — | `flying` |
| `harrier` | — | — | — |
| `hoarfrost_seer` | — | — | — |
| `hollow_mimic` | — | — | — |
| `iskaldra` | `stagger` | `stagger` | `stagger` |
| `last_lamplighter` | — | — | — |
| `lightning_wisp` | — | — | — |
| `noctyrax` | `stagger` | `stagger` | `stagger` |
| `rime_spitter` | — | — | — |
| `rime_whelp` | — | — | — |
| `rimejaw` | — | — | — |
| `roc_fledgling` | — | — | — |
| `slag_mortar` | — | — | — |
| `stoneback_mite` | — | — | — |
| `storm_cantor` | — | — | — |
| `storm_capacitor` | `charge` | — | `charge` |
| `tharokh` | `stagger` | `stagger` | `stagger` |
| `vaeloryx` | `stagger, immobilize` | `stagger, immobilize` | `stagger, immobilize` |
| `veilbound_acolyte` | — | — | — |
| `vyraketh` | `stagger` | `stagger` | `stagger` |
| `warden` | — | — | — |
| `wick_shade` | — | — | — |
| `zekarion` | `stagger, shock` | `stagger, shock` | `stagger, shock` |

## Groundsplit witness

The probe raised Craghide-owned Outcrops at `(2, 4)` and `(5, 4)`, plus another owner’s Outcrop at `(6, 6)`. The committed attack forecast contained 20 distinct, passable tiles at Manhattan distances 1 or 2 from the two owned centers. The wall at `(2, 2)` and the two owned centers were outside the footprint. Each row below resolves the real Groundsplit intent with the player on the indicated tile. [Footprint builder](../../scripts/guardian_combat_rules.gd#L33), [Headless receipt](/private/tmp/labyrinth_codex/txt-37/groundsplit.log)

| Position | Tile | HP lost |
| --- | --- | ---: |
| Distance 1 | `(2, 3)` | 7 |
| Distance 2, axial | `(2, 6)` | 7 |
| Distance 2, diagonal | `(1, 3)` | 7 |
| Distance 2 from the second Outcrop | `(6, 3)` | 7 |
| Overlap | `(4, 4)` | 7 |
| Distance 3 | `(2, 1)` | 0 |
| Foreign Outcrop only | `(6, 7)` | 0 |

## Receipts

Godot commands ran through `python3 tools/godot_task_runner.py --task-id txt-37 --stream -- godot --headless --path . --script <script>`. The baseline inventories used `-- --before` before the renderer edit. Expanded inventories set `TXT37_GRIMOIRE` to the temporary txt-36 JSON. Headless Godot emitted the same macOS system CA diagnostic across runs and returned successful proof results.

| Check | Exact result | Receipt |
| --- | --- | --- |
| `pages.gd`, release before and after | `TXT37 PAGES: PASS (headless, 18 creatures)` | [Before](/private/tmp/labyrinth_codex/txt-37/before-release.log), [After](/private/tmp/labyrinth_codex/txt-37/after-release.log) |
| `pages.gd`, txt-36 before and after | `TXT37 PAGES: PASS (headless, 44 creatures)` | [Before](/private/tmp/labyrinth_codex/txt-37/before-expanded.log), [After](/private/tmp/labyrinth_codex/txt-37/after-expanded.log) |
| Inventory diff | `TXT37 COMPARISON: PASS (18 release pages unchanged, 44 expanded pages match, 4 changed)` | [Comparison](/private/tmp/labyrinth_codex/txt-37/comparison.log) |
| `groundsplit.gd` | `TXT37 GROUNDSPLIT: PASS (7 live resolutions)` | [Witness](/private/tmp/labyrinth_codex/txt-37/groundsplit.log) |
| `bash -n tools/txt37/native.sh` | Exit 0 | |
| `bash tools/txt37/native.sh --dry-run` | `TXT37 PAGES: PASS (headless, 3 capture states)` | [Dry-run](/private/tmp/labyrinth_codex/txt-37/proof.jGYXKF/after.log) |
| Capture plan names | `TXT37 CAPTURE PLAN: PASS (3 planned PNGs match the native contract)` | [Comparison](/private/tmp/labyrinth_codex/txt-37/comparison.log) |
| `test_ui_identity_lint.py` | `Ran 25 tests in 4.673s`, `OK` | [UI identity](/private/tmp/labyrinth_codex/txt-37/ui-identity.log) |
| `test_rules_text_lint.py` | `Ran 3 tests in 0.060s`, `OK`, `PASS: Rules text lint (16 existing hits)` | [Rules text](/private/tmp/labyrinth_codex/txt-37/rules-text.log) |
| `test_short_card_tooltips.py` | `Ran 5 tests in 0.013s`, `OK` | [Grimoire copy](/private/tmp/labyrinth_codex/txt-37/short-tooltips.log) |
| `test_icon_identity_policy.py` | `Ran 10 tests in 0.096s`, `OK` | [Icon identity](/private/tmp/labyrinth_codex/txt-37/icon-identity.log) |
| `test_card_panel_text.py` | `Ran 4 tests in 0.007s`, `OK` | [Card panel text](/private/tmp/labyrinth_codex/txt-37/card-panel-text.log) |
| `grimoire_search_probe.gd` | `GRIMOIRE STEAM KEYBOARD: PASS`, `GRIMOIRE SEARCH PROBE RESULT: PASS` | [Search](/private/tmp/labyrinth_codex/txt-37/grimoire-search.log) |
| `grimoire_focus_return_probe.gd` | `GRIMOIRE SEARCH PROBE RESULT: PASS` | [Focus return](/private/tmp/labyrinth_codex/txt-37/grimoire-focus.log) |

## Changed line ranges

| File | Lines | Purpose |
| --- | --- | --- |
| [`scripts/grimoire_creature_page.gd`](../../scripts/grimoire_creature_page.gd#L41) | 3–11, 23, 41–64 | Use the ordered base trait badges to build the existing page rows. |
| [`tools/txt37/pages.gd`](pages.gd) and [UID](pages.gd.uid) | 1–170, UID 1 | Compare live pages and badges and capture the three chosen sections. |
| [`tools/txt37/groundsplit.gd`](groundsplit.gd) and [UID](groundsplit.gd.uid) | 1–96, UID 1 | Measure the committed Groundsplit forecast and actual HP loss. |
| [`tools/txt37/native.sh`](native.sh) | 1–29 | Prepare the isolated overlay and invoke the appropriate proof runner. |
| [`tools/txt37/native_contract.json`](native_contract.json) | 1–9 | Validate exactly sized PNGs and their center region. |
| [`tools/txt37/result.md`](result.md) | Entire file | Record acceptance and proof. |

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-37 && bash tools/txt37/native.sh
```

The command sets `LABYRINTH_CEL_LOOK=all` and checks `1920x1080` at 100% UI scale. It prints a new output directory and each PNG’s absolute path on its own line. The PNGs go under that directory’s `after/` subfolder, with the visual-runner manifest at `after-captures.json`. No inspection fixture command was requested.

The headless dry-run printed these planned paths.

```text
/private/tmp/labyrinth_codex/txt-37/proof.jGYXKF/after/enemy_glacial_mirror_traits_1920x1080.png
/private/tmp/labyrinth_codex/txt-37/proof.jGYXKF/after/enemy_gust_shrike_traits_1920x1080.png
/private/tmp/labyrinth_codex/txt-37/proof.jGYXKF/after/enemy_cinder_ooze_traits_1920x1080.png
```

## Chosen defaults

- Page proof uses Cinder Ooze as the unchanged reference, an isolated Grimoire with all creature pages unlocked, pointer modality, reduced motion, four layout frames, and one pixel of geometry tolerance. The comparison spawns each enemy separately at the fixture origin with actor ID 1 and no live encounter.
- Groundsplit reuses the Guardian fixture and the named 9×9 board, Outcrop, wall and witness positions. Both owned Outcrops and the foreign Outcrop have 2 HP. The foreign fixture owner ID is 999.
- The native contract reuses txt-35’s 920×420 region at (500, 320), minimum luma range 25 and minimum luma standard deviation 3.

## Open issues

- Native captures and visual inspection are pending because the worker has no macOS window-server access. The headless proof checked the expected rows, scroll position and text fit.
- Groundsplit’s glossary wording remains a report-only discrepancy.
- There are no `TODO_DESIGN_*` placeholders. All changes are uncommitted on `codex/txt-37`.
