# rr-10 feedback 3 — gate calibration

Only the two native silhouette gates and their regression tests changed. No
runtime, rig, meshes, motion, ownership, paint, approved idle, production
registration, other creature data or protected director input changed. The
worker left everything uncommitted and performed no GUI run or peer review.

1. **Joint-seam holes.** An enclosed transparent region larger than one pixel
   must still be wholly within the existing three-pixel GPU seam neighbourhood.
   At least 80% of its four-neighbour opaque boundary must be visibly owned by
   the two members of one permitted anatomical pair, with both members present.
   A staff-owned boundary pixel makes it free negative space. The allowed pairs
   are shoulder torso/upper sleeve, elbow upper/fore sleeve, wrist fore
   sleeve/hand, torso/head, torso/robe, and robe/foot on each side. Hidden
   continuation belongs to its logical cut piece. Sleeves remain single native
   surfaces: nearest posed bone segment names each boundary texel's upper/fore
   region without deforming, resampling, or CPU-rasterizing any mesh. Existing
   holes still match GPU-transported rest references one-to-one.
2. **Detached components.** An 8-connected component of at most two pixels is
   exempt only when every pixel has encoded-RGB normalized luma strictly below
   0.12 and its nearest distance to the largest component is at most two native
   pixels. Distance uses the project's existing Euclidean dilation convention.
   All other detached components fail, including clusters above eight pixels.
   The visible layer colour is checked, so a hidden dark pixel cannot exempt a
   brighter visible fragment. All five historical feedback-1 captures still
   fail; the new native far-elbow fixture passes intact and fails after a
   three-pixel-wide (3×3) opening is cut at its actual elbow.

## Existing native capture diagnostic

The 467 frames captured by the director at `5abe9b561` were rechecked without
changing their files, hashes, bindings or original 344-error report. This is a
calibration diagnostic, **not fresh native acceptance**. The gate and fixture
changes correctly invalidate both old native and old headless-pose bindings.

The requested rule does not clear all current captures:

| Diagnostic | Director's old gate | Calibrated gate |
|---|---:|---:|
| Frames flagged for joint-seam holes | 325 | 217 |
| Frames flagged for detached components | 19 | 1 |

Examples that meet the new joint-pair predicate even after staff/free-hand
openings are excluded (coordinates are on the 512 px native proof canvas):

| Frame | Hole pixels | Bounding box, inclusive | Boundary owners |
|---|---:|---|---|
| mark 30 | 7 | (202,244)–(206,245) | fore_far 6, hand_far 6 |
| ward 12 | 2 | (299,272)–(299,273) | torso 5, robe 1 |
| death 30 | 6 | (213,269)–(215,271) | fore_far 2, hand_far 8 |
| move 9 | 5 | (280,366)–(283,367) | robe 6, foot_near 4 |

The remaining detached component is **move 41**, two near-black pixels at
(y,x)=(383,243),(384,243). Their nearest Euclidean distances to the main
silhouette are √5 and √10 pixels, respectively; encoded luma is 4.701/255 and
1.886/255. Thus its nearest distance exceeds the supplied two-pixel limit.
The corresponding nearest 8-neighbour grid distances are two and three pixels.

The implementation does not add exceptions for these remaining regions or
alter the director-approved visuals. The current native gate and contact sheet
composer consequently remain blocking. See
[the diagnostic JSON](proof/feedback3_native_diagnostic.json) for every frame,
input hash difference, and capture manifest hash. Diagnostic crops are in
`/private/tmp/rr10-feedback3-native-failures/`; the original director failure
crops and reports remain intact.

## Files changed

- `tools/humanoid_cutout/silhouette_gates.py`: new native boundary and component helpers.
- `tools/humanoid_cutout/gates.py`: calls those helpers; optional diagnostic crop directory.
- `tests/test_rr10_humanoid.py`: supplies boundary owners to existing hole mutations; no assertion weakened.
- `tests/test_rr10_silhouette_gates.py`: five focused calibration/mutation tests.
- `tests/rr10/feedback3/capture.json`, `sleeve_far.png`, `elbow_seam.png`: hash-bound copies of native proof inputs for the elbow regression.
- This case's `README.md`, `feedback3.md`, `proof/feedback3_native_diagnostic.json`, and `proof/feedback3_verification.md`: current handoff and results.

Existing runtime hooks changed in this feedback: **none**. The director's
preexisting modified proof files were preserved.

## Chosen defaults

Only debug/test fixtures were chosen: a 24×24 synthetic canvas with body rows
and columns 5–18, RGB (60,70,80), outline RGB (18,18,23), and a 12×12 boundary
fixture with a 2×3 opening at rows 4–5 / columns 4–6. Named fields live in
`tests/test_rr10_silhouette_gates.py`. Byte values 30 and 31 bracket the supplied
0.12 luma limit. The native mutation uses the existing 128 px proof origin and
observed elbow centre (227,273); its required width is the director's 3 px.
No new player-facing defaults or TODO_DESIGN placeholders were introduced.
`TODO_DESIGN_mq6_rear_delivery_and_paint` remains the existing rear stop.

## Proof for the design owner

Headless commands, exact observed result lines and log paths are recorded in
[feedback3 verification](proof/feedback3_verification.md). No windowed command
was attempted. From this worktree, the director's requested commands remain:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
```

They retain the 1920×1080, 100% UI scale visual runner and freshness guards.
Native output is `proof/native/`; accepted sheets would be
`proof/contact_sheets/front_<clip>_3x.png`. The unresolved flags described above
must be addressed by the director before these commands can both pass. Rear
proof remains deferred until the approved mq6 inputs arrive.
