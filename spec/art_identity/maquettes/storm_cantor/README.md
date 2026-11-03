# mq-17 — Storm Cantor native maquette

Implementation for the design owner, left uncommitted on `codex/mq-17`.
This unit supplies the source maquette and native proof. Painting, runtime
rig v2, inspection approval and publication belong to later owner stages.

1. `recipe.py`, `source_measurements.json` and `director_pose.json` compile
   `measurements.json`, the Blender-native v2 input. It uses the approved CC0
   humanoid body and its real heat-weighted armature. Slender plate envelopes,
   curved separate ribs with actual gaps, a hollow hanging bell, the closed
   rear plate/spine, distinct helm tines and the three-tined staff are native
   meshes. No raster art, icon, audio or font is generated or replaced.
2. `delivery/pose_table.md` reports every sub-value of requirements 1–12,
   measured from opened native vertices and actual armature endpoints.
   `delivery/proportion_table.md` compares source and native proportions,
   without an old-pose fit gate. `delivery/mq17_acceptance.json` recomputes
   level shoulders, projected shoulder rise, proper 180-degree rotation,
   staff screen side, unclipped labels and per-part native coverage.
   `delivery/per_part_coverage.csv` includes all 22 labels in both views;
   hidden parts require an explicit occlusion and retain a nonempty solo.
3. `delivery/` contains the 1024-square native clay pair, maps, 44 solos,
   projected joints, manifests and `contact_sheet.webp`: current art at 4x,
   front/rear native at 1:1, and the mq-15 Gaoler at 1:1. No figure is
   independently resized; all soles share a proof baseline. `COMMIT_MANIFEST.txt` inventories the retained
   files under the 6,000,000-byte limit. Native clay PNG bytes are copied
   unchanged; packing preserves every mask alpha and visible RGBA value.
   Discarded models, caches, old candidates and duplicate captures are
   SHA-256 inventoried before removal in `discarded_proof_sha256.json`.
4. Cold, shared-cache replay and independent-cold builds must match. The
   exact replay hashes unrounded float32 meshes and every joint matrix.
   Opened native mutations change polygon ownership, a helm vertex, the
   staff position, finger geometry and bell visibility; a passing baseline
   is required before mutation rejection can certify the result. Clean
   input-only regeneration uses a copied compiler, fresh native build and
   empty cache, and compares both clays and part maps. The shared delivery
   validator seals report/capture bytes to the native cold geometry hash.

Observed final gates: far shoulder rise **31.730px**, target **31.7295px**,
error **0.0005px**; native shoulder Z difference **0.000000119m**. The rear
relative matrix is **diag(-1,-1,1)**, determinant **+1**. Front drawn body
height is **928px**, exactly **232px × 4**; the true-turn rear is **913px**.
Every pose-table row passes its 1-degree or 0.01 L/H tolerance. Both feet
are planted; the bell and tabard sigils are explicitly hidden in the rear.
The cloak retains the source rag pattern and anchors its lowest tip to the
new native near knee; an opened-vertex check and focused regression enforce
that endpoint.

The static cloth envelopes are closed meshes bound to their owning rig bone;
this maquette does not introduce simulated cloth or animation. Hood/scarf and
cloak stay on torso, tabard on pelvis, sash/medallion on pelvis, bell on torso
with the sternum-hook pivot, and the entire staff/pennant on hand_far with its
origin at the grip. Only the diagnostic ownership palette is coloured.

`preservation.json` binds the losslessly compressed original inventory in
`preservation_inventory.json.gz`: all 2,051 existing maquette/source files and
16 compilable foreign inputs. Compressed bytes and the complete expanded JSON
bytes each have a checked SHA-256; no inventory value is removed. Shared builder code and every foreign figure
remain byte-identical. No builder change from mq-16 was duplicated: the local
capture wrapper uses the API already present in this checkout. Large full-view
jobs returned their 110-second execution timeout; the final workflow uses a
preview plus two-label solo batches. A four-label clean-regeneration batch hit that execution limit under load;
the final clean workflow uses two-label batches with the same renderer settings.
Each job allows 110 seconds execution
and stops after 120 seconds without a response, including queue time.

## Director feedback 1 — rebuilt armour and cloth

The approved joints, stance, head/tines, bell pivot, staff shaft and fork are
frozen in `approved_pose.json`. `feedback1_dimensions.json` records the exact
director H ratios. `volumes.py` replaces the thin source placeholders with
rounded plate volumes, a five-rib barrel, normal-thickened folded cloth,
a soft sash/knot and domed hollow shoulder shells with one curved lame each.
The three short crest spikes sweep back; their arc lengths are 0.03 H.
The rib opening is a curved sternum window, with no rectangular frame posts.
The near-side opening exposes the bell in 3/4 view while the far-side plate
keeps ribs and bell occluded in the true rear turn.

Both transverse axes of each limb are measured, as are couters/poleyns,
gauntlet palms, toe reach, barrel width, every cloth thickness, neck roll,
tabard width/folds, streamer width/tails, spikes and total shoulder span.
All **42 feedback dimension rows** pass. The native barrel is **0.159656 H**
(target 0.16 H); the outer pauldron span is **0.310000 H**. The proportion
table contains all target/measurement pairs. Three actual fold crests and
three ragged cloak tails are verified from the opened meshes.

The wider thigh armour is expanded behind the approved forward surface,
so the fixed open-hand pose retains its 0.03 L wrist clearance. New cloth
thickness is measured from paired native surface vertices. The staff's
pennant receives that same minimum thickness and a shallow vertical fold;
its tie, hanging length, width and the entire shaft/fork stay fixed. The
front far thigh is now fully occluded by the draped tabard/pelvis: its native
solo remains complete and its occluding owners are reported in acceptance.

The original five native corruptions remain mandatory; three additional
opened-scene mutations reject thin armour, collapsed cloth and a shoulder
cap dropped below its joint. No shared builder or foreign figure changed.
No new player-facing tuning or unresolved TODO_DESIGN value was introduced.

## Director feedback 2 — proof and guards only

The director-approved compiled spec digest remains
`48f3f0ddae5b3881fbccba39fcb466bd1499980c9cc8893e153c6b1a46ee7504`.
`feedback2_approved_sha256.json` freezes that spec and every delivered PNG/WebP
byte, including all solos and the contact sheet. The unused pose solver was
removed: `approved_pose.json` is the sole joint input. No forms, volumes, pose,
source calipers, design dimensions, camera or rendered image changed.

`regeneration_checks.py` derives the complete input inventory from current
compiler, builder, probe and proof sources. Verification requires exact inventory
and SHA equality, successful compile/bridge results, explicit clean-cache and
new-model flags, all four comparisons and current delivery file/canonical PNG
hashes. The raw regenerated hashes bind to its retained native capture manifest;
the fresh probe binds to the delivered native report. Empty inventories, zero
hashes, stale sources, missing comparisons and failed/reused runs fail closed.

Shape reports now measure each cap's rise, inner/outer skin separation and rim
height above its shoulder. Every limb reports its longitudinal extrema relative
to the two actual bone joints. These are numerical observations, with technical
proof tolerances in `chosen_defaults.json`; they do not alter construction.
All ten per-rib curvature/wrap checks and all six per-spike direction checks are
mandatory. The proportion table includes the additional shape observations.
Three added native negative cases flatten both caps, collapse their skins and
shorten upper/fore armour to a tenth of its length, restoring every vertex after
each case. The original eight corruptions also remain required.

Focused tests independently calculate changed pose angles, fist height, staff
clearance, transverse diameter, cap rise and longitudinal coverage on perturbed
fixtures. They test each missing rib/spike check, every forged volume target,
missing folds/tails, fork shape and elbow direction. `guard_mutation_probe.py`
reproduces the six review survivors against the specific assertions, with a
passing baseline for each and byte-for-byte source restoration. Stale input
failures or unrelated exceptions never count as caught mutants.

## Director feedback 3 — heavier masses

`feedback3_dimensions.json` supplies only the new director targets; it overrides
`feedback1_dimensions.json` in memory without rewriting historical source data.
The bell's new 0.09 H mouth supersedes the historical 0.08 H extra dimension;
its height, hanging hook, ownership and pivot stay fixed.

Armour diameters, joint cops, gauntlets/fingers, the rib barrel/bars, bell mouth,
pauldron span/domes, hood roll, tabard/streamer widths, toe extension and held
shaft/fork thickness are measured back from native geometry. The report now
requires 66 volume rows, including each finger/thumb, rib and fork tine.
`feedback3_preserved.json` binds every unrequested piece and the staff's fixed
pennant, topology, placement and centre paths. The cloth grids and ragged hem
heights remain fixed; only the directed panel widths and roll thickness change.
Current native measurements include **0.199586 H** rib-barrel width (target
0.20 H), **0.360000 H** outer shoulder span, **0.100000 H** dome diameter,
**0.033034 H** outward dome offset and **0.020000 H** fork base diameters.
Every one of the 66 volume rows passes the existing measurement tolerances.

All feedback-2 completeness, measurement, negative-case, mutation and regeneration
guards remain active. `feedback2_approved_sha256.json` remains historical evidence;
the new volume delivery receives its own explicit artifact seal at staging.

The director resolved both fields: each 0.10 H dome and its lame move outward
0.033034 H from the fixed shoulder joint. Lame normal offsets fit inside the
specified dome envelope, preserving the 0.36 H total span. Fork tines retain
their existing taper, with a 0.02 H base diameter; the base ring is measured
explicitly. No TODO_DESIGN field remains.

## Chosen defaults

`chosen_defaults.json` records numerical topology/sampling, the one-metre L
unit gauge, shape measurement tolerances, capture batch size, response deadlines,
pixel/joint tolerances, synthetic native mutations, diagnostic palette and
proof sheet layout, and deterministic proof-inventory compression. These are technical/proof controls. Visible geometry uses
the supplied identity's calipers and exact director pose, not new tuning.
The approved pose fixes the forward shoulder-pendulum angle; the near upper
arm remains 8 degrees out of the side plane. Shoulder
and ankle widths are transverse in body space. The proportion report defines
that measurement explicitly. No TODO_DESIGN placeholder remains.

## Proof for the design owner

Every native operation is headless Blender through the director's existing
bridge. No Godot/windowed probe or `tools/inspection_fixture.py` command applies
to this offline source-only unit. No window-server run or retry is required.

For the feedback-3 volume revision, run these commands from the worktree after
the director targets are resolved. Use fresh empty build and regeneration
output directories. Staging creates the new clays/maps/solos and contact sheet;
regeneration then verifies their current-source hashes and preserves their bytes.

```sh
python3 -B -m spec.art_identity.maquettes.storm_cantor.proof prove --out spec/art_identity/maquettes/storm_cantor/proof/owner_feedback3_native
python3 -B -m spec.art_identity.maquettes.storm_cantor.proof stage --capture spec/art_identity/maquettes/storm_cantor/proof/owner_feedback3_native/capture
python3 -B -m spec.art_identity.maquettes.storm_cantor.proof regenerate --out spec/art_identity/maquettes/storm_cantor/proof/owner_feedback3_clean
python3 -B -m unittest tests.test_mq17_maquette tests.test_maquette_blender tests.test_maquette_regressions tests.test_maquette_closed_loft spec.art_identity.maquettes.blender.test_delivery_validation spec.art_identity.maquettes.blender.test_delivery -q
python3 -B -m spec.art_identity.maquettes.storm_cantor.guard_mutation_probe
python3 -B tests/test_art_identity_gate.py
python3 -B tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/mq-17-feedback3-owner-audit
python3 -B -m spec.art_identity.maquettes.storm_cantor.proof curate
python3 -B -m spec.art_identity.maquettes.storm_cantor.proof verify
```

The `prove` operation includes native mutations, determinism and exact replay.
The ordinary portable builder suite skips its two opt-in native fixtures;
this unit's own native bridge proof is separate and mandatory. Focused test
and bridge result lines are retained with this figure. No full project suite,
peer review, commit, publication or task queue mutation is part of this worker
handoff.
