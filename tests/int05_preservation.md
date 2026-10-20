# int-05 preservation sweep

Scope: tests and preservation helpers only. The design owner owns commit,
review, inspection and publication. Changes are left uncommitted.

## Acceptance and implementation

1. `test_rr14_seer_identity.py` checks rr-14's range from
   `66d07be81f36d10106b1a2548f5c8a08fe3364c5` (the result of
   `git merge-base e08e4e296^1 e08e4e296^2`) through its final unit head
   `5a97e2b28bccd407a970dc0bfda4beb70fc11ea9`. It uses the int-04
   `unit_preservation.changed_paths` and `read_bytes` helpers.
   All 775 fully protected paths remain forbidden changes, including deletions
   and renames. The two binding-only files are compared as raw endpoint bytes
   after replacing only their top-level `inputs` object with `{}`. Nested
   payload fields and serialization outside that object remain protected.
2. `tests/rr14/seer_identity.json` retains exactly the original 777 paths,
   now as an inventory with no hashes. Its paths match both the original
   rr-14 delivery and int-03's re-pinned ledger. `refresh_bindings.py`, the
   only other ledger consumer, now verifies the original range-base payload
   directly before rebinding. No live Seer file, approved value or asset changes.
3. `test_int05_preservation.py` calls the actual rr-14 test assertion with
   disposable committed ranges. An injected Seer edit is rejected even after
   a later commit repairs it; live working bytes cannot affect either endpoint.
   Additional negatives cover deletion/rename, nested payload changes and
   non-binding serialization. A positive allows binding-only changes. The
   rebinding helper accepts the new inventory and refuses altered payloads.
4. Focused checks and both full suites are recorded below. Each full suite is
   invoked once, after the executable patch and focused checks are complete.

## Re-pinned guard audit

The sweep follows hash-update history, not just current ownership labels.
It covered Python, GDScript, shell and JSON under `tests`, `experiments`,
`tools` and `spec`. Literal-hash and preservation searches were paired with
`git log -G '[0-9a-f]{64}'` on pin files and source-history searches for
`sha256`, `spec_hash`, `byte_identical`, `preserv`, `protected` and `baseline`.
The ledger-name scan included 663 hash-bearing files; a second scan added
211 JSON files with production/case/maquette paths regardless of ledger name.
The source-history scan covered 1,417 test/audit/preservation files, including
checks whose expected values are loaded or computed rather than literal.

### Converted in int-05

| Check / pin file | Hash-update evidence | Result |
| --- | --- | --- |
| `test_rr14_seer_identity.py` / `rr14/seer_identity.json` | Introduced by `fcae304f3`; `e78aaba78` (int-03) re-pinned Seer layouts and proof records to rr-26, without changing the 777-path inventory. `git log -p -- tests/rr14/seer_identity.json` shows both versions. | Converted to rr-14's fixed range; no today's-tree hash pins remain. |

No additional unconverted re-pinned cross-unit figure guard was found.

### Rechecked histories and exclusions

| Candidate | History / ownership evidence | Disposition |
| --- | --- | --- |
| Mimic `rr20/protected_inputs.json` | `92d696798`, `1a2928ed8`, `901d32789` change the ledger; it includes prior Seer/Thrall files. | Already converted by int-04: `rr20_preservation.py` checks `73e076bfb..901d32789`; only Mimic's own inputs remain live pins. |
| Maquette compiled-spec and regeneration guards | mq-07/08/09/10 receipts were updated during their own revisions; consumers include `test_arc_thrall_maquette_r2.py`, `test_glacial_mirror_shoulder.py`, `test_mq09_maquettes.py`, `test_mq09_forms.py` and `blender/test_creature.py`. | Already converted by int-04, including foreign recipe/report range checks and historical compiler inputs. Original receipts remain unchanged. |
| Seer rear-turn `protected_sha256.json` | Other-figure pins consumed by feedback-4/5 audits. | Already historical through `rear_turn/preservation.py` at `57d2abd81`. |
| Weaver, Mirror and Thrall foreign scope guards | `test_rr21_cutout.py`, `rr23_preservation.py`, `rr24_preservation.py`; int-03/int-04 history inspected. | Already fixed ranges; Mirror exact-hash exceptions read endpoint blobs. |
| Thrall `rr24/repaint_baseline.json`, rr-15/24/27 consumers | Recorded/revised by `7cdcebb1e` and `9f67d441d`; rr-27 has an exact continuation-removal exception. | Own-figure repaint/geometry/motion contracts, not a foreign-figure freeze. Existing values and assertions retained. |
| `test_gait01.py` | rr-24 added the Thrall repaint helper in `7cdcebb1e`; the scope check uses `80d5ec39b..4b3f74830`. | Already range-scoped. That fixed range contains no PNG changes, so its repaint loop consumes no rolling figure hash. The unused old `gait01/preservation.py` helper has no callers. |
| Capacitor `mq5/protected_inputs.json` | `fd3acba61`, `0a58619d1`; four pins are Capacitor painting/director/masks. | Own-figure guard. |
| Mortar `rr22/proof/protected_inputs.json` | `5cb8fd438`, `100919e97`, `f5202d620`; paths bind Mortar maquette/paint/director inputs. | Own-figure guard. |
| Gaoler/Shrike/Bloomer/Wisp `baseline.sha256.json` | Own rig revisions, then capture-reader migrations (including `6e76ac2b6` / `126a567c3`). | Per-case delivery seals, not preservation of another unit's figure. |
| `tests/maquette_cutout/alpha_fixtures/manifest.json` | `9b108eac1`, `20cad186f`; source-alpha/native fixtures for the pipeline's owned rigs. | Own delivered fixture references. |
| Native/density/identity registries and proof manifests | Updated by their figure's delivery/capture stages; blanket pin consumers inspected. | Own receipt validity and operation-local before/after preservation. Foreign fixed freezes already use the historical guards above. |
| UI/map/splash/music hashes, synthetic fixtures | No foreign figure-preservation contract. | Outside scope. |

Audit scratch records: `/private/tmp/int05-hash-history.json`,
`/private/tmp/int05-additional-ledger-history.json` and
`/private/tmp/int05-guard-history.log`.

## Verification

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/int-05`:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-05 && python3 tools/output_gdignore.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-05 && LABYRINTH_TASK_ID=int-05 python3 -m unittest discover -s tests -p 'test_rr14*.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-05 && LABYRINTH_TASK_ID=int-05 python3 -m unittest discover -s tests -p 'test_int0*_preservation.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-05 && LABYRINTH_TASK_ID=int-05 python3 -m unittest discover -s tests -p 'test_*.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-05 && python3 tools/godot_task_runner.py --task-id int-05 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

Observed focused results:

- rr-14: `Ran 21 tests in 2.748s` / `OK`, including
  `RR14 RUNTIME: PASS (246 checks; headless synthetic anatomy and foot IK)` and
  `RR14 SEER RANGE IDENTITY: PASS (777 files; only two input-binding objects excluded)`.
  Log: `/private/tmp/int05-focused-rr14.log`.
- int-04/int-05: `Ran 18 tests in 13.303s` / `OK`, including
  `INT05 SEER RANGE MUTATION: PASS (in-range edit caught; later commits and working bytes ignored)` and
  `INT05 BINDING MUTATION: PASS (top-level inputs allowed; nested payload change rejected)`.
  Log: `/private/tmp/int05-focused-preservation.log`.

- Inventory verification: `INT05 ORIGINAL INVENTORY: PASS (775 protected paths, 2 binding-only paths; exact rr-14 inventory)`
  and `INT05 RANGE BASE: PASS (exact merge-base required by brief)`.
- Godot full suite, once: `FULL SUITE RUNTIME: 550.481 seconds (budget 900 seconds)`;
  `TEST RESULT: PASS`; exit 0. Main body: `378990` assertions in
  `276.632 seconds`; all 177 child suites passed. Registration audit:
  `TEST REGISTRATION AUDIT: PASS (758 scripts; full suite=413, quarantined=29, windowed probe=316)`.
  Log: `/private/tmp/int05-godot-full.log`.

- Python full suite, once: `Ran 1477 tests in 1738.273s` /
  `OK (skipped=64)`; exit 0. The original rr-14 guard also passed in full
  discovery. Log: `/private/tmp/int05-python-full.log`.

Both full suites passed on the completed executable patch. Final whitespace
validation (`git diff --check`) passed, and
`OUTPUT GDIGNORE: PASS (13 folders; 3 referenced roots)` was observed.
All task acceptance criteria are met. No existing master failure assertion was
rewritten, and no out-of-scope fix was needed.

The full Python run refreshed the tracked Weaver sample index's bindings and
full-sample digest. The final ownership check caught that generated receipt;
its payload was unchanged, and the receipt was restored byte-for-byte to the
initial clean HEAD. `INT05 OWNERSHIP: PASS (exactly five intended files; nothing staged)`
then passed. No approved receipt update is included in the handoff.

## Design placeholders, chosen defaults and inspection

No TODO_DESIGN placeholders or player-facing defaults were needed. Chosen
defaults are confined to named synthetic fixture paths/bytes/binding sentinels,
temporary directory/module names, disposable Git identity and fixture commit
messages. Fixture commits exist only inside temporary repositories under tests;
the implementation branch remains uncommitted. The engine timeout is the
existing prescribed 900-second cap.

No windowed probe, capture, proof contract or `inspection_fixture.py` command
applies: this unit changes tests and preservation helpers only. Product code,
scenes, approved art, motion, audio, registries and saves are untouched.
There are no new windowed commands for the design owner to run.
