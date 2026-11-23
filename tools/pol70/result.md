# pol-70 round 2 · Card titles in motion and on the Scavenger shelf

The headless and native probes compare the uncommitted `codex/pol-70` worktree with candidate 4 at `76aac505b`. They use the real views at 1920×1080, 100% UI scale, with Cel Look `all`. The headless comparison holds the import cache constant and checks the round 2 name table against the archived round 1 after manifest.

## Proxy title layout

The authorized RunScene patch passes each card’s resting title layout into its drag and play proxies. Retained cards keep their source layout through a draw, and incoming cards fit against the resting layout of the receiving hand. The hand and reward slots supply their authored scale before any hover or reveal transform. A pooled proxy receives a fresh title layout at spawn.

Every changed RunScene hunk is listed below. The first column uses candidate 4 line numbers. An insertion is shown with its anchor line, and the deletion marks its position in the current file.

| Candidate 4 lines | Current lines | Title change |
| --- | --- | --- |
| 7183 | 7183 | Accept the source widget and resting size in proxy creation. |
| 7208 | 7208 | Use the typed CardWidget when creating or reusing a proxy. |
| After 7215 | 7216–7221 | Copy the source title layout or fit using the resting size. |
| 13713 | 13719 | Give the Quick Wits discard proxy its resting source widget. |
| After 16715 | 16722–16723 | Pass the authored title scale to reused slots. |
| After 17085 | 17094–17095 | Pass the authored title scale to new slots. |
| 20730 | 20740 | Pass the resting source widget to the drag proxy. |
| 21880 | 21890 | Pass the resting source widget to the play flight. |
| 21983 | 21993 | Accept the resting source widget in the play flight method. |
| 21986 | 21996 | Forward that widget to the proxy builder. |
| 22080 | 22090–22091 | Read the retained hand widget before creating its deal proxy. |
| 22085 | Deleted after 22095 | Remove the later read of the same retained hand widget. |
| 22121 | 22131 | Give staged incoming cards the receiving hand’s resting size. |
| 22235 | 22245 | Give ordinary incoming cards the receiving hand’s resting size. |

[RunScene](/Users/borgerding/workspace/Labyrinth.worktrees/pol-70/scripts/run_scene.gd:7183)

## Scavenger shelf

The Scavenger buy shelf keeps the −1 source px tracking from step 3 when it needs to shrink further. Step 5 descends in whole source sizes and uses the first one that fits. The same font size is used throughout the hover lift and return. Other full-card contexts still use the round 1 fit order.

The extra fixture replaces two magic offers in the probe’s shop engine so that Shattered Reflection and Cinderweave Guard can be displayed simultaneously. The fixture uses the production shelf builder and authored assets. The normal merchant stock rules and checkpoint contents are untouched.

## Proof for the design owner

The default launcher includes all round 1 shots and the fixture shelf. It writes full frames, 2× title crops and the hand hover strip into `before/` and `after/` under a fresh output directory, printing each PNG’s absolute path. The miniature-only launcher also checks matching crop pixels.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-70 && LABYRINTH_CEL_LOOK=all /private/tmp/labyrinth_codex/pol-70/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-70 && LABYRINTH_CEL_LOOK=all /private/tmp/labyrinth_codex/pol-70/native.sh --title-rows
```

The new files are `scavenger_long_names.png` and `scavenger_long_names_titles_2x.png` in each side’s directory. Native PNG rendering remains pending on a macOS desktop. The dry run reports the output directory and records crop dimensions in the manifests.

## Chosen defaults

The fixture replaces the first two magic offers and keeps the third ordinary offer, along with the ordinary gear and item shelves. It samples both specified cards on hover in and out. The round 1 proof defaults still apply, including fixed headless 60 fps steps, 6 px of crop padding, and sampling the hand hover strip every second frame.

## Changed files in round 2

- `scripts/run_scene.gd`, `scripts/card_widget.gd`, `scripts/scavenger_shop_view.gd`
- `tools/pol70/census_probe.gd.in`, `tools/pol70/compare_rects.py`, `tools/pol70/proof.py`, `tools/pol70/result.md`

## Observed verification

[All 2,440 title measurements](/private/tmp/labyrinth_codex/pol-70/round2-final/title_fit.tsv) · [Before manifest](/private/tmp/labyrinth_codex/pol-70/round2-final/before/manifest.json) · [After manifest](/private/tmp/labyrinth_codex/pol-70/round2-final/after/manifest.json) · [Dry-run log](/private/tmp/labyrinth_codex/pol-70/round2-final.log)

| Context | Step 1 | Step 2 | Step 3 | Step 4 | Step 5 | Ellipses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `combat` | 279 | 22 | 4 | 0 | 0 | 0 |
| `boss` | 279 | 22 | 4 | 0 | 0 | 0 |
| `scavenger` | 219 | 40 | 33 | 0 | 13 | 0 |
| `graftwright_confirm` | 293 | 10 | 2 | 0 | 0 | 0 |
| `reward` | 303 | 2 | 0 | 0 | 0 | 0 |
| `draw_pile` | 293 | 10 | 2 | 0 | 0 | 0 |
| `grimoire_card` | 301 | 4 | 0 | 0 | 0 | 0 |
| `event_card` | 303 | 2 | 0 | 0 | 0 | 0 |

The stock census still reports legal titles under 14 effective px. The round 2 title check validates the fit order and the shelf exception separately.

| Required census shot | Raw card-title `small_font` hits before → after |
| --- | ---: |
| `combat` | 1 → 1 |
| `boss` | 1 → 1 |
| `scavenger` | 3 → 0 |
| `graftwright_confirm` | 1 → 1 |
| `reward` | 0 → 0 |
| `draw_pile` | 1 → 1 |

```text
combat: 686 other controls and 5 title rows matched; maximum non-title edge delta 0.0000 px
boss: 729 other controls and 5 title rows matched; maximum non-title edge delta 0.0000 px
scavenger: 441 other controls and 3 title rows matched; maximum non-title edge delta 0.0000 px
graftwright_confirm: 375 other controls and 4 title rows matched; maximum non-title edge delta 0.0000 px
reward: 291 other controls and 3 title rows matched; maximum non-title edge delta 0.0000 px
draw_pile: 905 other controls and 13 title rows matched; maximum non-title edge delta 0.0000 px
RECT COMPARISON: PASS; 0 mismatches
CARD TITLE CHECKS: PASS; 0 mismatches
NAME FIT: 0 unresolved context/name pairs
ROUND 1 NON-SHELF TITLE DIFF: 0 mismatches across 2135 rows
ROUND 1 SHELF TITLE DIFF: 13 expected changes; 0 other mismatches
TITLE MOTION: PASS; 12 sequences; 0 mismatches
CENSUS RESULT: PASS; 14/14 shots succeeded; 0 capped
```

### Step 5 names

| Card | Source px | Effective px | Fits |
| --- | ---: | ---: | --- |
| Bone-Ward Charm · `bone_ward_charm` | 16 | 11.27 | Yes |
| Cinderline Tempo · `cinderline_tempo` | 17 | 11.98 | Yes |
| Cinderweave Guard · `cinderweave_guard` | 16 | 11.27 | Yes |
| Earthen Rampart · `earthen_rampart` | 17 | 11.98 | Yes |
| Gathering Rhythm · `gathering_rhythm` | 16 | 11.27 | Yes |
| Lodestone Reversal · `lodestone_reversal` | 16 | 11.27 | Yes |
| Rite of the Mountain · `rite_of_the_mountain` | 15 | 10.57 | Yes |
| Salamander Heart · `salamander_heart` | 17 | 11.98 | Yes |
| Shattered Reflection · `shattered_reflection` | 15 | 10.57 | Yes |
| Skybreak Current · `skybreak_current` | 17 | 11.98 | Yes |
| Thorn Crown Pact · `thorn_crown_pact` | 17 | 11.98 | Yes |
| Undertaker Stand · `undertaker_stand` | 17 | 11.98 | Yes |
| Witchglass Double · `witchglass_double` | 17 | 11.98 | Yes |

Minimum measured size is **10.57 effective px**. All 13 use −1 source px glyph spacing. The next larger whole source size overflows for each.

### Motion and receipt frames

```text
before/scavenger_long_names/shattered_reflection: 16 hover frames; source px 14; -1 refits; peak lift scale 1.045
before/scavenger_long_names/cinderweave_guard: 16 hover frames; source px 14; -1 refits; peak lift scale 1.045
after/scavenger_long_names/shattered_reflection: 16 hover frames; source px 15; 0 refits; peak lift scale 1.045
after/scavenger_long_names/cinderweave_guard: 16 hover frames; source px 16; 0 refits; peak lift scale 1.045
motion_short/deal: 20 frames; source px [19]; 0 refits
motion_short/drag: 14 frames; source px [19]; 0 refits
motion_short/hover_in: 10 frames; source px [19]; 0 refits
motion_short/hover_out: 9 frames; source px [19]; 0 refits
motion_short/play: 31 frames; source px [19]; 0 refits
long_hand/hover_in: 10 frames; source px [15]; 0 refits
long_hand/hover_out: 9 frames; source px [15]; 0 refits
motion_long/deal: 20 frames; source px [15]; 0 refits
motion_long/drag: 14 frames; source px [15]; 0 refits
motion_long/hover_in: 10 frames; source px [15]; 0 refits
motion_long/hover_out: 9 frames; source px [15]; 0 refits
motion_long/play: 31 frames; source px [15]; 0 refits
```

[Cinderweave Guard per-frame log](/private/tmp/labyrinth_codex/pol-70/round2-final/after/motion_long-probe.log) · [Patch Up per-frame log](/private/tmp/labyrinth_codex/pol-70/round2-final/after/motion_short-probe.log) · [Fixture shelf proof](/private/tmp/labyrinth_codex/pol-70/round2-final/after/scavenger_long_names-probe.log)

The headless title metrics match for both miniature crops. The receipt fixture reached `embers=1000->600` on both revisions.

### Planned native capture sizes

These are headless measurements for the 2× crops. Full frames use 1920×1080.

| Full PNG | Crop PNG | Before crop | After crop |
| --- | --- | ---: | ---: |
| `long_hand.png` | `long_hand_titles_2x.png` | 1748×130 | 1748×130 |
| `scavenger.png` | `scavenger_titles_2x.png` | 1374×84 | 1374×84 |
| `graftwright_confirm.png` | `graftwright_confirm_titles_2x.png` | 2298×100 | 2298×100 |
| `event_transform.png` | `event_transform_titles_2x.png` | 690×56 | 690×56 |
| `scavenger_receipt.png` | `scavenger_receipt_titles_2x.png` | 148×48 | 148×48 |
| `scavenger_long_names.png` | `scavenger_long_names_titles_2x.png` | 1374×84 | 1374×84 |

### Focused checks

| Check | Exact result |
| --- | --- |
| Card display overrides | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16745 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/pol-70/round2-card-display.log) |
| Card summary fit | `CARD SUMMARY FIT RESULT: PASS (223 checks, 0 failures, 26 samples)`. [Log](/private/tmp/labyrinth_codex/pol-70/round2-card-summary-fit.log) |
| Sentence face fit | `FACE FIT CHECKS: 18992 checks, 0 failures` and `TEST RESULT: PASS`. [Log](/private/tmp/labyrinth_codex/pol-70/round2-face-fit.log) |
| UI identity lint | `Ran 25 tests in 6.536s` and `OK`. [Log](/private/tmp/labyrinth_codex/pol-70/round2-ui-identity.log) |
