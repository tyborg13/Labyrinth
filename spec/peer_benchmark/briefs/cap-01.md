# cap-01 — Fast proof captures: crop to the actor, fast lossless encoding (owner-approved 2026-10-19)

## Header
- Base: integration `fb1256984`, which is green.
- **Problem:**
  - Rig production captures save every frame as a full 1920x1080 PNG of the whole board: about 7,900 frames, about
    14 GB, and 30–50 minutes per rig.
  - Most of each frame is the static board. The gates only read the actor's pixels.
  - Writers: `tests/maquette_cutout/production_capture.gd:156` (`_viewport.get_texture().get_image().save_png(...)`),
    `native_capture.gd`, `pixel_capture.gd`, `seam_capture.gd`, and per-unit wrappers (`tests/rr07`, `rr12`, `rr22`,
    `gait01`, …).
  - Consumers: `tools/humanoid_cutout/{gates,production_gates,proof,move_sheet}.py`, `tools/maquette_motion/gates.py`,
    and per-case scripts under `experiments/cutouts/*/`.
- **Target:**
  - a full production capture under 8 minutes and under 1 GB per rig;
  - identical gate verdicts and metrics;
  - identical review reels.
- Owned:
  - the capture writers above;
  - the shared consumers;
  - a new shared crop helper;
  - every per-case consumer that reads native frames.
- rr-27 (Thrall) may merge first. Rebase-friendly edits only in `experiments/cutouts/arc_thrall/*`.

## Change
1. **Crop.**
   - Each capture writes only a rect around the actor: the renderer's full action canvas projected to the screen, plus
     a 16 px margin, clamped to the frame.
   - The rect is constant for a whole capture run (all clips, both views of that run), so frames stay aligned.
   - Record it in the frame manifest: `"crop": [x, y, w, h]` plus the existing `"size": [1920, 1080]`.
   - Uncropped legacy manifests (no `crop`) still read correctly.
2. **One helper.**
   - Add a shared Python helper (e.g. `tools/humanoid_cutout/native_frames.py`) that loads a frame and maps full-frame
     coordinates in and out of the crop.
   - Every consumer goes through it: gates, crops, move/contact sheets, reels.
   - Any check that sampled the board outside the actor (for example, background or shadow on the floor) keeps working.
     Either the margin covers it, or the run saves one uncropped reference frame per clip (`full_<clip>.png`) for
     those checks. Report which.
3. **Encoding.** Measure on the Seer's production capture:
   - `save_png` on the crop;
   - `save_webp` lossless on the crop;
   - an uncompressed RGBA dump plus a header, if Python can read it without new dependencies.
   - Pick the fastest that is lossless and meets the size target. Report the table: seconds, GB, frames/s.
4. **Equivalence proof** on the Seer (`experiments/cutouts/hoarfrost_seer/rr10_proof.sh`) and the Mortar
   (`experiments/cutouts/slag_mortar/rr22_proof.sh`):
   - Every gate JSON is byte-identical apart from timestamps and paths: errors, metrics, pocket and detached lists.
   - Pixel hashes are unchanged; they already come from the renderer texture.
   - The review reel decodes to identical frames, or within the encoder's own determinism. Say which.
   - You can't open windows, so build the headless equivalence harness. List the exact windowed commands, before and
     after, for the director.
5. Update `spec/peer_benchmark/humanoid_cutout_rig.md`'s proof section: one paragraph on the crop and the encoder.

## Keep
- Gate thresholds, rules and pixel semantics.
- The 1920x1080 / 100% UI scale capture environment. Only what is written to disk changes.
- Windows typed-array rule.

## Proof
- Focused tests for the helper (crop math, legacy manifests, edge clamping) and the consumers.
- The director runs the windowed before/after sequences.

## Out of scope
- Changing what is captured, which clips, or the frame rate.
- rr-09 binding narrowing.
