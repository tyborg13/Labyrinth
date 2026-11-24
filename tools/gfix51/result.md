# gfix-51 verification

## 1. Scroll range reset

The release baseline was `38a6abf32` on `codex/release`. Its 18 creature pages overflowed at 1920×1080 and 100% UI scale. The fixture unlocked the release catalog and used Noctyrax, the Last Eclipse, as the final creature.

On Godot 4.6.1, a wheel event changes the scrollbar value and `ScrollContainer::_scroll_moved()` queues a sort. The reset happens in `ScrollContainer::NOTIFICATION_SORT_CHILDREN`. Its `_reposition_children()` calls `_update_scrollbars()`, which hides the bar and passes the cached `largest_child_min_size.height` of zero to `v_scroll->set_max()`. `Range::set_max()` clamps the page and value to zero. The list remains 1,244 px tall. [Godot scroll notification](https://github.com/godotengine/godot/blob/14d19694e/scene/gui/scroll_container.cpp#L425-L434) · [Scrollbar update](https://github.com/godotengine/godot/blob/14d19694e/scene/gui/scroll_container.cpp#L538-L555) · [Range clamping](https://github.com/godotengine/godot/blob/14d19694e/scene/gui/range.cpp#L213-L225)

```text
GFIX51 TRACE first wheel dispatched: rows=26 max=1244 page=356 value=452 visible=true
GFIX51 TRACE scroll pre-sort: rows=26 max=1244 page=356 value=452 visible=true
GFIX51 TRACE scroll post-sort: rows=26 max=0 page=0 value=0 visible=false
```

Page selection replaces the rows with the same total minimum height. The release trace emits no list minimum-size change between selection and the first scroll sort. Godot emits that signal only when the final minimum differs, and `ScrollContainer::get_minimum_size()` is what fills its cached child extent. The independent diagnostic sent the native sort notification without dispatching input and reproduced the reset. A direct minimum-size query followed immediately by the same sort restored the range. [Release input trace](../../output/gfix51/release-creatures.log#L13) · [Direct sort trace](../../output/gfix51/release-cache.log#L13) · [Control minimum-size dispatch](https://github.com/godotengine/godot/blob/14d19694e/scene/gui/control.cpp#L1545-L1557) · [ScrollContainer cache](https://github.com/godotengine/godot/blob/14d19694e/scene/gui/scroll_container.cpp#L36-L48)

```text
GFIX51 direct SORT_CHILDREN without input: viewport=356 content=1244 minimum=1244 max=0 page=0 value=0 bar=false
GFIX51 direct SORT_CHILDREN after minimum-size query: viewport=356 content=1244 minimum=1244 max=1244 page=356 value=0 bar=true
```

## 2. Scroll and focus

The [browse build](../../scripts/grimoire_panel.gd#L664) and [search reconciliation](../../scripts/grimoire_panel.gd#L704) call [`_refresh_grimoire_nav_minimum_size()`](../../scripts/grimoire_panel.gd#L1208) after the final rows are present and before the existing deferred scroll work. This gives Godot a minimum-size update even after a same-height rebuild. The scroll sort can then consume the refreshed extent through the normal layout path.

The fixture exercises all eight sections and all visible Magicks and Equipment group lists with the catalog unlocked. Its 68 trials use wheel buttons, thumb motion with the left mouse button held, Down Arrow, and D-pad Down. They check that selection opens the clicked page, retains its focus and nonzero scroll offset, and emits zero intermediate scrollbar range or visibility changes. At the end of the creature wheel and drag trials, Noctyrax's entire row was visible at scroll 888 of 888. [Fixed input trace](../../output/gfix51/fixed.log#L13)

## 3. Visual proof

The fix uses the existing list layout and scrollbar styling. The native launcher opens the creature list afresh for each capture and dispatches actual wheel or thumb events through the viewport after clicking a page in the top half. The headless dry run verified both capture states and the full final row rectangle at `(496, 736, 200, 44)`. [Dry-run log](../../output/gfix51/native.bKF0cT/probe.log#L13)

### Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-51 && bash tools/gfix51/native.sh
```

The launcher uses `LABYRINTH_CEL_LOOK=all` and validates each 1920×1080 PNG and its final-row region. It prints the paths individually under `output/gfix51/native.<run>/` and writes a `captures.json` manifest there. Windowed capture and visual inspection remain pending.

- `output/gfix51/native.<run>/wheel_end_1920x1080.png`
- `output/gfix51/native.<run>/drag_end_1920x1080.png`

## Receipts

Godot commands used `python3 tools/godot_task_runner.py --task-id gfix-51 --stream -- godot --headless --path . --script <script>`.

| Check | Exact result | Log |
| --- | --- | --- |
| Release `tools/gfix51/list_scroll.gd -- --creatures-only` | `GFIX51 SCROLL: FAIL (4 input trials, 0 capture states)` | [Release](../../output/gfix51/release-creatures.log) |
| Release `tools/gfix51/list_scroll.gd -- --diagnose-cache` | `GFIX51 direct SORT_CHILDREN without input: viewport=356 content=1244 minimum=1244 max=0 page=0 value=0 bar=false` | [Diagnostic](../../output/gfix51/release-cache.log) |
| Fixed `tools/gfix51/list_scroll.gd` | `GFIX51 SCROLL: PASS (68 input trials, 0 capture states)` | [Fixed](../../output/gfix51/fixed.log) |
| `tests/grimoire_search_probe.gd` | `GRIMOIRE SEARCH PROBE RESULT: PASS` | [Search](../../output/gfix51/search.log) |
| `bash tools/gfix51/native.sh --dry-run` | `GFIX51 SCROLL: PASS (2 input trials, 2 capture states)` | [Dry run](../../output/gfix51/native.bKF0cT/probe.log) |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.142s` · `OK` | [UI identity](../../output/gfix51/ui-identity.log) |
| `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir output/gfix51/python` | `INPUT GROUP default: always run` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 28.046s` · `OK` · `PASS: Rules text lint (16 existing hits)` | [Python](../../output/gfix51/python.log) |

## Chosen defaults

- The probe unlocks the existing catalog, uses reduced motion, and inherits the pre-battle fixture's first seed with an available fight. It selects the second page at a 24 px inset from the top of the viewport.
- The probe settles for eight layout frames and waits 0.35 seconds after selection. It caps wheel input at 180 events and uses at least eight drag steps, with enough extra steps to sample travel at half-page intervals.
- The PNG contract samples the final row and bar region and requires a luma range of 12 and standard deviation of 2.

## Open issues

- Native PNGs await the design owner's windowed run. The dry run printed candidate paths.
- Godot reported the host certificate-loading warning while the probes ran. The Python runner completed with exit 0 and an `Operation not permitted` notice for its shared timing cache under `.git`.
- There are zero design placeholders. The changes are uncommitted on `codex/gfix-51`.
