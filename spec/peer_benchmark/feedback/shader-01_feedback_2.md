# shader-01 feedback 2 (final, small)

The director ran both native proofs (Metal):
- **Shader proof:** session 1 had 36 shader cache misses, session 2 had 0, and there were no `_save_to_cache` errors.
  The links were created for shader_cache, metal and vulkan.
- **Combat proof:** session 1 had 52 misses, session 2 had 0. The first trap-kill frame is still about 30 ms in both
  sessions, which matches your note: Godot 4.6.1 doesn't persist Metal pipelines, so pipeline creation remains on first
  use per session.

The cache fix works. Finish the proof so it states what's true:
1. **Acceptance per backend.**
   - Metal: session 2 has zero shader cache misses and zero `_save_to_cache` errors; pipeline counts are reported for
     information only.
   - Vulkan: also zero pipeline compilations in session 2.
   Update `tests/run_shader01_cache_proof.py`, the probes and `tests/shader_01_proof.md` accordingly.
2. **The shader probe captured session 1 at the window size (3024x1898)** on a Retina screen, so its pixel check
   sampled the wrong spot. Render the probe in a fixed 1920x1080 SubViewport (as `tests/helpers/ui03_capture_viewport.gd`
   does) and sample there.
3. Name test files by responsibility: `tests/run_shader01_checks.py` and `tests/run_shader01_cache_proof.py` become
   `tests/run_engine_cache_checks.py` and `tests/run_engine_cache_proof.py`. Update references.

Re-run only the cache unit tests and the proof validator tests. The director re-runs native.
