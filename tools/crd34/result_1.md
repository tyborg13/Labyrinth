# crd-34 feedback 1

## Light

Revealing Glare and Searing Light now show **Light** “An enemy starting a turn in Light gains Expose 2.” The `only_light` keyword and legacy selector fields use the same sentence. The `illuminate` glossary template still supplies radius-based Light descriptions. A card that has a Light placement panel uses that panel once. [Selector data](../../data/card_panel_text.json#L241) · [Panel assembly](../../scripts/action_icon_library.gd#L605)

The witness committed Beacon on a Crawler at `(3, 4)`, then resolved the Crawler's turn. Expose went from 0 to 2 in Light and stayed at 0 in the unlit control. The native dry run also checked Fire, Ice, Light and Electrified both as standalone selectors and alongside their ground panels. [Witness](rules_witness.gd) · [Witness log](/private/tmp/labyrinth_codex/crd-34/feedback1.PYpNkk/rules-witness.log)

The 309-card export scanned 983 keyword panels across catalog, projected hand and legacy card views for standalone `X` and unresolved brace placeholders, including `{r}`. None appeared in the keyword panels. A separate scan of the exported native condition icons found these 12 `X` instances in both exports. The native icon itself uses the generic glossary tooltip through a separate CardWidget path. [Export audit](/private/tmp/labyrinth_codex/crd-34/feedback1.PYpNkk/audit.log) · [Baseline comparison](/private/tmp/labyrinth_codex/crd-34/feedback1.PYpNkk/legacy-markers.log) · [Native icon path](../../scripts/card_widget.gd#L2019)

| Native icon | Cards with an existing unfilled `X` |
| --- | --- |
| Light | Blinding Bash, Dazzle, Hallowed Strike, Revealing Glare, Searing Light, Sunlance |
| Move | Couched Lance, Headlong, Iron Wheel |
| Stagger | Hobnail Drive |
| Retaliate | Reflected Threat |
| Illusion | Refraction |

## Groundsplit

One live Groundsplit forecast covered all three occupied tiles, each at distance 1 from Craghide's Outcrop at `(2, 4)`.

| Unit | Tile | Damage |
| --- | --- | --- |
| Hero | `(2, 3)` | 7 |
| Crawler | `(3, 4)` | 0 |
| Player's Illusion | `(2, 5)` | 7 |

The Crawler was spared, so the glossary and Grimoire both use the approved fallback, “This enemy damages you if you stand within 2 tiles of an Outcrop this enemy raised.” The original seven hero resolutions also passed. [Glossary](../../data/glossary.json#L487) · [Grimoire](../../data/grimoire.json#L1066) · [Groundsplit log](/private/tmp/labyrinth_codex/crd-34/feedback1.PYpNkk/groundsplit.log) · [Surface log](/private/tmp/labyrinth_codex/crd-34/feedback1.PYpNkk/groundsplit-surfaces.log)

## Snapshots and verification

The existing snapshot fixtures now pin the four selector entries and the Groundsplit glossary and Grimoire sentences. The test assertions are untouched. The export still shows exactly five cards changed from the baseline. Only Revealing Glare and Searing Light changed from the first implementation. [Complete hover list](result.md#complete-list-of-changed-card-hovers) · [Selector and glossary fixture](../../tests/fixtures/txt20_rules_copy.json) · [Grimoire fixture](../../tests/fixtures/pla02_grimoire_pages.json#L296)

```text
CRD34 LIGHT WITNESS: {"after":2,"before":0,"enemy_tile_at_start":"(3, 4)","light":[{"id":1,"owner":"player","pos":"(3, 4)","radius":2,"remaining_activations":-1}],"unlit_control":0}
CRD34 GROUNDSPLIT UNITS: {"enemy_damage":0,"enemy_tile":"(3, 4)","hero_damage":7,"hero_tile":"(2, 3)","illusion_damage":7,"illusion_tile":"(2, 5)","owned_outcrop":"(2, 4)"}
TXT37 GROUNDSPLIT: PASS (7 live resolutions)
CRD34 AUDIT: 309 IDs, 53 -> 52 distinct False rows, 0 new False
CRD34 DIFF: only empty_husk, revealing_glare, searing_light, stoke, white_silence hover copy changed
CRD34 FEEDBACK DIFF: only revealing_glare, searing_light changed from the first implementation
CRD34 TEMPLATES: 983 keyword panels checked, 0 unfilled markers
CRD34 LEGACY CONDITION ICONS: 12 existing marker instances, 0 new
CRD34 CONTROLS: PASS (4 selectors and glossary-only Sweeping Strike)
CRD34 DRY RUN: PASS (1920x1080, 100% UI scale, 0 PNGs, 0 failures)
```

| Check | Result |
| --- | --- |
| Rules text lint | `Ran 3 tests in 0.047s` · `OK` · `PASS: Rules text lint (16 existing hits)` |
| `test_card_panel_text` | `Ran 4 tests in 0.004s` · `OK` |
| `test_short_card_tooltips` | `Ran 5 tests in 0.011s` · `OK` |
| `text_budget_test` | `Ran 6 tests in 0.153s` · `OK` |
| UI identity lint | `Ran 25 tests in 3.853s` · `OK` |
| Python default group | `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 26.829s` · `OK` |

## Chosen defaults

- Light uses the crd-33 Crawler and Beacon fixture with a separate unlit activation. The Light deduplication control uses radius 2.
- The expanded Groundsplit witness reuses the original 9-tile board edge, Craghide position, distance-one hero position, and 2-Health Outcrop. The adjacent Crawler and Illusion have 100 fixture Health to survive and expose the exact damage. The Illusion uses fixture ID 41.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/crd-34 && bash tools/crd34/native.sh
```

The windowed capture is pending. The command prints the four PNG paths under a new `/private/tmp/labyrinth_codex/crd-34/native.*/` directory. No design placeholders. The work remains uncommitted. [Headless dry-run log](/private/tmp/labyrinth_codex/crd-34/native.nidXv0/probe.log) · [Files and exact commands](result.md)
