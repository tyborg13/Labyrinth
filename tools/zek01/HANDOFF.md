# zek-01 implementation handoff

All changes remain uncommitted. Publication, peer review and the inspection fixture belong to the design owner.

## Requirements

1. **Scatter:** `dragon_scatter_pattern.gd` selects the hero tile, four distance-2–3 tiles, then four floor candidates preferring distance ≤5. Enemy footprints and non-placeable floor are excluded. Marks have Manhattan separation ≥2. Each candidate preserves three unmarked floor destinations reachable in at most two cardinal floor steps. A short deterministic search avoids a greedy near-ring dead end. Candidate order is a local integer hash of the saved fight seed, declaration cycle and tile; no RNG advances. Declared tiles remain on the action and use the existing strike/surface resolver and FX. Exhausted or physically obstructed boards yield fewer marks rather than break spacing/safety. A board with fewer than three reachable floor destinations cannot satisfy the safety contract; no new board geometry is invented.
2. **Cycle:** the unique intent definitions stay unchanged; `cycle_order` references Skybreak twice. The engine resolves those ids in order, retaining array order when the dial is absent. Move lists continue reading the unique definitions. Existing analytics ids and Zekarion's battlefield instance remain unchanged. A legacy warning resolves verbatim once; when the next warning is declared, its old cycle index maps by id to the first corresponding new slot, preserving completed-cycle count: old `0/1/2/3` → new `0/1/4/2` (Skybreak/Lash/Overload/Call). The engine then advances one new slot. `dragon_cycle_order` makes this idempotent. New combats save `fight_seed`; legacy combats freeze their saved RNG state once as a compatibility seed without advancing it. Saved in-progress Health is preserved.
3. **Health:** authored max Health is 62. Storm Lash, Call Wisps, Overload, the battlefield rule instance, other enemy data, art, VFX and sound are unchanged. A data-scope comparison confirms exactly the four approved dials changed. The balance specification and scorer both encoded HP50 and now agree on HP62, nine marks and the five-slot cycle. Intrinsic card scores are identical to HEAD. The analytics specification had no HP/count encoding; it now documents the additive saved fields and unchanged id-based event semantics.

## Measurements

See `results/measurement.md`, `results/summary.json` and `results/fights.jsonl.gz`. The comparison uses section 1 / depth 4 for every dragon, eight archived ladder entry builds, and eight combat seeds per build, N=64 per cell. Other dragons' baseline cells are reused across scenarios because their data/rules are unchanged. The six Zekarion variants are measured independently with matched inputs. No tuning was performed. Zekarion wins: baseline 56.2%, pattern50 48.4%, HP56 39.1%, HP62 34.4%, HP68 32.8%, HP74 31.2%. All six Wilson interval half-widths are below 12 percentage points. There were no turn or decision caps.

Files changed are enumerated in `results/changed_files.txt`.

The damage audit is in `results/damage_audit.md`, `results/damage_events.json` and `results/audit.jsonl.gz`. The 56 qualifying losses include three self-Lightning Storm hits (15 Health) and one Retaliate hit (3 Health) on Zekarion; hero losses came from Wisps, the three dragon bolts, Skybreak and Fatigue. Actual screen observation is pending; the report distinguishes production presentation paths from observed rendering. No damage-presentation fixes were made.

## Headless verification

The exact observed result lines and logs are preserved in `results/verification.txt` and `results/logs/`. No full Python or Godot suite was run. No new Python test module was added; the suite resource audit was still run.

## Proof for the design owner

Run from this worktree. Cel variants are currently stale; rebuild the existing approved cel pipeline before capturing:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/zek-01 && python3 tools/cel_look.py build --if-stale
```

Native 1920×1080, 100% UI scale, cel look, production dragon fixture/resolver/playback:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/zek-01 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py tools/zek01/capture.gd --task-id zek-01 --no-headless --display-driver macos --audio-driver Dummy --rendering-driver opengl3 --expect-size 1920x1080 --proof-contract tools/zek01/proof_contract.json --result-manifest /private/tmp/zek01-native-proof.json --timeout 180
```

The script prints its isolated capture directory. Expected files:

- `01_opening_before.png`: original band7 telegraph, HP50, same fixture seed/build.
- `02_opening_after.png`: scatter9 telegraph, HP62.
- `03_opening_strikes.png`: actual opening playback at contact.
- `04_second_skybreak_wisps.png`: the second declared Skybreak with two Wisps alive.
- `05_second_strikes.png`: actual second Skybreak playback at contact.
- `06_overload_warning.png`, `07_overload_firing.png`, `08_overload_result.png`: existing Overload playback and field result.
- `witnesses.json`: actual declarations, resolver steps/states, beat receipt, seven-strike baseline timing and each new phase's playback/frame timings. Captured beats include PNG readback stalls; baseline timing does not.

This is staged coverage from the production dragon fixture. Boss turns are resolved directly; helpers remain alive but do not take independent activations. The probe protects Health during setup resolution and restores the entry Health for presentation. It advances the saved player-activation boundary between staged turns so previous ground is eligible fuel. It does not claim a naturally played encounter or player difficulty result. Existing field VFX are not fabricated. A renderer observation is required before claiming the nine strikes are within playback budget.

For the owner's interactive inspection fixture (the worker did not generate or launch it):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/zek-01 && python3 tools/inspection_fixture.py --task-id zek-01 --scenario dragon --dragon-id zekarion --dragon-depth 4 --dragon-build balanced --manifest /private/tmp/labyrinth-inspection-manifests/zek-01.json --summary 'Zekarion scatter9, repeated Skybreak and HP62' --launch
```

Reproduce collection and report, using a fresh measurement output directory:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/zek-01 && python3 tools/run_curve_dragons.py --zek01 --samples 64 --workers 6 --output-dir /private/tmp/zek01-repeat
cd /Users/borgerding/workspace/Labyrinth.worktrees/zek-01 && python3 tools/godot_task_runner.py --task-id zek-01 --timeout 0 --stream -- godot --headless --path . --script tools/zek01/measure.gd -- --inputs /private/tmp/zek01-repeat/inputs --output /private/tmp/zek01-repeat-audit.jsonl --first 0 --last 8 --audit
cd /Users/borgerding/workspace/Labyrinth.worktrees/zek-01 && python3 tools/zek01/report.py --input-dir /private/tmp/zek01-repeat --audit /private/tmp/zek01-repeat-audit.jsonl --output-dir /private/tmp/zek01-repeat-report
```

`--resume` retains completed cells and skips them without rerunning passing fights. The collection contract records source hashes, archived payload hash, policy hash, fixed schedule, and retained-cell provenance.

## TODO_DESIGN placeholders

None. No player-perceivable design values were invented.

## Chosen defaults

Measurement-only: section 1 / depth 4; eight existing ladder entry payloads; N64 (eight combat seeds per entry); six isolated workers. The 1,000,003 stride is inherited from the ladder tool. Output locations are task-local temporary paths. Timeouts are unbounded for the finite statistical sweep and 180 seconds for the known multi-phase windowed batch.

Proof-only named constants: existing fixture seed search start 7,262,026; depth 4; 12 settle frames; resolution protection Health 999; contact sample progress 0.55. Viewport 1920×1080 and UI scale 100% are required values, not defaults. Internal hash arithmetic uses mask 0x7fffffff, cycle multiplier 92821, LCG multiplier 1103515245/increment 12345, tile multipliers 68917/28307 and xor shifts 16/15. These are deterministic implementation details, with no gameplay RNG use.

## Open issues

Windowed captures, screen visibility/cause-label observations and strike-performance timings are pending on the design owner's machine. The worker has no window server and attempted no windowed launch. Full merge suites, peer review, commit and publication remain with the owner, as instructed. Physically impossible scatter budgets degrade to fewer marks while preserving safety/spacing; no geometry or enemy behavior was redesigned.
