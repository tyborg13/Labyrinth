# pol-66 skill tree link emphasis

## Acceptance

1. Direct prerequisites and dependents draw above the other links with 3 px ember rails and ember arrowheads. The ember glow has alpha 0.30 and is 9 px wide. The dark under-strokes retain their existing colours and alpha.
2. Ancestors draw in bright gold at 2.5 px with zero glow.
3. Unrelated rails, end caps, arrowheads and under-strokes draw at alpha 0.55 while focused. Learned, available and locked links retain their state colours and widths. The synthetic no-focus case matches the baseline.
4. Hover uses the same focus handler as click and GUI navigation. The probe sends mouse motion, mouse clicks, keyboard and D-pad events and checks the focus and both link layers before the next frame.
5. The baseline and updated runs agree on all 32 routes, 29 node rectangles, and six bridges at both resolutions. The probe also samples the learn confirmation stroke at the same strength on both revisions and checks its width and warm colour.

| Skill | Incoming ember | Outgoing ember | Bright gold ancestors |
| --- | ---: | ---: | ---: |
| Quick Wits | 0 | 5 | 0 |
| Living Shadow | 2 | 1 | 2 |
| Open Sky | 2 | 0 | 4 |

## Headless proof

[Before](</private/tmp/labyrinth_codex/pol-66/skills.vNiPiHQh/before.log>) and [after](</private/tmp/labyrinth_codex/pol-66/skills.vNiPiHQh/after.log>) log each route's relationship, state, sampled rail and arrowhead colours, alpha and width. The probe records the draw commands submitted by both layers. The mixed ownership case exercises teal available links and gold learned links at the same faded alpha.

```text
POL66 before HEADLESS: PASS (3020 checks, 0 failures)
POL66 D-PAD 1920x1080: 20 moves, 21 distinct nodes, _rebuild_link_geometry 2 -> 2, max synchronous input 7893 us, max input to next headless frame 41053 us
POL66 D-PAD 1280x800: 20 moves, 21 distinct nodes, _rebuild_link_geometry 2 -> 2, max synchronous input 5642 us, max input to next headless frame 22194 us
POL66 after HEADLESS: PASS (4550 checks, 0 failures)
POL66 GEOMETRY COMPARISON: PASS
```

## Focused checks

| Check | Observed output |
| --- | --- |
| Existing skill tree data and topology suite | `SKILL TREE SUITE: PASS (387 checks, 0 failures)` |
| Existing skill UI suite, both branches | `SKILL UI TEST: FAIL (20)` |
| UI identity unit tests | `Ran 25 tests in 4.823s`, `OK` |
| UI identity lint | `PASS: UI identity lint (1502 sites within baseline + exceptions)` |
| Changed-script typed-array scan | `TYPED ARRAY SCAN: 5 scripts; 0 new; 0 pre-existing` |
| Python default group | `Ran 192 tests in 74.695s`, `OK` |
| Rules text lint, included in the Python default group | `PASS: Rules text lint (455 existing hits)` |

The skill UI failure messages matched on both runs after normalizing the measured Encore durations. The failures cover analytics, a hand-selection pointer hit and the Encore reduced-motion timing assertion. [Baseline log](</private/tmp/pol66-skill-ui-before.log>) · [Updated log](</private/tmp/pol66-skill-ui.log>) · [Skill tree suite log](</private/tmp/pol66-skill-tree.log>) · [Python default group log](</private/tmp/pol66-python-default.log>)

## Proof for the design owner

Run this in a macOS session with a window server.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-66 && /private/tmp/labyrinth_codex/pol-66/native.sh
```

The launcher prints a fresh folder and captures the same combat fixture from the sibling `scn-02` and the current worktree. At 100% UI scale it writes `before/<size>_<skill_id>.png` and `after/<size>_<skill_id>.png` for all three focuses at 1920×1080 and 1280×800. The runner writes `before.json` and `after.json` after PNG validation.

The headless equivalent exercises the shared fixture, view, geometry and link checks and emits logs.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-66 && /private/tmp/labyrinth_codex/pol-66/native.sh --dry-run
```

## Chosen defaults

- Probe settle delay is 80 ms, matching the existing skill tree visual probe.
- The learn pulse sample uses strength 0.5. The synthetic mixed ownership case learns Quick Wits and Rehearsed Escape.
- The combat backdrop reuses census seed 7262026 and its four-enemy fixture.

## Open items

- Real-renderer PNGs and visual inspection await the design owner.
- The broader skill UI suite has 20 reproducible baseline failures.

`TODO_DESIGN_*` placeholders: none.
