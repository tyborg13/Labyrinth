# atk-12 implementation and proof

The inherited `fed8b1702` WIP correctly identified non-Gust battlefield beats
without animation steps. `dispatcher.gd:fire` records `battlefield_rule_fired`
and resolves damage, but only Gust appends a presentation step. The scene applied
the ordinary attack losses, then adopted the completed activation's state without
presenting its remaining hero loss.

- Zekarion: Overload (`tempest_breath`) fires Lightning Storm. The saved witness
  records 5 Health damage from that rule after the ordinary 4-damage attack.
- Iskaldra: Rime Talon fires Frostbite. The witness records 3 Health damage from
  that rule beyond the attack's 11 damage. This is the authored rule, not an extra
  attack or a rules bug.
- Vyraketh: the old fastest-speed observer last sampled the `-6` at progress
  0.22, with no recorded overlap/occluder. Fresh targeted before/after replays
  reach the normal fade. Native proof remains required to decide conclusively
  whether the old report was only coarse headless sampling. No Vyraketh timing
  or drawing behavior was changed.
- Room Frostbite: a fresh seed-101 route found an unstepped turn-end hit as
  well. The saved hero is Chilled; the rule's 1 damage plus the existing Chilled
  bonus of 2 correctly loses 3 Health. The inherited WIP already presents it.
  The observer incorrectly used the *following* slice's frame as the beginning
  of its loss window, although its time window began at round start. The observer
  now records the correct start, and the classifier can recover it from old logs'
  round-begin rows without rewriting their data.

The WIP's three reconciliation call sites, receipt reporting, and strip speed
option are retained. The scene's helper moved to `scripts/hero_loss_playback.gd`;
it reuses the existing hero-loss entries, death hold, hit reaction and animation.
It also excludes losses owned by pending death Bursts. Rules, assets, constants,
analytics and saves are unchanged. There are no new permanent tests or design
placeholders.

## Observed results (2026-11-15)

- All 25 fresh receipt runs exited 0 and matched the baseline's outcome and
  decision limit. Baseline: 1,038 classified losses, four missing numbers
  (Zekarion 3, Iskaldra 1). Fresh: 959 losses, zero missing numbers at every
  setting. Two hunts took different routes; these totals are coverage evidence,
  not a controlled per-event comparison. Existing unclaimed Health numbers
  remain in the full reports (34 baseline, 35 fresh); targeted replays have zero.
- Controlled replays: Zekarion 1→0 missing; Iskaldra 1→0; room Frostbite 1→0;
  Vyraketh 0→0. All four complete resolved combat states are byte-identical
  before/after; hashes are in `current/resolved_state_comparison.json`.
- `FLOATING COMBAT TEXT TEST RESULT: PASS`
- `COMBAT FEEL TEST RESULT: PASS`
- `CARD BUFF PLAYBACK TEST RESULT: PASS (525 checks, 0 failures)`
- `STA01 PRESENTATION: PASS (668 checks; 0 failures; headless clocks only)`
- `Dragon committed patterns passed.`
- `ATK12 DRAGON PLAYBACK: PASS (49 checks, 0 failures)` (temporary entry point
  for the existing dragon area and exchange suites).
- `ATK12 RESOURCE PROOF: PASS (Health 3, Block 2, Stoneskin 1; idempotent; resolved state unchanged; completion boundary)`
- UI lint: `Ran 25 tests`, `OK`; approved-content manifest: `Ran 1 test`, `OK`.
- Python resource audit: `ISOLATION AUDIT: 56 modules`, exit 0; no new test
  modules were added. Strip `--check-only`, Python source compilation, and
  `git diff --check` exited 0. The first `py_compile` attempt could not write
  Python's external cache directory; in-memory source compilation passed.

Reports: `current/comparison.txt`, `current/{before,after}/summary.json`, and
`current/target-{before,after}/summary.json`. Full test suites were not run.

## Headless receipts

All outputs for this pass live under
`/private/tmp/labyrinth_codex/atk-12/current`. `before/` contains copies of
atk-10's **after** logs; their originals are untouched. Matching high-Health
limits are 900 decisions for normal seed 101, 600 for normal seed 102, and 400
for seed 101 at fastest / fastest+reduced / normal+reduced. Production-Health
seeds are 201–208 at normal and 201–204 at the other three settings.

From the task worktree:

```sh
python3 tools/atk12/proof.py prepare
python3 tools/atk12/proof.py receipts
python3 tools/atk08/receipts.py --root /private/tmp/labyrinth_codex/atk-12/current report --label target-before
python3 tools/atk08/receipts.py --root /private/tmp/labyrinth_codex/atk-12/current report --label target-after
python3 tools/atk08/receipts.py --root /private/tmp/labyrinth_codex/atk-12/current report --label before
python3 tools/atk08/receipts.py --root /private/tmp/labyrinth_codex/atk-12/current report --label after
python3 tools/atk08/receipts.py --root /private/tmp/labyrinth_codex/atk-12/current compare --before before --after after
```

Targeted before runs compile an in-memory copy of the integrated scene with
exactly the three atk-12 presentation calls omitted. The same production input
handlers, resolver, saves and observer run in both passes. Iskaldra replays
recorded decisions 635–648; the other cases use their original decision lists.
`final_state.txt` permits byte comparison of the complete resolved combat state;
`rule_fired` rows preserve the existing rule event as attribution evidence.

## Proof for the design owner

No native capture was attempted in the sandbox. Generate the exact commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-12 && python3 tools/atk12/proof.py native-commands > /private/tmp/labyrinth_codex/atk-12/current/native_commands.sh
```

Run the generated ten commands on a window-server-enabled machine:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-12 && sh -e /private/tmp/labyrinth_codex/atk-12/current/native_commands.sh
```

They use `tools/visual_probe_runner.py`, `tools/atk08/strip_movie.sh`, the fixed
30-fps MovieWriter clock, 1920×1080, 100% UI scale, and normal speed for all three
dragon cases and room Frostbite, before and after. Vyraketh additionally runs at fastest speed both ways.
After strips require their expected hero number; Vyraketh requires a sampled
progress of at least 0.8. Inspect the actual PNGs and their `manifest.json`, then
the validated `proof.json`. Output paths are
`current/native/<zekarion|iskaldra|vyraketh|room_frostbite>/<before|after>/<normal|fastest>/`.

After native runs, inspect recent Godot reports:

```sh
ls -lt ~/Library/Logs/DiagnosticReports | head -20
```

No `inspection_fixture.py` command is requested for this implementation unit;
the design owner owns fixture preparation, review, commits and publication.

## Chosen defaults (proof only)

- `QUIET_FRAMES = 8`, matching the existing strips; `IDLE_FRAME_LIMIT = 10000`.
- Replay and native watchdogs: named 300-second budgets.
- `STRIP_SECONDS = 20`; `STRIP_INTERVAL_SECONDS = 1 / 30` for native cel strips.
- `STRIP_REQUIRED_LIFE_PROGRESS = 0.8`, an evidence threshold, not an animation
  duration. Target seeds, expected amounts, and input indices come from receipts.
- The image-validity contract requires two images, luma range 8 and luma
  standard deviation 2, matching the workflow's sample contract.
- The temporary resource proof uses hero Health 10→7, Block 5→3 and Stoneskin
  4→3 at tile (2, 2). It is outside the repository and is not a permanent test.

## Known validation issue

`tests/guardian_feedback_playback_probe.gd` fails at line 90 while indexing an
empty `declared_tiles` array in its Cantor fixture; the probe is identical to
local master. The run was interrupted after that script error. Its assertions
and fixture were left unchanged. The separate dragon area/exchange suites pass;
the exchange suite intentionally injects an analytics acknowledgment failure
and emits that diagnostic while validating retry behavior.
