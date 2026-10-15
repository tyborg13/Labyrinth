# vfx-01 — round 2 (peer review of b1ff413f7 + director visual review)

Work on top of b1ff413f7. Do not commit.

1. **Surface glows lose their element colour** (Medium, peer review). `_draw_board_surface` (combat_board_view.gd) uses
   `str(event.get("feedback_element", event.get("surface", "neutral")))`, but `CombatOutcomeFeedback.prepare` always sets
   `feedback_element` (to `""` when the main spell covers the tile), so the surface fallback never runs: a Fireball
   painting fire on its own target tile gets a neutral brown/cream glow. Fix: when `feedback_element` is empty, use
   `_surface_pixel_element(str(event.get("surface", "")))`. Test: a prepared surface_created event whose tile the main
   spell covers; assert the run element equals the surface's (fire, ice, water, electrified, rubble).
2. **Thin lines stay continuous** (director). The pixelated conduction floor line breaks into a dotted trail and loses its
   zigzag (`surface_conduction_on_crop3x` vs `_off`). Rule for every line-type effect (conduction lines, chain-lightning
   arcs, beams, tethers): a solid core exactly one cell (2 px at 1080p) wide, full alpha, 8-connected from start to end,
   following the original path's zigzag; only the glow/halo around it is dithered (one cell wide, Bayer as now). Test:
   the core cells of a quantized conduction segment and a chain arc form one 8-connected path between the endpoints.
3. **Benchmark harness** (peer review). The board already renders into a fixed-size SubViewport, so drop the window
   resize and its equality check (record the actual window size). Measure GPU cost properly: run with
   `--rendering-driver vulkan`, sum `RenderingServer.viewport_get_measured_render_time_gpu` over the board viewport and all
   pixel viewports, interleave off/on per sample, gate on the **median ≤ 1.0 ms at 1080p** per workload, and report p95
   and 4K. Keep the CPU frame-interval numbers as a secondary report. Min-spec hardware is out of scope (note it).
4. **Lazy layer nodes**: create a tile's SurfaceGround / SurfaceFeedbackPixels nodes only when that tile has feedback
   (about 160 always-present nodes on a 9×9 board today); free them when it ends. Test the node count on an idle board.
5. **Dead code**: remove the unreachable additive-blend path and its runtime-generated shader.
6. **Data**: move the surface→ramp mapping (rubble→earth, electrified→lightning, …) into `data/vfx_pixel_style.json`;
   tests read it.
7. Confirmed intended: collision flashes and generic surface glows inside `draw_feedback` are pixel-styled.

Proof: pixel FX tests, elemental FX test, hash equivalence, full suite; list the windowed compare/render probes and the
Vulkan benchmark command for me to run.
