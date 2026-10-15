# vfx-01 — round 3 (director: windowed proof of round 2)

Round 2 visuals are approved: continuous one-cell cores with dithered halos (conduction and lightning), surface glows
keep their element colour. Vulkan GPU budget passes on every 1080p workload (paired median Δ ≤ 0.45 ms, 180/180 samples).

1. **CPU regression in line cores**: lightning submission costs +1.218 ms median at 1080p (+1.308 at 4K); every other
   workload is ≤ 0.22 ms. The core rasterization is too expensive per frame. Target: lightning (and the chain/tether
   cases) ≤ 0.3 ms median submission delta at 1080p. Batch the core and halo cells into one draw per layer (one mesh or
   multimesh / one polyline at the low-res layer), cache the rasterized cell list per arc shape for the frames it is
   unchanged, and avoid per-cell draw calls. Keep the exact pixels (test that the rendered cells are identical before
   and after the optimization).
2. **Benchmark false negative**: it ended with "Vulkan board/pixel GPU timestamps are unavailable" and exit 1 although
   every row has 180/180 GPU samples on and off. Fix the check (it must fail only if a row lacks valid GPU samples, i.e.
   fewer than 90% non-zero); report the gate verdict from the paired medians.

Proof: pixel FX tests (incl. the pixel-identity test for the optimization), elemental FX test, full suite; the Vulkan
benchmark command for me to run (expected PASS).
