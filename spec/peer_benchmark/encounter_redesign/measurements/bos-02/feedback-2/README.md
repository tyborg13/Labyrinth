# bos-02 feedback 2 — final round

Starting HEAD: `3cbb7047a` (director-committed Round 1). This round changes only the director's Zekarion ladder, the approved Hollow Gale tooltip and associated validation/metadata. Preflight, contract and commit belong to the director. Changes remain uncommitted.

Zekarion's two additional matched cohorts finish at **26% (rung 4)** and **24% (rung 5)**, from accepted rung 3's 28%. Neither reaches the director's 30% minimum, so **rung 5 is retained**: HP 50 and direct Overload bolt 3. Lightning Storm stays 5 / Chain 1→2. Zekarion remains outside the provisional band; no further tuning is authorized.

| Dragon | Final rung | Final win rate |
|---|---:|---:|
| Tharokh | 3 | 58% |
| Vyraketh | 4 | 34% |
| Vaeloryx | 4 | 36% |
| Noctyrax | 2 | 32% |
| Iskaldra | unchanged | 36% |
| Zekarion | 5 (last authorized) | 24% — outside 30–60% |

The new cohorts use the same seeds, decks, revision and policy as the accepted cohorts. Lower damage/Health did not produce a monotonic policy-v2 win rate: half-Health switches rise from 28 to 33 to 35 across rungs 3/4/5. This is observed data, not a causal attribution. Full raw records are preserved.

## Acceptance evidence

1. **Zekarion:** matched revision-7, policy-v2, tier-3 deck, seeds 1–50. The new ladder starts from accepted rung 3. See `measurement.md`, raw `rungs/` files and measured enemy snapshots for results and the stopping decision. The Lightning Storm rule, helper entries, other five dragons and all nine Grimoire bodies are preserved.
2. **Hollow Gale:** the glossary and tt-01 short-copy registry contain exactly “Strikes everywhere within 2 tiles of Vaeloryx and Pushes struck actors 1 tile.” The registry records 14 words and cites bos-02 feedback 2. The former `TODO_DESIGN_HOLLOW_GALE_GLOSSARY_COPY` is resolved. Two old tooltip-retention checks now require the director-approved Grimoire bodies for Gale and Worldspines; every other former-definition retention check remains.
3. **Golden:** `tools/enc04_golden_audit.gd` reports `current_matches_frozen=true`. There are 54 rooms / 108 combat snapshots, with **zero dragon rooms**. The frozen golden is untouched; `golden-audit.json` records the count and hash.
4. **Program registry:** the dragon probe's `--check-only` invocation is in the ordered integration block and supplemental manifest. Its obsolete renderer-only exclusion is removed. All original registry guards and mutation checks remain intact. The new helper suites run through the existing dragon-pressure program; measurement scripts are developer harnesses rather than test entry points.
5. **Full suites:** see `verification.txt` and the saved suite reports for observed results and failure lists. No windowed execution was attempted in this sandbox.

## Final Godot gate and fixture corrections

The final full Godot attempt reaches the known 900-second budget and exits 124. Its main body reaches 495,806 assertions in 741.956 seconds, but its final failure list is not emitted. The child report has 154 passes, two performance failures, three local timeouts and 93 parent-interrupted rows. This is not a full-suite PASS.

All **29 isolated programs pass** afterward: 24 affected bos-02 programs, plus all five failed/timed-out full-run children. This includes dragon rules and forecasts, boss bar, clock, analytics, Grimoire, 845 tooltip checks, 2,671 measurement checks, the 13-state proof contract, surface rules and the dragon cutout tests. `standalone-results.json` records exact commands and observed result lines. `godot-failure-evidence.json` retains the original full-run failures without altering their assertions.

An initial diagnostic full run exposed five cutout guards still expecting pre-director Health, and inspection found the old Overload-4 surface expectation. Those expected numbers now match the approved rungs; initiative, rewards, identity and all other assertions are preserved. The old-save test explicitly supplies its legacy bolt 4 and continues to require that it survives migration. Two original tooltip retention checks now require the director's approved replacement bodies verbatim. The final full runs were started after these source corrections; no further source behavior changed.

## Final Python gate

The final full Python run completes all 234 modules and **2,250 tests in 2,112.712 seconds**, with **one failure, zero errors and 66 skipped**. The sole failure is the unchanged tracked-sidecar guard described below. All other executed tests pass, including the ordered-program mutation guards, measurement matching, exact copy and text-budget checks. Optional audio/Python-environment skips are recorded verbatim in `python-suite-results.json`. The runner's attempted Git timing-cache update is denied by the sandbox; it is a nonfatal warning after test execution, not another test failure.

## Sidecars and Git-index gate

The full Python run finds five missing tracked bos-02 `.uid` files from Rounds 0–1. They are now generated by `ResourceUID.create_id()` through the task-local headless runner, with no editor scan. Their exact paths and IDs are in `sidecar-validation.json`. The unchanged sidecar guard passes with the proposed committed inventory; **the actual tracked-inventory guard still requires the director to stage the five sidecars**. No Git index was changed or test assertion weakened. Recheck after director staging:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 -m unittest discover -s tests -p test_godot_sidecars.py
```

## Files and remaining work

`files-changed.txt` is the exhaustive manifest. Changes cover the two Zekarion fields; one glossary definition and its tt-01 approval; dragon-only balance metadata; exact-value/copy/provenance tests; ordered probe registration; five engine-generated UID sidecars; and this round's measurements and verification reports.

`TODO_DESIGN_HOLLOW_GALE_GLOSSARY_COPY` is resolved; no TODO_DESIGN placeholders remain for this round. Zekarion at 24% remains outside its band after the last authorized rung. Windowed proof is pending the director, and the full Godot completion remains limited by the observed budget. The sidecar guard needs director staging as part of the already-owned commit workflow.

## Proof for the design owner

The same production encounter/clock probe covers all six dragons on a beat turn and Vaeloryx's half-Health banner. Run at 1920×1080 and 100% UI scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/visual_probe_runner.py --task-id bos-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/proof_contracts/dragon_element_rules.json --result-manifest /private/tmp/bos-02-feedback2-fights-proof.json tests/dragon_element_rules_probe.gd
```

Expected captures (not produced here): `user://dragon_element_rules_probe/<dragon>_beat_warning.png`, `<dragon>_beat_result.png`, and `vaeloryx_half_health.png`. The runner prints the isolated absolute capture paths and writes its manifest.

Accepted Grimoire page proof remains available:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02 && python3 tools/visual_probe_runner.py --task-id bos-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/proof_contracts/dragon_feedback1_grimoire.json --result-manifest /private/tmp/bos-02-feedback2-grimoire-proof.json tests/dragon_pressure_grimoire_probe.gd
```

Expected pages: `user://probes/dragon_pressure_warnings/grimoire_<entry_id_with_underscore>.png`.

Playable inspection fixtures use ordinary Health and decks:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-02
for dragon_id in vyraketh tharokh iskaldra vaeloryx zekarion
do
  python3 tools/inspection_fixture.py --task-id bos-02 --run-id "bos-02-feedback2-${dragon_id}" --scenario dragon --dragon-id "$dragon_id" --dragon-depth 4 --manifest "/private/tmp/bos-02-feedback2-${dragon_id}-fixture.json" --launch
done
python3 tools/inspection_fixture.py --task-id bos-02 --run-id bos-02-feedback2-noctyrax --scenario dragon --dragon-id noctyrax --dragon-depth 24 --manifest /private/tmp/bos-02-feedback2-noctyrax-fixture.json --launch
```

## Chosen defaults

No gameplay defaults chosen. This round uses one measurement worker for the sole active ladder. All sampler/policy inputs, runner timeouts, test fixture coordinates, capture timing and debug-only proof Health are inherited unchanged from Round 1. No new art, icons, fonts or audio.
