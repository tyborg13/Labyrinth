# bos-02 implementation handoff

All changes remain uncommitted in `codex/bos-02`. No branch, queue, approval, review or publication state was changed. The owner-provided brief and boss rules draft were read without editing them. No assets were generated or changed.

## Contract and numbered requirements

1. **Vyraketh:** data installs Wildfire on Cinder Breath, spreading in all directions. Two Cinder Droplets occupy the existing helper slots. The secondary Fire-neighborhood action is removed. Half Health changes to every second source turn with the exact supplied sentence. Beat Fire has source ownership, Maw retires it, and Crownfire still selects only the remembered marks.
2. **Tharokh:** data installs the guarded length-5, Health-4 Upheaval every second player turn, changing to every player turn at half Health. Two Burrow Grubs use the helper slots. Stonewake retains its lane; its raise and the Claw/Breath pulses are removed. Faultline has radius 1 and consumes only enemy-owned Tharokh Outcrops. Saved `dragon_spire` terrain migrates to `crag_outcrop` with enemy ownership. `preserve_owned_terrain` still spares the source's terrain from attack damage; its flagged lanes retain the old sight geometry through its own stone. Movement still treats the Outcrops as solid, and other actors' stone still blocks the lane.
3. **Iskaldra:** data installs damage-3 Frostbite on Rime Talon, changing to every second source turn at half Health. Two Rime Spitters use the helper slots. Talon's trail rider is removed; Mantle, Shatterstorm and previous-trail replacement remain. The focused witness checks Mantle absorbs the beat and that an unarmored Iskaldra takes 3 without Freeze.
4. **Vaeloryx:** data installs clockwise Gust after each source turn, changing Push 1 to Push 2 at half Health. Two Gust Shrikes use the helper slots. The wake recorder, wake hit and persisted `dive_wake` are removed/dropped at load. Retained attacks are tested separately from the new Gust.
5. **Zekarion:** data installs damage-5, Chain-1 Lightning Storm on Overload, changing to Chain 2 at half Health. Wisps and Call Wisps remain. Both surface-snapshot riders are removed; Overload retains its shot 4.
6. **Noctyrax:** data installs Blink-3 Shadowstep on Void Claw for hidden Veilbound Acolytes only, without a half-Health change. The three player-anchored sweeps are removed. Existing helpers, summon, braziers and other attacks remain.

The first task-contract acceptance criterion is implemented and covered by focused production-routing tests. The second is covered by the matched 50-run measurement table; all values remain those in the brief. The owner must inspect the windowed evidence before accepting the visual portion of the contract.

## Files and deleted code

- `data/enemies.json`: only the six owned dragon entries; removed the named riders and added four helper rosters plus six instance bindings.
- `data/battlefield_rules.json`: one contiguous six-dragon block keyed by dragon id; exact panel sentences and half-Health declarations.
- `scripts/dragon_combat_rules.gd`: data installation, source-owned stone selection, old-save migration; deleted `spire_tiles` and `_approach_spire_tile`, the paired-raise declaration and their placement scoring.
- `scripts/combat_engine.gd`: dragon installation hook, Faultline ownership/radius routing; deleted `DRAGON_SPIRE_KIND`, `_enemy_raise_dragon_spires`, the unused `_dragon_spire_tiles`, its action dispatch and its special raise focus calculation.
- `scripts/dragon_pressure_fields.gd`: removed the player-anchor branch used only by the retired Noctyrax sweeps. The shared original nearest-brazier compatibility path remains.
- `scripts/committed_pattern_shapes.gd`: flagged Tharokh lanes ignore its source-owned Outcrops for sight only, matching the former spire geometry.
- `scripts/room_generator.gd`: reads the four approved helper rosters; the existing `(4,3)`, `(2,3)`, `(6,5)` slots remain intact.
- `scripts/progression_store.gd`: one dragon migration call at the existing owned load boundary. Current saves keep their existing numeric variants; legacy rider payloads are removed only from dragon intents. Removed-only held plans are discarded; retained Razor geometry stays held while both copies of its wake recorder are dropped. Historical analytics records remain untouched.
- Dragon tests: new `tests/suites/dragon_element_rules_suite.gd`, revised dragon boss/pressure/route/committed-pattern suites. Removed tests for the Fire/Ice/charge snapshot riders, paired spire setup and pulses, recorded Dive wake and player-anchored sweeps. Preserved retained-attack, retirement, Mantle, summon, reward and route-guard coverage.
- Deleted `tests/dragon_pressure_earth_breath_probe.gd` and its UID, which existed only for the removed Breath pulse. Deleted the obsolete `_thar_order_addendum` and its paired-spire/pulse assertions from the presentation probe. The warning probe no longer gathers removed-rider diagnostics; the Ice-pursuit comment now describes the retained attack. Existing boss/presentation probes use Upheaval Outcrops and the retained Stonewake/Overload action types. Both parse headless; their rendering remains unverified here.
- `tests/fixtures/bos02_dragon_sentences.json` copies the brief's six base and five half-Health sentences verbatim. The shared `battlefield_rules_suite.gd` now checks new dragon entries against this source while preserving its original table oracle for all other entries. The dragon suite also checks these approved strings independently of production data.
- Dragon-specific assertions/fixtures in the shared enemy-surface, surface-core and dragon-area suites now use the new payload and Outcrop identity. No Guardian implementation or summon implementation changed.
- `tools/dragon_rule_measurement{.py,.gd}` and `tools/dragon_rule_measurement_engine.gd`: unchanged meas-02 sampler and committed policy v2, with branch-local observation counters. Counts exclude speculative branches, boss deaths, and objective-cleared followers. Existing generic committed-action compatibility remains shared with Guardians and legacy engine callers; it was not redesigned.
- `tests/dragon_element_rules_probe.gd`, `tests/proof_contracts/dragon_element_rules.json` and one entry in `tests/windowed_test_allowlist.json`: 13 production-clock states and exact-resolution capture contract.
- `spec/card_balance_heuristic.md` and the dragon-only descriptive metadata in `tools/card_heuristic.py`: required enemy-checklist consistency update, removing descriptions of the retired riders and documenting the approved element rules. All 309 intrinsic card-score rows and coefficients are unchanged; Guardian metadata is preserved.

## Measurement and verification

The supplied provisional bands are 30–60% for elemental dragons and 15–40% for Noctyrax. After the change: Tharokh 72%, Vyraketh 18%, Vaeloryx 12%, Iskaldra 36%, Zekarion 22%, Noctyrax 12%. Only Iskaldra falls inside its band; the other five are flagged for the director. No numbers were tuned.

See `files-changed.txt` for the exhaustive file list. See `measurement.md`, `measurement.json`, `setup.json`, and `before/` / `after/` raw gzipped records. Baseline processes loaded the integration code/data before gameplay edits. Six independent runner processes use revision 7, first seed 1, 50 runs per dragon, the unchanged tier-3 deck and policy v2. Every raw result retains replay coordinates and branch-local beat metrics. Beat damage is the production event's resolution-time HP delta, including immediate force/ground consequences; later Fire ticks are outside that event. Beats and their damage are actual committed event totals; lieutenant kills exclude deaths attributed only to clearing the leader objective.

The task worktree initially lacked a `.godot` import cache. Final suite setup copies existing imported resources and the validated 96-entry global class registry into the ignored local cache from the integration worktree, then checks current import settings and source MD5s. `import-cache-validation.json` records 10,628 matching resources, zero stale copies, and unavailable optional/ignored imports. `global-class-cache-validation.json` binds every cached class to its current declaration. No editor scan or asset metadata edits were performed. The previously timed-out SFX partition passes alone with this setup.

Verification result lines are recorded in `verification.txt`. Logs are under `/private/tmp/bos-02-*.log` and `/private/tmp/bos-02-python-final/`. The native headless engine emits its existing macOS system-certificate error; this is separate from GDScript/test result lines.

## Proof for the design owner

These commands have not been run windowed. The sandbox has no window-server access. Capture paths will be printed as `BOS02 CAPTURE: .../dragon_element_rules_probe/<name>.png`; the runner manifest records the actual isolated HOME paths. The Noctyrax capture uses its actual depth 24; elemental capture launches use depth 4. The half-Health case displays the freshly accepted switch through the production banner adapter. No captured images are claimed by this handoff.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/visual_probe_runner.py --task-id bos-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/proof_contracts/dragon_element_rules.json --result-manifest /private/tmp/bos-02-dragon-rules-proof.json tests/dragon_element_rules_probe.gd
```

Playable fixtures, generated and verified before each windowed launch:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/inspection_fixture.py --task-id bos-02 --run-id bos-02-vyraketh --scenario dragon --dragon-id vyraketh --dragon-depth 4 --manifest /private/tmp/bos-02-vyraketh-fixture.json --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/inspection_fixture.py --task-id bos-02 --run-id bos-02-tharokh --scenario dragon --dragon-id tharokh --dragon-depth 4 --manifest /private/tmp/bos-02-tharokh-fixture.json --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/inspection_fixture.py --task-id bos-02 --run-id bos-02-iskaldra --scenario dragon --dragon-id iskaldra --dragon-depth 4 --manifest /private/tmp/bos-02-iskaldra-fixture.json --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/inspection_fixture.py --task-id bos-02 --run-id bos-02-vaeloryx --scenario dragon --dragon-id vaeloryx --dragon-depth 4 --manifest /private/tmp/bos-02-vaeloryx-fixture.json --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/inspection_fixture.py --task-id bos-02 --run-id bos-02-zekarion --scenario dragon --dragon-id zekarion --dragon-depth 4 --manifest /private/tmp/bos-02-zekarion-fixture.json --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/inspection_fixture.py --task-id bos-02 --run-id bos-02-noctyrax --scenario dragon --dragon-id noctyrax --dragon-depth 24 --manifest /private/tmp/bos-02-noctyrax-fixture.json --launch
```

Reproduce measurements and headless proof:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/dragon_rule_measurement.py --output-dir /private/tmp/bos-02-measurement/after --runs 50 --workers 6
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/godot_task_runner.py --task-id bos-02 --stream -- godot --headless --path . --script tests/dragon_pressure_mechanics_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/godot_task_runner.py --task-id bos-02 --stream -- godot --headless --path . --script tests/dragon_committed_patterns_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/godot_task_runner.py --task-id bos-02 --stream -- godot --headless --path . --script tests/dragon_spire_routes_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/godot_task_runner.py --task-id bos-02 --stream -- godot --headless --path . --script tests/battlefield_rules_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/godot_task_runner.py --task-id bos-02 --stream -- godot --headless --path . --script tests/dragon_element_rules_probe.gd -- --check-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/godot_task_runner.py --task-id bos-02 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/bos-02-python-final
```

## TODO_DESIGN placeholders

`TODO_DESIGN_DRAGON_GRIMOIRE_COPY` is recorded as a named data placeholder in `design-todos.json`. Nine existing entries in the unowned `data/grimoire.json` still refer to retired riders or need review of the remaining field description. Replacement reference prose was not supplied, and the unit owns no Grimoire file. The rule-panel sentences are the exact approved text. The owner must provide and integrate the reference-copy update in its owning unit.

## Chosen defaults

Only offline/debug values were chosen: task-specific output/observer key names; `ROUTING_TURN_LIMIT=24`, `PROOF_TURN_LIMIT=24`, `BANNER_CAPTURE_FRAMES=12`; and explicit test-only Outcrop positions/owners: owned `(2,4)`, player-owned `(6,6)`, foreign-owned `(7,6)` with actor id `999`, lane blocker `(3,3)`, and route-only blockers `(6,3)` / `(4,2)`. Fire ownership witnesses use `(3,5)` and `(7,2)`; the legacy save witness uses `(7,7)`. The capture contract reuses the existing board region `[300,120,1300,700]`, minimum luma range `8`, and luma standard deviation `2`. The proof reuses the existing boss suite's seed `74123` and 2,000-HP test hero so clock-based waiting reaches the beat. The legacy Overload test injects a damage-5 retired snapshot; the retained shot stays the authored 4. Elemental proof cases use depth 4 and Noctyrax uses its approved depth 24. The measurement retains the harness's six workers and 7,200-second process timeout; the capture command uses a 120-second proof timeout. These values do not enter gameplay data.

## Open issues

The final full Godot attempt exits 124 at the existing 900-second limit. Its main body executed 495,679 assertions in 723.039 seconds. All eight dragon programs exit 0, including the final 320-check pressure suite. Of the 247 program rows, 143 exit 0, three exit 1, three SFX programs time out at 180 seconds, and 98 are cancelled/not started when the parent is interrupted. Those cancellation rows are not passes. See `godot-suite-results.json`, `godot-program-results.json` and `godot-failure-evidence.json`.

An earlier complete execution ran all 247 programs in 829.519 seconds and reported 12 failures. Six were the new dragon entries missing from the older sentence-provenance oracle; the verbatim brief fixture fixes them, and both focused checks and the final main body now pass that gate. Remaining failures are in unchanged board-surface, encounter golden, locked-wind hash, summon tooltip, status-plate and registration checks. The standard-room golden hashes match when computed with the baseline CombatEngine and the bos-02 engine, and the baseline engine also fails the existing oracle. The two unregistered pt15 suites are unchanged. No assertions in these files were altered.

The final canonical Python invocation completed all 233 modules and 2,233 tests in 1,947.729 seconds: `FAILED (failures=9, errors=8, skipped=66)`, exit 1. Its four shards all completed normal cleanup. Remaining failures/errors are in unchanged Guardian rear-turn/frozen maquette inventories, summon tooltip copy, runtime-boundary assertions, program-manifest order and the two orphaned suites. No assertions in these files were altered. See `python-suite-results.json` for exact identifiers/tracebacks and `python-suite-summary.json.gz` for the complete summary. Earlier cleanup failures and the 71-test focused recovery are historical, superseded by this complete invocation.

The unowned Grimoire reference-copy TODO remains open; see `design-todos.json`.

Windowed captures and the design owner's inspection remain outstanding by the explicit sandbox/workflow split. The director owns any tuning indicated by out-of-band measurements. Commit, peer review, fixture acceptance and publication remain with the design owner.
