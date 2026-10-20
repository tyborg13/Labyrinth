# rr-26 feedback 3 — shared tooling consolidation

The consolidation is implemented without changing paint, cuts, motion, poses,
continuation recipes or the director-resolved shadow cache. **Acceptance 7 is
not met:** the integrated rr-24 Thrall has two unmatched one-pixel components.
Acceptance 5 has one evidence limitation: Mirror has no committed full sample
record; its comparison uses a replay of the committed source. No native
renderer acceptance is claimed.

All edits remain uncommitted in the director's merge of `6077f772d` into
`c20cf94a7`. Conflict markers in `gates.py` are removed by editing; the index
still has unmerged entries for the director to stage. No Git-writing command,
peer review, full suite, windowed capture or inspection fixture was run.

## Numbered requirements

1. **Implemented.** `tools/humanoid_cutout/source_space.py` is the only source
   provenance classifier. `DetachedSource` uses whole approved-paint connected
   components, immutable ownership masks, exact source RGBA and the rigid
   owner's independent transform. Every unmatched component fails, including
   one dark pixel. `pocket_report` checks every pixel against every transported
   paint/tuck mask, even pieces absent from the rim. Independent joint tears
   fail. Source-space failures cannot be waived by historical frame/pocket
   exceptions. `rest_space.py`, `PaintedComponents`,
   `apply_painted_components` and the unused `unexplained_holes` helper are
   deleted. All native callers use one `native_errors` signature. Mirror's
   per-view `rigid_air` policy remains unchanged.
2. **Implemented.** Mortar and Mimic writers emit proof-relative
   `full_samples: {file, sha256}` pointers. `bone_evidence.read_report(case)`
   reads those or legacy full inventories. `load_samples`, `read_samples` and
   the redundant case reader wrappers are deleted; importers use `read_report`.
   Containment is the first operand, followed by existence and digest checks.
   The rr-21 mutation still removes that operand and catches both traversal and
   symlink escapes. Its cold fixture uses the incoming committed record only
   when the case does not yet exist in `HEAD` during this no-commit merge.
3. **Implemented.** Weaver uses `integration.json.action_adapter`; Mirror's
   former constant entry lives in its integration record. `Action.playback_adapter`
   tries the case adapter before the declared shared contact adapter. The one
   new dispatch site in `run_scene.gd` resolves `source_actor_key` with
   `actor_key` as fallback. Existing fallback paths and the single
   `after_step` boundary remain. `step_selectors` and
   `contact_playback_clips` retain their roles. No adapter timing, gameplay,
   cues or outcomes were edited. Ten routing checks and all seven unit runtime
   programs passed, alongside headless production playback.
4. **Preserved.** `gait_continuations.py` and
   `humanoid_continuations.gd` exactly match the merge-start hashes. No
   `active_recipe` value or figure layout was edited in this round.
5. **Observed identity; one baseline limitation.** All 7,628 original pose rows
   match, across 188 view/clip/kind inventories. Six units compare with
   committed records. Mirror's 968 rows compare with committed-source replay,
   explicitly labelled below. No pose row changed. Capacitor's new sampler
   additionally emits 1,024 production rows absent from its old record; every
   bone value matches its corresponding committed case row.
6. **Headless refresh implemented; native stages pending.** All seven current
   sample inventories, compact indexes, headless gates, strict censuses and
   production-logic scenarios were regenerated. Mortar's compact production
   records use the canonical pointer. Thrall's policy changes are only the two
   implementation digests for its migrated checkers; tuning is unchanged.
   Historical feedback reports retain their original evidence. Native,
   density-rest, idle-video and review evidence remains stale until the
   director executes the sequences below; it was not relabelled as current.
7. **Not met for Thrall.** Mimic, Seer, Mirror, Capacitor, Weaver and Mortar
   have zero unmatched detached components in both views, every clip. Thrall
   has the two components below. They were not exempted or repainted.
8. **Focused verification performed.** Unit Python sets, source/bone/gate
   tests, mutation controls and runtime programs were run. Older preservation
   assertions were left unchanged. Their failures and one Git-writing-fixture
   skip are recorded below. Dead readers/classifiers and dispatch copies were
   deleted. No full suite was run.

## Behavioural differences between the merged implementations

- Former `source_space.PaintedComponents` certified ownership from current cut
  textures. The canonical classifier uses immutable proof ownership, so a
  modified cut cannot earn a certificate.
- That former implementation tested alpha occupancy against a union of a
  piece's approved specks. The canonical implementation requires exact approved
  RGBA from a single original component, with the actual visible owner; a
  recoloured speck or a component assembled from multiple specks cannot borrow
  certification. Legal nearest-source sampling ties are checked explicitly;
  there is no positional or raster-error allowance.
- A missing independently sampled rigid transform now produces an unmatched
  component rather than the former direct dictionary lookup error. Skinned
  pieces and hidden fill still cannot supply rigid-speck certificates.
- The old source-space pocket check read red masks only. The former rest-space
  check read red **or green**; the canonical check retains both and the alpha
  guard, protecting tucks as required by §1. Both already checked all pieces.
- The former rest-space pocket function had no independent joint-tear input.
  The canonical function retains source-space's tear input, and native gates
  now supply it. A diagnosed joint tear cannot become an air pass.
- Historical detached/frame/exact-pocket exceptions could previously waive
  these source-space failures. The canonical gate excludes those two rule
  types from waivers. The historical loader, assertions and exception files
  remain unchanged for their historical users.
- Reports now have one API: detailed metrics, per-source-component
  certificates, exact unmatched pixel coordinates, per-piece pocket hits,
  painted/tuck totals and joint-tear flags. There is no post-hoc subtraction
  from a heuristic's exempted totals. The old outline metric helper remains
  only because other diagnostics use it; it supplies no provenance here.

The rr-26 strict `DetachedSource` behaviour itself is retained when moved from
`rest_space.py`. Compact pointer paths are now uniformly relative to `proof/`,
including Mortar's former case-relative paths. The reader still accepts legacy
full reports; no legacy compact pointer reader remains in production tooling.

## Pose identity

The reproducible [hash helper](rr26_pose_hashes.py) produces the complete
[before/after CSV](rr26_feedback3_pose_hashes.csv) and
[JSON](rr26_feedback3_pose_hashes.json). Both canonical hashes and raw JSON
object bytes are compared for every original row, excluding input-manifest
headers and whitespace outside the rows. Tiny float lexemes are preserved.
Every before and after hash in the table is equal; the CSV also contains raw
row hashes for each view/clip/kind inventory.

| Unit | Rows | Before source | Before SHA256 = after SHA256 |
|---|---:|---|---|
| Seer | 1,258 | committed `c20cf94a7` | `4340a4b6d04cfe67601467eb4f6882217ba9cf5db71821f8c39a8a13039b829d` |
| Thrall | 1,050 | committed `6077f772d` | `39502590d701f2aecfc7e216075602856a61cf4e130f7bd0071d99bfb459b066` |
| Mirror | 968 | committed-source replay `6077f772d` | `d1cf5cc80a3d3443e695ebd0f1e873b3a130f4b3ed16388bfc149679412fdff9` |
| Mimic | 1,008 | committed `c20cf94a7` | `48129fa8d69b8fd02faa943efd96b111e681bed4d1a1445e103128b1afdf5a37` |
| Weaver | 1,106 | committed `6077f772d` | `fcdc48131b1be5a426460fa5a935cf6921be3b28a825301f102968d9a78374a8` |
| Mortar | 1,214 | committed `6077f772d` | `b9f957a8a8154d4db27ff1251af505bf59cc846bb81a8729d82975eb32e31d13` |
| Capacitor | 1,024 | committed `6077f772d` | `fa86daf888ac7b53c7d296dfd6de1c2b463aefa851d51521f622f0eb6190c966` |

Weaver's and Mortar's ignored full records were missing. They were recovered
only after matching the **entire file** to their committed pointer hashes:
`d73f68da90a69afdcacdf9bbaeffcf7809e66e6bcf9edce5056527a76e6428cd`
and `807be8cd48a13287eef2c76a9a1c8b992ce2571995aa3dc771b660e4d0f07e2e`.
The recovery helper preserves raw float lexemes and rejects a mismatched hash;
its positive and tampered-row negative tests pass. Mortar's old input metadata
was recovered from committed `a1615e5673bec4730c3d36032fa36dcc2ac0aa5a`.
Mirror was sampled from the committed source snapshot, using the mandated
runner, and the temporary snapshot was removed. This supplies no missing
committed-record proof and is never labelled as one.

## Strict census and open Thrall findings

These are CPU estimates, not native renderer results. Full records live under
`rr20/proof/logs/rest_space/<unit>.json`; tracked
`rr20/proof/rest_space_summary.json` contains counts, failures and hashed
pointers. The summary command exits **1**, preserving the Thrall failures.

| Unit | Frames front / rear | Unmatched front / rear |
|---|---:|---:|
| Seer | 467 / 467 | 0 / 0 |
| Thrall | 335 / 335 | 0 / 2 |
| Mirror | 344 / 344 | 0 / 0 |
| Mimic | 362 / 362 | 0 / 0 |
| Capacitor | 348 / 348 | 0 / 0 |
| Weaver | 395 / 395 | 0 / 0 |
| Mortar | 431 / 431 | 0 / 0 |

| View / clip / frame | Presented pixels | Visible owner | Source texel / RGBA |
|---|---|---|---|
| Thrall rear / move / 14 | `(340,319)` | `mq7b_continuation_leg_far` | `(171,218)` / `[0,0,4,255]` |
| Thrall rear / move / 23 | `(323,269)` | `mq7b_continuation_leg_near` | `(109,179)` / `[15,5,6,255]` |

The independent rr-24 raster checker also fails two front joint-pocket frames:
`jab/22`, bounds `[282,248,283,250]`, 2 pixels; `death/31`, bounds
`[280,252,282,256]`, 7 pixels. Rear failures are the two detached components
above. These findings remain in `arc_thrall/rr24/checks.json`. Fixing their
paint/continuation ownership would exceed this round's unchanged-pose and
unchanged-continuation constraints. No exemption was added.

## Headless commands and evidence

Run each named stage with the [refresh driver](rr26_refresh.py); it invokes the
existing unit entrypoints, records exact child commands and exit codes, and
runs Godot only through the rr-26 task runner:

```sh
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py policy-bindings
```

For each of `seer thrall mirror weaver mortar capacitor`, in that order of
stages (rigs may run independently):

```sh
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py samples --rig UNIT
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py gates --rig UNIT
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py production --rig UNIT
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py census --rig UNIT
```

After all protected reference-record outputs settle, refresh Mimic's exact
authorized before/after ledger and run its stages:

```sh
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py coverage
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py samples --rig mimic
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py gates --rig mimic
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py production --rig mimic
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py census --rig mimic
python3 -B experiments/cutouts/hollow_mimic/rest_space_proof.py --summary
python3 -B experiments/cutouts/hollow_mimic/rr26_pose_hashes.py
```

The exact expanded commands, results and log hashes are in
[rr26_feedback3_verification.json](rr26_feedback3_verification.json).
Ignored execution logs are in `rr20/proof/logs/rr26f3/`.
Samples and headless gates pass for all seven. Production playback covers
Seer 1,441 frames; Thrall 923 per view; Mirror 949 per view; Weaver 1,263 per
view; Mortar 1,516 per view; Capacitor 1,011; Mimic 1,316 for each of six
view/card scenarios. All report `MAQUETTE PRODUCTION LOGIC: PASS`.
The strict census fails only Thrall. Additional current construction-diagnostic
commands and their observed result lines are in the same verification file.

## Focused tests

The verification JSON records each complete command and exact result lines.
The Python sets use `tests/rr20_regression_runner.py` to force inherited Godot
invocations through task `rr-26`. `--read-only-git` skips exactly the Mirror
fixture that creates and commits a disposable repository, honouring the
director's prohibition; it does not rewrite that fixture's assertions.

| Focused set | Observed result |
|---|---|
| Seer rr-10 files (11 modules) | `Ran 63 tests in 51.109s`; `OK` |
| Final Thrall rr-11/24 + Mortar rr-22/25 | `Ran 73 tests in 39.778s`; `OK` |
| Mirror rr-18/23 | `Ran 47 tests in 52.259s`; `FAILED (failures=2, skipped=1)` |
| Mimic rr-20/26 | `Ran 51 tests in 140.754s`; `OK` |
| Weaver rr-21 | `Ran 33 tests in 125.075s`; `FAILED (failures=1)` |
| Capacitor rr-17 | `Ran 31 tests in 81.727s`; `FAILED (failures=1)` |
| Shared rr-14 anatomy/bone/foundations | `Ran 17 tests in 2.876s`; `OK` |
| Canonical source/records + rr-21 containment mutation + historical exception tests | `Ran 29 tests in 1.898s`; `OK` |
| Final named source-test fixture constants | `Ran 10 tests in 0.237s`; `OK` |
| Historical rr-14 Seer identity + continuation domains | `Ran 4 tests in 0.038s`; `FAILED (failures=9)` |

Preserved failures:

- Mirror `test_shadows_retain_every_other_figure_against_pinned_baseline` and
  `test_shared_records_retain_every_other_figure`: integrated figures and the
  director-resolved registries/cache differ from the old single-unit pins.
- Weaver `test_prior_creature_assets_and_case_data_are_byte_identical`: the
  no-commit integration contains authorized prior-figure changes relative to
  `HEAD`. The cold review and containment mutation tests pass.
- Capacitor `test_shadow_baseline_is_explicit_and_portable`: the old baseline
  predates integrated Thrall/Mirror shadow records. Its assertion is intact.
  Against the frozen director-resolved merge cache, the unchanged shadow
  checker reports `RR17 SHADOW PRESERVATION: PASS (76 existing entries unchanged)`.
- The historical Seer identity test has nine failing file subtests against its
  older rr-14 pins. **All nine files already match feedback-2 `HEAD` exactly**;
  none was changed by this consolidation. The test's unconditional printed
  `RR14 SEER BYTE IDENTITY: PASS` is not a success: the actual result is
  `FAILED (failures=9)`. Its assertions remain untouched.

Direct runtime commands use
`python3 tools/godot_task_runner.py --task-id rr-26 --stream -- godot --headless --path . --script SCRIPT`:

| Script | Exact result line |
|---|---|
| `tests/rr10/runtime_checks.gd` | `RR10 RUNTIME: PASS (10 checks; headless logic only)` |
| `tests/rr11/runtime_checks.gd` | `RR11 RUNTIME: PASS (5722 checks; headless logic only)` |
| `tests/rr18/runtime_test.gd` | `RR18 RUNTIME: PASS (5964 checks; headless logic only)` |
| `tests/rr20/runtime_checks.gd` | `RR20 RUNTIME: PASS (5323 checks; headless logic only)` |
| `tests/rr21/runtime_checks.gd` | `RR21 RUNTIME: PASS (243 checks; headless registration and action clocks)` |
| `tests/rr22/runtime_checks.gd` | `RR22 RUNTIME: PASS (478 checks; headless logic only)` |
| `tests/rr17/runtime_test.gd` | `RR17 RUNTIME: PASS (58 checks, 0 failures; headless logic only)` |
| `tests/rr26/action_dispatch.gd` | `RR26 ACTION DISPATCH: PASS (10 checks; case priority, contact fallback and unchanged existing paths)` |
| `tests/rr21/continuation_checks.gd` | `RR21 CONTINUATION TEXTURES: PASS (3072 full-image checks; source/production, paint/masks, both views, repeated transitions)` |

All seven native capture programs also loaded headlessly with `--validate-only`;
these are load checks, not renderer captures. Registration audit:
`TEST REGISTRATION AUDIT: PASS (751 scripts; full suite=407, quarantined=29, windowed probe=315)`.
Existing macOS CA-certificate and teardown resource warnings remain in logs;
they are not hidden or relabelled as script failures.

## Proof for the design owner

These exact script stages refresh native gates, production, density-rest and
review records at **1920×1080, 100% UI scale** through the existing visual
runner/contracts. They were not run here. Stop on a failed stage; Thrall's
strict findings may prevent native acceptance. No `inspection_fixture.py`
command was requested; the director owns fixture preparation.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26
export LABYRINTH_TASK_ID=rr-26

for stage in density rest native sheets idle production review; do
    sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh "$stage" || exit "$?"
done

for stage in density rest native sheets idle production review crops; do
    sh experiments/cutouts/arc_thrall/rr24_proof.sh "$stage" || exit "$?"
done

for stage in density rest native sheets move contacts idle production review; do
    sh experiments/cutouts/glacial_mirror/rr18_proof.sh "$stage" || exit "$?"
done

for stage in density rest native sheets idle production review; do
    sh experiments/cutouts/briar_weaver/rr21_proof.sh "$stage" || exit "$?"
done

for stage in density rest native sheets walk idle production review; do
    sh experiments/cutouts/slag_mortar/rr22_proof.sh "$stage" || exit "$?"
done

RR17_SHADOW_BASELINE="$PWD/experiments/cutouts/hollow_mimic/rr20/proof/logs/rr26f3/director_resolved_shadow_cache.res" \
    sh experiments/cutouts/storm_capacitor/rr17_proof.sh

# Reference records must settle before binding Mimic's protected-input ledger.
python3 -B experiments/cutouts/hollow_mimic/rr26_refresh.py coverage
for stage in density rest native sheets idle production review; do
    sh experiments/cutouts/hollow_mimic/proof.sh "$stage" || exit "$?"
done
```

Capacitor's script is one complete sequence, with no stage argument. Its new
optional baseline input selects the exact pre-existing merge cache instead of
the default historical pin; the preservation checker and default pin are
unchanged. The frozen fixture SHA256 is
`75f8808dcc54342d43b78a1b81eb451eef7e4972488063e909be60a1923675e8`.
It is already available at the command's ignored path in this worktree.

Capture roots are the following case directories plus `proof/`:

| Unit | Case | Capture/review paths under `proof/` |
|---|---|---|
| Seer | `hoarfrost_seer/rr10` | `native_rest/`, `native/`, `contact_sheets/`, `idle_native/`, `production_native/`, `hoarfrost_seer_review.mp4` |
| Thrall | `arc_thrall/rr11` | `native_rest/`, `native/`, `contact_sheets/`, `idle_native/`, `production_native/`, `arc_thrall_review.mp4`; `rr24_crops/` |
| Mirror | `glacial_mirror/rr18` | `native_rest/`, `native/`, `contact_sheets/`, `gait_move_native/`, `rr23_native_crops/`, `idle_native/`, `production_native/{front,rear}/`, `glacial_mirror_review.mp4` |
| Mimic | `hollow_mimic/rr20` | `native_rest/`, `native/`, `contact_sheets/`, `idle_native/`, `production_native/{front,rear}/{whirlwind_slash,quick_stab,hurl_spear}/`, `hollow_mimic_review.mp4` |
| Weaver | `briar_weaver/mq9` | `native_rest/`, `native/`, `contact_sheets/`, `idle_native/`, `production_native/{front,rear}/`, `briar_weaver_review.mp4` |
| Mortar | `slag_mortar/rr22` | `native_rest/`, `native/`, `contact_sheets/`, `gait_move_native/`, `idle_native/`, `production_native/{front,rear}/`, `slag_mortar_review.mp4` |
| Capacitor | `storm_capacitor/mq5` | `native_rest/`, `native/`, `production_native/`, `storm_capacitor_review.mp4` |

After every unit's density stage has settled, repeat the headless refresh in
this document: density seals can change bound derived metadata. Refresh
Mimic's exact authorized ledger only after reference records settle; never
rebind a native capture's inputs. Rerun a native stage if its provenance is
stale.

## Files changed, defaults and remaining issues

The exact worker file inventory is in the verification JSON. Shared changes
are `tools/humanoid_cutout/{source_space,bone_evidence,gates,integration}.py`,
deleted `rest_space.py`, `scripts/maquette_cutout_runtime/{action,presentation}.gd`
and the single dispatch site in `scripts/run_scene.gd`. Case changes are
adapter metadata, reader/writer import migrations, task-runner propagation,
Thrall implementation-digest refresh and derived headless records. Tests are
the focused rr-20/21/22/26 migrations, the rr-18 routing assertion, the rr-20
sampler and new rr-26 routing/hash-recovery checks. New rr-26 evidence helpers,
tables and this handoff live beside the Mimic case. Resolved registry/cache/
`cutout_context.gd` changes belong to the director's merge, not this worker.

`TODO_DESIGN` placeholders: **none introduced or unresolved by this round**.
The open Thrall problem is a scope conflict, not an invented design policy.

Chosen defaults are proof-only named fields: `TASK_ID='rr-26'` and the
`SCRIPTS`/`GATES`/`RIGS` path maps in `rr26_refresh.py`;
`PROOF_TIMEOUT_SECONDS=180` reuses the existing headless timeout;
`FIXTURE_TINY_BONE_NUMBER='0.000000000465661287307739'` is an observed sampler
lexeme; `FIXTURE_GATE_FRAME=0` and
`FIXTURE_GATE_POCKET={bbox:[2,2,4,4], pixel_count:4}` exercise exception
rejection. Baseline revision/path fields are recorded in the ignored baseline
manifest and pose table. No player-visible value was chosen.

Remaining issues are Thrall's two strict detached failures and two independent
front seam findings, Mirror's missing committed full sample baseline, the
preserved historical/integration test failures, the prohibited Git-fixture
test, and pending director windowed proof. No claim of all-green acceptance
or fresh native proof is made.
