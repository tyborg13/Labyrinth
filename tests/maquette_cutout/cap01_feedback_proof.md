# cap-01 feedback 1 implementation handoff

All changes are uncommitted. No windowed commands, full suite, peer review,
commit or publication were run in this feedback round.

## Acceptance criteria

1. Native frame readers use `humanoid_cutout.native_frames.load_frame`. The
   three reported paths are fixed. The repository audit also found native
   reads/copies/encoder inputs in Harrier, Vaeloryx, protagonist gear, Shrike's
   production coverage/reel/promotion, and the strike-trail sheet tool. All are
   routed through the shared IO. Hashes and logical-file existence checks use
   `frame_digest` and `frame_exists`. Logical glob enumeration is codec-aware.
   Tests cover cropped PNG, lossless WebP and headered RGBA, actual consumer
   entry points, mixed board/pose spaces, crop-only manifests and legacy bytes.
2. `capture_inventory.py` requires eight captures, eight gate/diagnostic JSONs,
   five gate exit records, four reels and their manifests, both sets of contact
   sheets, and the Mortar gait sheet/manifest. Native frame/surface inventories
   are derived from clips and layouts. Production counts come from the case's
   existing fixed-clock logic records: Seer 1,441; Mortar 1,516 per view. Reel
   counts are verified with ffprobe as well as their manifests. Missing, extra,
   duplicated or incomplete artifacts fail with a path, even on both sides.
3. The board fixture has a non-uniform RGB pattern. Python independently checks
   every reconstructed RGBA byte from all three real writer codecs. The actual
   native gate's rest reader and Gaoler's complete native gate are exercised.
   Both surviving mutations are killed; see the table below.
4. No production writer, capture format, encoder setting, renderer binding,
   threshold or pixel rule changed. Seer/Mortar capture-bound source bytes are
   unchanged from `6e76ac2b6`. No `after` recapture is required for this round.
   Only focused tests were run.
5. Native and production gates run as subprocesses whose actual exit statuses
   are recorded. A completed failing gate continues the sequence and its JSON
   and exit must match in comparison. Samples and gate records are written
   inside the proof output folder. Canonical gates run against a private case
   copy and linked capture input, preserving committed case proof and existing
   pocket JSON. The director compositor retains failed gate evidence while
   producing the same frame order and sheet pixels as the original compositor.

For r0 capture folders without exit records, `compare` re-evaluates the canonical
same-source gates headlessly, requires their JSON to match the saved reports,
and then records the observed exit. It does not infer an exit from `ok`, rebind
captures, or overwrite historical pocket reports. Missing capture/gate/reel
artifacts still fail. New version-2 runs require every recorded exit directly.

## Changed files

Native reader audit fixes:

- `experiments/cutouts/briar_weaver/rr21_residue.py`
- `experiments/cutouts/chainbound_gaoler/mq3/probes/motion_gates.py`
- `experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py`
- `experiments/cutouts/gust_shrike/mq2/probes/production_coverage.py`
- `experiments/cutouts/gust_shrike/mq2/probes/pack_production.py`
- `experiments/cutouts/gust_shrike/mq2/pipeline.py`
- `experiments/cutouts/harrier/package_assets.py`
- `experiments/cutouts/vaeloryx/review_sheets.py`
- `experiments/cutouts/protagonist_gear/collect_review.py`
- `tools/build_strike_trail_sheet.py`

Proof infrastructure:

- `tools/capture_director.py`
- `tools/capture_gate_runner.py` (new)
- `tools/capture_inventory.py` (new)
- `tools/capture_review.py` (new; baseline compositor outside renderer bindings)
- `tools/native_frame_paths.py` (new; logical filename enumeration)
- `tools/capture_mutation_check.py` (new)

Focused proof:

- `tests/maquette_cutout/capture_storage_test.gd`
- `tests/test_native_frames.py`
- `tests/test_capture_director.py` (new)
- `tests/test_native_review_readers.py` (new)
- `tests/maquette_cutout/cap01_feedback_proof.md` (this file)

Derived code fingerprints only:

- `experiments/cutouts/chainbound_gaoler/mq3/baseline.sha256.json`
- `experiments/cutouts/chainbound_gaoler/mq3/proof/derived_files.json`
- `experiments/cutouts/gust_shrike/mq2/baseline.sha256.json`
- `experiments/cutouts/gust_shrike/mq2/proof/motion_samples.json`

Gaoler's clean rebuild matches all 882 artifacts after refreshing reader hashes.
Shrike's 904 existing sampled poses and all other existing non-input fields
match a fresh headless sampler. Only four owned code pins were refreshed; its
new sampler's additional `bone_samples` field and unrelated old pins were not
copied into the historical record. No approved paint, motion, balance or gate
values were rewritten.

Audit exclusions are source art, registered maquette inputs, immutable PNG test
fixtures, frozen `provenance/round*` source snapshots, and independent legacy
JPEG gameplay transports whose writers are outside this crop pipeline. Those
files do not consume the native storage manifests changed by cap-01.

## Observed focused results

| Check | Exact result | Evidence |
| --- | --- | --- |
| Combined native IO, reader, director and residue tests | `Ran 42 tests in 10.889s` / `OK` | `/tmp/cap01-feedback-focused-final.log` |
| Existing Gaoler native checksum/size/owner mutation guards | `Ran 2 tests in 0.565s` / `OK` | `/tmp/cap01-feedback-gaoler-native.log` |
| Gaoler clean rebuild comparison | `GAOLER REBUILD: PASS (882 files)` | `/tmp/cap01-feedback-gaoler-final.log`, `.json`; fresh tree `/tmp/cap01-feedback-gaoler-v2` |
| Shrike headless sampler | `SHRIKE MOTION SAMPLES: PASS (904 poses; 196 authored bone poses; design complete=true)` | `/tmp/cap01-feedback-shrike-samples.log`, `.json` |
| Existing Shrike sample fields | `SHRIKE EXISTING SAMPLE FIELDS: IDENTICAL (904 poses; four owned code pins refreshed)` | `/tmp/cap01-feedback-shrike-equivalence.log` |
| Writer fixture | `CAPTURE STORAGE: PASS (0 failures)` | `/tmp/cap01-feedback-storage.log`; fixture outputs `/tmp/cap01-feedback-storage/` |

The combined test includes actual ffmpeg decode equality for legacy versus
cropped proof frames and all three Shrike reel codecs, plus identical original
versus director compositor paths and contact-sheet pixels. These are headless
fixtures, not the director's full Seer/Mortar windowed equivalence result.

| Mutation | Result |
| --- | --- |
| Sample crop shifted 1 px, recorded coordinates unchanged; fixture's own image comparison disabled so Python must detect it | `CAPTURE MUTATION sample_crop_shift_1px_metadata_unchanged: KILLED` |
| Canonical native gate rest loader bypassed with direct `Image.open` | `CAPTURE MUTATION native_gate_rest_loader_bypassed: KILLED` |

Mutation command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-01 && python3 tools/capture_mutation_check.py --output /tmp/cap01-feedback-mutations
```

Mutation logs and machine-readable table:
`/tmp/cap01-feedback-mutations/` and `/tmp/cap01-feedback-mutations.log`.
Mutations use disposable fixture/writer copies and an in-memory reader patch;
production writer and gate files are never edited.

## Proof for the design owner

Re-run comparison on the existing director captures (use their actual paths if
these differ from the original example output root):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-01 && python3 tools/capture_director.py compare --before /tmp/cap01-proof/before --after /tmp/cap01-proof/after --output /tmp/cap01-proof/equivalence-feedback-1.json
```

No windowed rerun is needed. The exact complete windowed before/after plans are
also saved in `/tmp/cap01-feedback-before-commands.txt` and
`/tmp/cap01-feedback-after-commands.txt`. To regenerate those plans without
opening a window:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-01 && python3 tools/capture_director.py before --output /tmp/cap01-proof/before --print-commands
cd /Users/borgerding/workspace/Labyrinth.worktrees/cap-01 && python3 tools/capture_director.py after --output /tmp/cap01-proof/after --encoder-report /tmp/cap01-proof/encoding.json --print-commands
```

Inspection fixture preparation remains with the design owner, as assigned in
the task; this feedback requests no inspection-fixture command.

## TODO_DESIGN placeholders

None.

## Chosen defaults

Test-only `TEST_PATTERN_MODULUS = (251, 253, 256)` and
`TEST_BLUE_FACTORS = (7, 11)` define the non-uniform board oracle. The mutation
subprocess budget is the named `MUTATION_TIMEOUT_SECONDS = 180`. Private case
copies and encoder scratch directories live beneath caller-owned proof/test
output paths. No player-facing defaults were chosen.

## Open issues

- The director's full Seer/Mortar comparison remains to be observed. Its 31
  canonical Seer tears remain genuine gate failures, retained as evidence.
- The non-uniform RGB fixture exposes an existing issue in unchanged
  `capture_storage.gd:proof_png`: its decoded opaque PNG can be RGB8 while the
  restoration target is RGBA8, logging `format != p_src->format` at `blit_rect`.
  The uniform r0 fixture does not expose that warning. Saved native frames and
  Python reconstruction pass independently. The writer was deliberately left
  unchanged in this feedback round; this debug proof-export issue remains open.
- The sandbox also emits the existing macOS CA-certificate warning during
  headless Godot startup. Commands complete successfully; no windowed run was
  attempted.
