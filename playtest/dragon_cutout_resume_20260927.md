# Cutout resume checkpoint — coordinator interruption

The coordinator recovered after the 2026-09-27 21:00 UTC interruption and quit
its native game normally (runner 5900 exit 0). It explicitly released the lease.
Vael candidate02 then passed its fresh full-cycle capture, all 196 strict
production/case pose comparisons, both native/shipped rest comparisons and the
focused runtime suite. The exact rear neutral bake is promoted. See
`dragon_cutout_feedback_notes.md` for current receipts. The cutout worker has
explicitly transferred the renderer lease to the presentation worker for its
Vyraketh/Tharokh v03 candidates; no cutout-worker process remains active.

Update after that transfer: Vyraketh candidate01 and Tharokh candidate02 now
have independent full-cycle acceptance in
`dragon_vyr_thar_attachment_review_20260927.md`. Thar candidate01 is preserved
as rejected. The final wrapper/guide now name both accepted `feedback_seams_v03`
cases. The remaining sequence starts with their production promotion/parity
checks and focused suites, then root's final source freeze and renderer lease.

The following saved-state/command section records the interruption checkpoint,
not the current acceptance state. Its Vael commands have now completed; the
remaining sequence is stated in the current update above.

## Saved state

- Shared task worktree and branch remain unchanged in ownership. No staging,
  commit, reset or adoption by this worker.
- V1 batch session 46494 exited 0: all seven renders and final verifiers passed.
  `/private/tmp/dragon-cutout-final-v1/acceptance.md` explicitly rejects visual
  closure for Vaeloryx, Vyraketh and Tharokh. Per-case directories are untouched.
- Iskaldra/Zekarion/Wisp independent full-cycle review is recorded in
  `dragon_four_rig_final_cutout_review_20260927.md`; Noctyrax's separate full
  review is in `dragon_noctyrax_final_cutout_review_20260927.md`.
- Vael candidate01 focused render session 24352 exited 0 at
  `/private/tmp/vaeloryx-attachment-fix-01`. Front gap fixed; rear one-texel
  shoulder gaps persisted. It is rejected, not final accepted proof.
- Vael standalone production suite session 97223 exited 0/PASS in run
  `dragon-boss-encounters-milestone-rewards-1790540931827460000-39253`.
  This receipt precedes candidate02's hidden collar addition.
- Vael candidate02 is saved in the existing `feedback_v02` case and production
  layouts. `repair_attachments.py` owns body collar/chain-weight/hidden overlap
  geometry. Structural validation and case/production mesh-data equality pass.
  No original part PNG or motion sampler has changed. Its native proof is owed.
- `tests/vaeloryx_feedback_asset_probe.gd` is prepared: 196 native direct/mirrored
  case-vs-production comparisons, fractional seam phases, native rest bakes and
  a strict shipped-rest comparison by default. It has not run yet.
- Presentation worker owns Vyr/Thar `feedback_seams_v03` candidates. Read-only
  crosscheck confirms all 105 PNGs, motion files, clip metadata, joint graphs
  and part definitions match v02. Only attachment meshes/weights differ. Its
  planned outputs are `/private/tmp/dragon-seam-repair/{vyraketh,tharokh}-candidate01`.

## Agreed next lease sequence

Root explicitly assigned: finish native fixtures → cutout worker Vael02 →
presentation worker Vyr/Thar → final seven-case freeze and batch. Do not assume
that a crashed coordinator released an active game or graphics lease.

After explicit handoff, from the shared worktree:

```sh
python3 tools/cutout_workflow.py render experiments/cutouts/vaeloryx/feedback_v02 --output /private/tmp/vaeloryx-attachment-fix-02 --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --backend metal
```

Inspect all twelve front/rear cycles, exact `front_idle/pose_0011.png` and
`rear_pull/pose_0011.png`, original peaks, full native boards and loop boundaries.
The previously transparent front pixel is (250,246); rear pixels are (265,246)
and (270,247). Pixel checks supplement complete visual inspection, not replace it.
The presentation worker independently reviews Vael; the cutout worker independently
reviews Vyr/Thar after their new receipts. Use `followup_task` if a reviewer is idle.

If Vael geometry passes, run the prepared production comparator through the
visual runner. Its first run may prepare an updated renderer-produced neutral
bake (the hidden overlap can change neutral compositing); the preparation flag
is explicit in its report and does not count as strict still-art acceptance:

```sh
LABYRINTH_VAEL_PREPARE_REST_BAKE=1 python3 tools/visual_probe_runner.py tests/vaeloryx_feedback_asset_probe.gd --project . --task-id dragon-vael-feedback-assets-01 --no-headless --display-driver macos --rendering-method mobile --rendering-driver metal --min-images 198 --expect-size 512x512 --expect-size 255x255 --timeout 70 --result-manifest output/dragon-revision/vael-feedback-assets-01.json
```

The 70-second comparison allowance follows the toolkit's 196 samples × 0.2 seconds
+ 30-second budget. This asset comparator emits native 512px canvases and 255px
bakes; the separate case capture supplies the required 1920×1080/100% board proof.
Copy only renderer-produced bakes whose pixel comparison differs into the existing
production `front/rest.png` or `rear/rest.png`, update their production layout
`rest_source_sha256`, then rerun the same comparator WITHOUT the preparation flag
using fresh task/output manifest suffix02. Require all 196 matches and both strict
rest checks. Do not repaint or resize the bakes.

Run `tests/vaeloryx_cutout_test.gd` through the official task runner again for
candidate02. Finish all Vael production writes, report any unresolved findings,
and explicitly hand the lease to the presentation worker. During its two captures,
hold production/layout writes; only inspect images or edit Markdown.

## Final batch remains owed

After all three repairs are accepted/promoted and root's fixtures are complete,
update the wrapper/guide's Vyr/Thar variants to the accepted case names. Root must
freeze the shared source closure before the fresh batch:

```sh
bash playtest/dragon_cutout_final_receipts.sh render /private/tmp/dragon-cutout-final-v2
bash playtest/dragon_cutout_final_receipts.sh verify /private/tmp/dragon-cutout-final-v2
```

V1 had 3,696 timed board frames, 2,832 unique first-cycle pose samples, 80 clip
records, fourteen editable scenes and eighty pixel-identical reload samples.
For the four unchanged rigs, `/private/tmp/compare-dragon-cutout-pixels.py OLD NEW`
can establish equality of every PNG/JPG with the already reviewed v1 pixels.
Current-source verification plus exact image equality supports carrying their
recorded visual review forward; record the comparison and any fresh spot checks
honestly. All three repaired rigs need full fresh review. Keep acceptance and
derived sheets outside immutable per-case proof directories. Root owns the final
commit, exact-HEAD peer signoff, inspection handoff and publication approval.
