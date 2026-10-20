# ui-03 implementation handoff

This follow-up is uncommitted on `codex/ui-03`. No commit, push,
branch change, peer review, publication, queue update or windowed launch was run.
Renderer inspection, peer review, the inspection fixture and publication belong
to the design owner under this unit's workflow split.

## Director feedback 2 (windowed review of 4b15ff5ff)

1. The scene now runs in a fixed 1920x1080 SubViewport displayed by a plain
   full-window TextureRect with `MOUSE_FILTER_IGNORE`. Every synthetic event
   enters that SubViewport. The existing cursor glyph is temporarily drawn
   there and follows only the synthetic pointer; desktop polling/input on its
   singleton is suspended for the capture. A regression sends root-only mouse
   motion over another card and verifies that neither captured hover nor cursor
   changes. No real mouse warp is used. Every press first routes pointer motion
   to its press point. MovieWriter still records the root. Director commits
   `61d02eaa6` (`--windowed` adapter) and `4b15ff5ff` (root viewport stretch) are
   preserved.
2. Routed pointer motion on the real RunScene root showed both native tooltips
   before the capture change: `hovered=true popup=true`. Their copy was missing
   the required plus sign (`Stagger 4`). The new exact-copy assertions failed
   before the fix; the seal now says `Empower: +2 Time · Stagger +4`, with the
   exact offered/charged instruction. Shared tooltip title capitalization stays
   unchanged. The capture waits for the actual embedded native popup and its
   rendered text, then a rendered frame and 0.4 seconds of visibility before
   continuing. Both gestures hold the offered and charged tooltips. Stills now
   include `charged_seal_tooltip.png` as well as `seal_hover_tooltip.png`.
3. Gameplay, approved assets, animation, root stretch, movie adapter and the
   other proof states are unchanged. The only production edit is the seal's
   positive Stagger bonus text.

Files changed in this round: `scripts/card_empower_controller.gd`,
`tests/card_keywords_visual_probe.gd`, `tests/proof_contracts/ui03_empower.json`,
`tests/suites/empower_seal_suite.gd`, new
`tests/suites/empower_seal_tooltip_suite.gd`, new
`tests/empower_seal_tooltip_test.gd`, new
`tests/helpers/ui03_capture_viewport.gd`, and this handoff. Logs and exact focused
results are in `output/ui03/feedback-2/RESULTS.md`. No full suites or windowed
commands were run. Headless `--verify-input` exercises the complete movie
choreography and native tooltip holds without rendering or writing captures.

New debug-only defaults: `FIXTURE_SEED = 60308`, `SETTLE_SECONDS = 0.25`,
`TOOLTIP_TIMEOUT_SECONDS = 3.0`, `TOOLTIP_TIMEOUT_FRAMES = 240`,
`POINTER_FOLLOW_EPSILON = 0.25`; `IDLE_POINTER = (1500, 650)` reuses the proof's
rest position. The 0.4-second visible hold is director-specified. There are no
remaining `TODO_DESIGN_` placeholders in this unit. Renderer confirmation of
the revised stills/clip remains the director's work. Commands below use fresh
feedback-2 manifests to preserve the previous proof records.

## Director feedback 1 (review of 75fc0bdcc)

Fixed with focused checks only; this follow-up remains uncommitted.

1. Right-stick Empower retains the mouse drag during modality handoff. InputRouter
   exposes the originating event only during synchronous modality notification;
   RunScene preserves the held gesture for Empower and routes it before normal
   controller navigation. Other controller actions still cancel the drag,
   including after an Empower handoff; neutral stick noise does not cancel it.
   The regression routes a mouse press/motion, a real right-stick event and the
   mouse release through `Input.parse_input_event`, then checks the empowered play.
2. A separate targetless test starts uncharged, charges mid-drag and commits the
   bonus and Time cost. Six live Quick Wits cases cover identical charged and
   uncharged survivors, fresh identical draws, immediate redraw and immediate
   reshuffle/redraw. They activate the skill through its hand-selection path and
   inspect committed hand order, skill use, deck cycles and each real seal.
   Guard-removal checks now detect both reported gaps: deleting the options
   refresh yields `CARD KEYWORDS TEST RESULT: FAIL (2 failures)`; deleting Quick
   Wits' charge clear yields `CARD KEYWORDS TEST RESULT: FAIL (10 failures)`.
   Each temporary mutation was restored in a `finally` block.
3. Removed the unused command text/cost/tooltip helpers and unused Router preload.
   Targetless and Crown tests assert actual seal tooltip text and charged state.
4. Renderer stills and movie remain queued for the director. Both windowed
   commands below are unchanged; neither was launched in this follow-up.

Feedback changes: `scripts/input_router.gd`, `scripts/run_scene.gd`,
`scripts/card_empower_controller.gd`, the keyword/Empower/Crown test suites, new
`tests/suites/empower_charge_departure_suite.gd`, and this handoff.

New debug-only defaults: `FIXTURE_SEED = 60307`, six named departure fixtures,
`ACTION_TIMEOUT_MSEC = 10000`, `ROUTED_DRAG_OFFSET = (20, 0)` and
`NEUTRAL_STICK_VALUE = 0.1`. No design values or approved assets changed.

Current focused logs and guard-removal evidence: `output/ui03/feedback-1/`.
The original implementation checks below are retained as historical evidence;
feedback checks are listed in `output/ui03/feedback-1/RESULTS.md`.

## Files changed

- `scripts/run_scene.gd`: Empower input, preview/commit integration, hand and
  proxy wiring, pointer/arrow handoff, charge-aware caches and tracker removal.
- `scripts/card_widget.gd`: seal, rim, mirrored anchor and independent seal input.
- `scripts/input_router.gd`: input-aware Empower glyph accessor.
- `scripts/card_empower_charge.gd`: transient charge per hand copy, explicit
  departures and turn-end clearing, including identical copies.
- `scripts/card_empower_controller.gd`: availability, health blocking, locking,
  input precedence, tooltip, widget synchronization and analytics.
- `scripts/card_empower_seal.gd`: authored `UiSocket` states and charge response.
- `scripts/card_empower_rim.gd`: static three-band blurred ember rim.
- `data/glossary.json`, `data/grimoire.json`: only the requested Empower copy.
- `spec/card_keywords.md`, `spec/analytics.md`: UI contract and additive event.
- `tests/suites/card_keywords_suite.gd`: seal assertions and regression entrypoint.
- `tests/suites/relic_u4_suite.gd`: Crown assertions for the new tooltip/summary.
- `tests/suites/empower_seal_suite.gd`: focused live input/state regression tests.
- `tests/card_keywords_visual_probe.gd`: required stills plus movie mode.
- `tests/ui03_movie_godot.sh`: adapter for Godot's built-in 60 fps AVI writer.
- `tests/proof_contracts/ui03_empower.json`,
  `tests/proof_contracts/ui03_empower_motion.json`: exact-resolution proof contracts.
- `tests/ui03_handoff.md` and `output/ui03/headless/`: handoff and observed logs.

The approved mockups and approved assets were inspected and left unchanged.
No art, icon, audio or font asset was created or downloaded.

## Numbered requirements

1. **Seal:** 66 layout pixels, mirrored from the Time badge's center anchor;
   approved nearest-filtered Empower icon at 52%; Crown-granted Empower uses the
   resolved card definition. Hover/selection/focus offer the seal; charge keeps
   it visible above neighboring card frames. Held and played proxies retain it.
2. **States:** authored fills, ring tints, ember blends, static halo and three
   blurred outer bands; blocked desaturation and crimson slash; no hover
   brightening when locked. Scale/flare response and instant reduced-motion
   change are implemented. Real-renderer appearance still needs owner inspection.
3. **Hint:** existing `E`, `RS`/`R3` glyph system; visible only on the raised card
   and hidden when blocked. Controller copy contains no `[E]`.
4. **Interaction:** real GUI clicks on both unselected and targeting seals,
   keyboard/controller precedence, mid-drag toggles, empowered drag-drop,
   targetless confirmation, deselect/reselect, surviving identical copies and
   turn-end clearing are tested. Iron Lung's remaining HP cost is checked
   against current HP. First target/orientation selection locks the choice.
   AoE rotation and force-aim survive toggles. The cursor returns over hand/HUD;
   the arrow hides off-board. The tracker has no Empower button/slot. Techniques,
   Rotate and controller prompts remain. Prepared caches skip charged copies.
5. **Text:** exact requested glossary definition and grimoire first line;
   grimoire second line preserved. Seal summaries reuse existing cost/bonus
   tokens with the requested device/state instructions and health-block text.
6. **Sound:** no audio changes or new cue. Existing card sounds remain.
7. **Analytics:** `empower_toggled` appends `{card_id, on, source, phase}` once per
   successful toggle, with all three sources and four phases covered. Blocked
   attempts emit no toggle. Existing `card_played` fields remain unchanged.

## Observed checks

All Godot commands used `python3 tools/godot_task_runner.py --task-id ui-03
--stream -- godot --headless --path . --script <entrypoint>`.

| Entry point/check | Exact result |
| --- | --- |
| `tests/card_keywords_test.gd` | `CARD KEYWORDS TEST RESULT: PASS` |
| `tests/card_keywords_w3_test.gd` | `CARD KEYWORDS W3 TEST RESULT: PASS` |
| `tests/relic_u1_test.gd` | `RELIC U1 TEST RESULT: PASS` |
| `tests/relic_u5_test.gd` | `RELIC U5 TEST RESULT: PASS` |
| `tests/cbt_01_test.gd` | `CBT-01 TESTS: PASS (0 failures)` |
| `tests/card_pool_overhaul_test.gd` | `CARD POOL OVERHAUL: PASS` |
| `tests/relic_u4_test.gd` (affected Crown assertions) | `RELIC U4 TEST RESULT: PASS` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests` / `OK` |
| `python3 -m unittest discover -s tests -p 'test_card_heuristic_keywords.py' -v` | `Ran 5 tests` / `OK` |
| `python3 tools/test_registration_audit.py` | `TEST REGISTRATION AUDIT: PASS (752 scripts; full suite=408, quarantined=29, windowed probe=315)` |
| `git diff --check` | exit 0, no output |
| JSON comparison to HEAD | `EMPOWER COPY SCOPE: PASS (only glossary definition and grimoire line 1 changed)` |

The production RunScene and focused suite passed headless `--check-only`
validation. The final still/movie probe also passed `--check-only`, through the
Godot runner, and `sh -n tests/ui03_movie_godot.sh` passed. No editor scan was used.
Full suites were not run, as explicitly directed in the unit's Proof section.

The macOS engine emitted `get_system_ca_certificates` diagnostics in headless
runs. Card-keyword and pool-overhaul runs also emitted an ObjectDB leak warning
in some runs; the final result lines above and runner exits were successful.
These diagnostics are preserved in the logs; they are not claimed fixed.

## Proof for the design owner

No renderer capture or clip has been run or visually inspected in this sandbox.
Run the following commands on the design owner's window-server-enabled machine.
The probe forces windowed 1920x1080, 100% UI scale and deterministic input family.

Required stills, plus controller and reduced-motion states:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ui-03 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/ui03_empower.json --result-manifest output/ui03/feedback-2/stills-manifest.json tests/card_keywords_visual_probe.gd --task-id ui-03
```

The probe prints the task-isolated absolute capture directory corresponding to
`user://probes/ui03/1920x1080_ui100/`:

- `hover_unlit.png`
- `seal_hover_tooltip.png`
- `charged_seal_tooltip.png`
- `charged_hand.png`
- `charged_targeting.png`
- `blocked.png`
- `charged_controller.png`
- `charged_reduced_motion.png`

The 60 fps clip uses Godot's built-in MovieWriter, with no encoder dependency.
The larger timeout accommodates fixed-frame movie writing:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ui-03 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --godot ./tests/ui03_movie_godot.sh --timeout 120 --expect-size 1920x1080 --proof-contract tests/proof_contracts/ui03_empower_motion.json --result-manifest output/ui03/feedback-2/movie-manifest.json tests/card_keywords_visual_probe.gd --task-id ui-03 -- --movie
```

Expected movie: `output/ui03/empower-interactions.avi`, 1920x1080 at 60 fps.
The sequence is hover → charge → drag-play, then click-select → charge through
its seal with targeting active → target. `clip_complete.png` is written to the
same task-isolated capture directory for validation.

The brief assigns the inspection fixture to the design owner and does not
request an `inspection_fixture.py` command for this implementation handoff.

## Design values (decided by the director)

- `CHARGE_RISE_SECONDS = 0.11`: the apex sits at half the 0.22 s response.
- `CHARGE_EASING_CURVE = Tween.TRANS_QUAD`: quad ease-out to the apex, then quad ease-in.

## Chosen defaults

Only implementation/debug/proof values were selected:

- `SEAL_Z_INDEX = 128`: internal child layer above the hand's emphasis layer.
- `DRAW_PADDING = 32.0`: rim draw envelope; its corner radius reuses the existing
  card glow's 18-pixel frame radius.
- `FIXTURE_SEEDS`: 60301–60306; existing keyword fixture cards plus debug-only
  two-target and rotatable-area fixtures.
- `SETTLE_FRAMES = 5`: headless GUI settling; original window size is restored.
- Proof data: `REST_POINTER = (1500, 650)`,
  `HOLD_FRAMES = 30`, `POINTER_TRAVEL_FRAMES = 36`,
  `PLAY_SETTLE_FRAMES = CLIP_FPS * 3`; all describe capture choreography only.
- Contract `regions`: hand area `[450, 650, 1050, 420]`, minimum luma range 65,
  minimum luma standard deviation 10; movie runner timeout 120 seconds.

## Open issues / owner work

- The director resolved the two animation details with the design values above.
- Run and inspect both renderer commands, including the five required states,
  controller state, reduced motion and the interaction clip.
- Perform the owner-assigned independent visual identity judgement, peer review,
  commit and verified inspection fixture before considering publication.
- Non-failing engine diagnostics above remain observable. No baseline assertions
  were weakened to hide them.
