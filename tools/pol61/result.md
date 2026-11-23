# pol-61 evidence

The baseline checkout was `codex/release` at `92ed73479e58c97aa091300579eeef6f0039e59c`. Both runs used the production RunScene and CombatEngine with the same fixture. The probe drove the Pass button, hand cards, and Escape through viewport `push_input`. Draw and discard fixture changes used the authoritative hand refresh with the pointer parked. Brace left the hand through an actual card play.

Frame −1 is the last sampled pre-action state. Frames start again at 0 for each scenario. Card slots are zero-based and −1 means there was no lifted slot. A range includes every frame in that range. Headless runs advanced the draw signal awaited by the production animation. The full logs retain the pointer position, hover and lift ownership, emphasis strength, per-card RGBA, slot RGBA, proxies, cache state, and rects on every frame.

- [Release frame trace](/private/tmp/labyrinth_codex/pol-61/headless-before/frames.jsonl)
- [Patched frame trace](/private/tmp/labyrinth_codex/pol-61/headless-after/frames.jsonl)
- [Capture dry-run log](/private/tmp/labyrinth_codex/pol-61/dry-run.log)

## 1. Deselect under a resting pointer

**Stale in the synthetic-input scenarios.** On frame 0 all three card-side cancels returned hover to slot 0 with a partial lift, and the board-side cancel had zero lift strength. No pointer motion was sent after the cancel.

| Scenario | Release hovered/lifted slot by frame | Patched hovered/lifted slot by frame |
| --- | --- | --- |
| Click selected card | -1 → -1/0, 0–23 → 0/0 | -1 → -1/0, 0–23 → 0/0 |
| Right-click | -1 → -1/0, 0–23 → 0/0 | -1 → -1/0, 0–23 → 0/0 |
| Escape | -1 → -1/0, 0–23 → 0/0 | -1 → -1/0, 0–23 → 0/0 |
| Right-click with pointer on board | -1 → -1/0, 0–23 → -1/-1 | -1 → -1/0, 0–23 → -1/-1 |

## 2. Turn start and hand relayout

**Stale in the synthetic-input scenarios.** On Pass, the parked pointer lay over slot 1 in the old fan. Its resting owner in the five-card hand was slot 2. Slot 2 was the first and only card to lift after the redeal. The discard and played-card cases held all lifts through the slide. Draw settled directly into slot 2.

| Scenario | Release lifted slot by frame | Patched lifted slot by frame |
| --- | --- | --- |
| Pass and redeal | -1–162 → -1, 163–186 → 2 | -1–163 → -1, 164–187 → 2 |
| Pass and redeal with reduced motion | -1–118 → -1, 119–142 → 2 | -1–118 → -1, 119–142 → 2 |
| Draw | -1 → 1, 0 → -1, 1–23 → 2 | -1 → 1, 0 → -1, 1–23 → 2 |
| Discard | -1 → 2, 0–6 → -1, 7–23 → 1 | -1 → 2, 0–6 → -1, 7–23 → 1 |
| Play Brace | -1 → 0, 0–80 → -1, 81–96 → 1 | -1 → 0, 0–79 → -1, 80–95 → 1 |

Before dealt proxies from frame 134 through 161 and published the live fan on frame 162. The final slot under the pointer on publication was 2.
The slide flags were discard sliding -1 → 0, 0–6 → 1, 7–23 → 0 and play sliding -1 → 0, 0–6 → 1, 7–71 → 0, 72–80 → 1, 81–96 → 0. A flag of 1 means the fan was moving.

After dealt proxies from frame 135 through 162 and published the live fan on frame 163. The final slot under the pointer on publication was 2.
The slide flags were discard sliding -1 → 0, 0–6 → 1, 7–23 → 0 and play sliding -1 → 0, 0–5 → 1, 6–70 → 0, 71–79 → 1, 80–95 → 0. A flag of 1 means the fan was moving.

## 3. Pass dim and brighten

**Live and fixed in headless.** On release, the retained cards brightened during the staged deal and snapped from 0.99917 to 0.56000 at the proxy-to-live swap. The patched turn-start deal carries the current locked tint until publication. The live widgets start from the visible proxy colors and ease to their interaction colors using the existing cubic ease-out over `HandFanContainer.CLOSE_SLIDE_SECONDS` (0.18 s). Each retained card entered and exited the patched swap at 0.56000. The largest swap-frame step across all five cards was 0.00069, on an incoming card finishing its deal.

| Maximum absolute alpha step across visible slots | Release | Patched |
| --- | --- | --- |
| Lock | 0.11125 on frame 1 (slot 0) | 0.11125 on frame 1 (slot 0) |
| Deal | 0.02398 on frame 148 (slot 0) | 0.01471 on frame 144 (slot 3) |
| Unlock | 0.43917 on frame 162 (slot 0) | 0.11125 on frame 164 (slot 0) |

RGB was 1.0 in these tint samples. The alpha vectors below are in visible slot order. Each line covers the stated frame or range at five decimals. A joining card has no preceding frame until it appears.

### Before normal motion

| Frames | Owner | Slot alphas |
| --- | --- | --- |
| -1–0 | live | 1.00000, 1.00000, 0.56000 |
| 1 | live | 0.88875, 0.88875, 0.56000 |
| 2 | live | 0.79803, 0.79803, 0.56000 |
| 3 | live | 0.72575, 0.72575, 0.56000 |
| 4 | live | 0.66983, 0.66983, 0.56000 |
| 5 | live | 0.62815, 0.62815, 0.56000 |
| 6 | live | 0.59665, 0.59665, 0.56000 |
| 7 | live | 0.57793, 0.57793, 0.56000 |
| 8 | live | 0.56700, 0.56700, 0.56000 |
| 9 | live | 0.56177, 0.56177, 0.56000 |
| 10 | live | 0.56013, 0.56013, 0.56000 |
| 11–133 | live | 0.56000, 0.56000, 0.56000 |
| 134 | proxy | 0.56131, 0.56131, 0.56131, 0.82120, 0.82000 |
| 135 | proxy | 0.56566, 0.56566, 0.56566, 0.82518, 0.82000 |
| 136 | proxy | 0.57228, 0.57228, 0.57228, 0.83117, 0.82000 |
| 137 | proxy | 0.58140, 0.58140, 0.58140, 0.83929, 0.82000 |
| 138 | proxy | 0.59288, 0.59288, 0.59288, 0.84931, 0.82000 |
| 139 | proxy | 0.60659, 0.60659, 0.60659, 0.86094, 0.82000 |
| 140 | proxy | 0.62236, 0.62236, 0.62236, 0.87389, 0.82000 |
| 141 | proxy | 0.64001, 0.64001, 0.64001, 0.88780, 0.82000 |
| 142 | proxy | 0.65931, 0.65931, 0.65931, 0.90231, 0.82000 |
| 143 | proxy | 0.68006, 0.68006, 0.68006, 0.91702, 0.82027 |
| 144 | proxy | 0.70199, 0.70199, 0.70199, 0.93154, 0.82262 |
| 145 | proxy | 0.72484, 0.72484, 0.72484, 0.94549, 0.82729 |
| 146 | proxy | 0.74836, 0.74836, 0.74836, 0.95848, 0.83418 |
| 147 | proxy | 0.77049, 0.77049, 0.77049, 0.96938, 0.84237 |
| 148 | proxy | 0.79447, 0.79447, 0.79447, 0.97960, 0.85295 |
| 149 | proxy | 0.81829, 0.81829, 0.81829, 0.98797, 0.86505 |
| 150 | proxy | 0.84164, 0.84164, 0.84164, 0.99425, 0.87835 |
| 151 | proxy | 0.86427, 0.86427, 0.86427, 0.99828, 0.89249 |
| 152 | proxy | 0.88589, 0.88589, 0.88589, 0.99995, 0.90711 |
| 153 | proxy | 0.90626, 0.90626, 0.90626, 1.00000, 0.92180 |
| 154 | proxy | 0.92512, 0.92512, 0.92512, 1.00000, 0.93618 |
| 155 | proxy | 0.94226, 0.94226, 0.94226, 1.00000, 0.94985 |
| 156 | proxy | 0.95747, 0.95747, 0.95747, 1.00000, 0.96247 |
| 157 | proxy | 0.97057, 0.97057, 0.97057, 1.00000, 0.97368 |
| 158 | proxy | 0.98140, 0.98140, 0.98140, 1.00000, 0.98319 |
| 159 | proxy | 0.98984, 0.98984, 0.98984, 1.00000, 0.99074 |
| 160 | proxy | 0.99579, 0.99579, 0.99579, 1.00000, 0.99614 |
| 161 | proxy | 0.99917, 0.99917, 0.99917, 1.00000, 0.99924 |
| 162 | live | 0.56000, 0.56000, 0.56000, 1.00000, 1.00000 |
| 163 | live | 0.67125, 0.67125, 0.67125, 1.00000, 1.00000 |
| 164 | live | 0.76197, 0.76197, 0.76197, 1.00000, 1.00000 |
| 165 | live | 0.83425, 0.83425, 0.83425, 1.00000, 1.00000 |
| 166 | live | 0.89017, 0.89017, 0.89017, 1.00000, 1.00000 |
| 167 | live | 0.93185, 0.93185, 0.93185, 1.00000, 1.00000 |
| 168 | live | 0.96137, 0.96137, 0.96137, 1.00000, 1.00000 |
| 169 | live | 0.98083, 0.98083, 0.98083, 1.00000, 1.00000 |
| 170 | live | 0.99233, 0.99233, 0.99233, 1.00000, 1.00000 |
| 171 | live | 0.99796, 0.99796, 0.99796, 1.00000, 1.00000 |
| 172 | live | 0.99982, 0.99982, 0.99982, 1.00000, 1.00000 |
| 173–186 | live | 1.00000, 1.00000, 1.00000, 1.00000, 1.00000 |

Before reduced motion dimmed immediately at frame 0. At the unlock frame 118, the retained-card alpha was 0.99965 → 1.00000.

### After normal motion

| Frames | Owner | Slot alphas |
| --- | --- | --- |
| -1–0 | live | 1.00000, 1.00000, 0.56000 |
| 1 | live | 0.88875, 0.88875, 0.56000 |
| 2 | live | 0.79803, 0.79803, 0.56000 |
| 3 | live | 0.73112, 0.73112, 0.56000 |
| 4 | live | 0.67810, 0.67810, 0.56000 |
| 5 | live | 0.63735, 0.63735, 0.56000 |
| 6 | live | 0.60637, 0.60637, 0.56000 |
| 7 | live | 0.58410, 0.58410, 0.56000 |
| 8 | live | 0.57042, 0.57042, 0.56000 |
| 9 | live | 0.56324, 0.56324, 0.56000 |
| 10 | live | 0.56058, 0.56058, 0.56000 |
| 11–134 | live | 0.56000, 0.56000, 0.56000 |
| 135 | proxy | 0.56000, 0.56000, 0.56000, 0.82120, 0.82000 |
| 136 | proxy | 0.56000, 0.56000, 0.56000, 0.82748, 0.82000 |
| 137 | proxy | 0.56000, 0.56000, 0.56000, 0.83378, 0.82000 |
| 138 | proxy | 0.56000, 0.56000, 0.56000, 0.84179, 0.82000 |
| 139 | proxy | 0.56000, 0.56000, 0.56000, 0.85226, 0.82000 |
| 140 | proxy | 0.56000, 0.56000, 0.56000, 0.86323, 0.82000 |
| 141 | proxy | 0.56000, 0.56000, 0.56000, 0.87524, 0.82000 |
| 142 | proxy | 0.56000, 0.56000, 0.56000, 0.88923, 0.82000 |
| 143 | proxy | 0.56000, 0.56000, 0.56000, 0.90377, 0.82000 |
| 144 | proxy | 0.56000, 0.56000, 0.56000, 0.91848, 0.82040 |
| 145 | proxy | 0.56000, 0.56000, 0.56000, 0.93296, 0.82298 |
| 146 | proxy | 0.56000, 0.56000, 0.56000, 0.94683, 0.82788 |
| 147 | proxy | 0.56000, 0.56000, 0.56000, 0.95971, 0.83498 |
| 148 | proxy | 0.56000, 0.56000, 0.56000, 0.97127, 0.84408 |
| 149 | proxy | 0.56000, 0.56000, 0.56000, 0.98119, 0.85494 |
| 150 | proxy | 0.56000, 0.56000, 0.56000, 0.98921, 0.86727 |
| 151 | proxy | 0.56000, 0.56000, 0.56000, 0.99511, 0.88074 |
| 152 | proxy | 0.56000, 0.56000, 0.56000, 0.99874, 0.89500 |
| 153 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.90965 |
| 154 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.92311 |
| 155 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.93744 |
| 156 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.95103 |
| 157 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.96353 |
| 158 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.97409 |
| 159 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.98353 |
| 160 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.99100 |
| 161 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.99631 |
| 162 | proxy | 0.56000, 0.56000, 0.56000, 1.00000, 0.99931 |
| 163 | live | 0.56000, 0.56000, 0.56000, 1.00000, 1.00000 |
| 164 | live | 0.67125, 0.67125, 0.67125, 1.00000, 1.00000 |
| 165 | live | 0.76197, 0.76197, 0.76197, 1.00000, 1.00000 |
| 166 | live | 0.83425, 0.83425, 0.83425, 1.00000, 1.00000 |
| 167 | live | 0.89017, 0.89017, 0.89017, 1.00000, 1.00000 |
| 168 | live | 0.93185, 0.93185, 0.93185, 1.00000, 1.00000 |
| 169 | live | 0.96137, 0.96137, 0.96137, 1.00000, 1.00000 |
| 170 | live | 0.98083, 0.98083, 0.98083, 1.00000, 1.00000 |
| 171 | live | 0.99233, 0.99233, 0.99233, 1.00000, 1.00000 |
| 172 | live | 0.99796, 0.99796, 0.99796, 1.00000, 1.00000 |
| 173 | live | 0.99982, 0.99982, 0.99982, 1.00000, 1.00000 |
| 174–187 | live | 1.00000, 1.00000, 1.00000, 1.00000, 1.00000 |

After reduced motion dimmed immediately at frame 0. At the unlock frame 118, the retained-card alpha was 0.56000 → 1.00000.

**Cache swap pending native verification.** The production cache returns early in headless. The native Pass trace requires observing an active cache and compares its captured card modulation with the live controls on each active frame. It records `cache_first_draw`, `cache_tints_match`, and the cache sprite modulation alongside the frame strip. The existing lifecycle probe supplies the direct/cached/restored pixel comparison.

## 4. Turn-order projection and Objective

**Stale on release at both sizes.** The horizontal landing strip is disabled in production. Hovering Brace displays its projected hero portrait on the vertical rail. With five enemies and the hero, the full rail kept at least its at-rest horizontal clearance throughout the sampled frames. No slot step change was needed.

| Both builds, at 100% | Frames | Objective rect | Rail rect | Projected hero slot rect | Rail-to-Objective horizontal gap |
| --- | --- | --- | --- | --- | --- |
| 1920×1080 | -1 | [195.600, 520.448, 350.000, 70.000] | [1720.000, 82.000, 182.000, 741.156] | — | 1174.400 px |
| 1920×1080 | 0–23 | [88.491, 574.317, 350.000, 70.000] | [1720.000, 82.000, 182.000, 741.156] | [1815.680, 351.540, 76.320, 57.600] | 1281.509 px |
| 1280×800 | -1 | [24.000, 550.000, 350.000, 70.000] | [1080.000, 86.000, 182.000, 449.300] | — | 706.000 px |
| 1280×800 | 0–23 | [24.000, 545.180, 350.000, 70.000] | [1080.000, 86.000, 182.000, 449.300] | [1175.680, 355.540, 76.320, 57.600] | 706.000 px |

Rects are in viewport pixels as [x, y, width, height]. The rail's left edge is the conservative clearance used for the painted projection.

## Checks

| Check | Observed result |
| --- | --- |
| Headless capture dry-run | `POL-61 BASELINE HEADLESS: 0 fixture failures`, `POL-61 AFTER HEADLESS: 0 fixture failures` |
| Frame trace assertions | `before trace: 630 records, 48 projection frames, proxy-to-live max step 0.43917`, `after trace: 630 records, 48 projection frames, proxy-to-live max step 0.00069` |
| Python default group, 4 shards | `SELECTED MODULES: 21 of 57`, `Ran 192 tests in 36.222s`, `OK` |
| UI identity lint | `Ran 25 tests in 6.204s`, `OK` |
| Rules text lint | `Ran 3 tests in 0.066s`, `OK`, `PASS: Rules text lint (455 existing hits)` |
| Windows typed-array scan | `TYPED ARRAY SCAN: 3 scripts; 0 new; 0 pre-existing` |
| Retained hand content | `RETAINED HAND CONTENT TEST RESULT: PASS` |
| Turn-clock HUD | `PERF12 FOCUSED clock: 0 failures`, `PERF12 FOCUSED: PASS (0 failures)` |
| Existing hand hover suite, on release and patch | `HAND POINTER TEST RESULT: FAIL`. Both reported the same 13 assertions on the old layout, hover, and pointer fixtures. |
| Existing projection probe, on release and patch | `No selectable playable card available for turn order projection probe.` Both exited 1. |

The older hand and projection checks are unchanged. The new headless traces use real pointer events and a different combat fixture. Godot logged a macOS certificate-store diagnostic on both builds. The Python runner passed and reported that its optional Git timing cache could not be updated under the sandbox.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-61 && bash /private/tmp/labyrinth_codex/pol-61/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-61 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id pol-61 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --result-manifest /private/tmp/labyrinth_codex/pol-61/cache-lifecycle.json tests/locked_hand_cache_lifecycle_probe.gd
```

The first command records numbered PNGs every two frames in `/private/tmp/labyrinth_codex/pol-61/before/` and `/private/tmp/labyrinth_codex/pol-61/after/`. Each directory will also contain `frames.jsonl` and `manifest.json`. The native script defaults to the pristine sibling `release` checkout. Set `BASE_PROJECT` to another pristine checkout at the pinned release commit if the sibling moves. The lifecycle runner prints its isolated screenshot directory.

Native captures and cache pixels await the director's run because this sandbox has no macOS WindowServer access. The polish ledger reports five pre-existing failures in the cache lifecycle probe, including reused-target pixels, ancestor tint, and the fractional transform. That historical result was not rerun here.

## Chosen defaults

- Proof-only seed 77104, an eight-tile-square room, hero at (2, 5), crawlers at the fixture tiles, and 20 HP per actor. Three initial cards and two draws produce the three-to-five-card redeal. Five crawlers are queued at time 12 plus enemy ID for both projection sizes so the projected hero portrait is visible in the compact rail.
- The capture uses a nominal 60 FPS cap, 30 setup frames, 24 observation frames, a 720-frame turn allowance, and a 180-second native runner timeout. The probe positions the pointer using real card hit geometry. No production tuning values were selected.

## Design placeholders

None.
