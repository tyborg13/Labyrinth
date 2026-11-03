# qa-15 feedback 1 (from the Codex review of 21930222a; evidence /tmp/qa15-review/)

Items 1-4 are accepted as they are (all mutations caught; the tracked tree stays byte-identical). Three Mediums, all in
rr-09:

1. **Verdict code must still invalidate certificates.** Dropping the Python tools from `RUNTIME_PATHS` left
   `verification_bindings()` (`tools/maquette_motion/gates.py` ~191) hashing only six files, so editing `features.py`,
   `silhouette.py`, `joint_seams.py` or `seam_pose.py` no longer stales a certificate (editing `pixels.py` does).
   Hash the transitive import closure of the verdict implementations (derive it from the Python imports, don't
   hand-list it) in `verification_bindings()`. Regressions: a freshly sealed fixture certificate goes stale after
   editing each of those four files.
2. **Bind every live rendering input.** `input_bindings()` (~155) and `proof_inputs.gd` (~55) hash part textures but not
   the Storm Capacitor's `glow_textures`, which `scripts/maquette_cutout_runtime/rig.gd` (~49) loads during playback.
   Bind every texture/resource path the rig loads from case data (generalise: walk the case JSON for resource paths
   the renderer loads, not just `glow_textures`). For rendering settings, pin them inside the probes instead of
   binding project.godot: the probes set MSAA (and any other project rendering setting the review found affecting
   output) explicitly to the values production uses, and the probe asserts them at start. Regressions: replacing a
   glow texture stales the bindings; changing project MSAA doesn't change probe output or fails the probe's assertion.
3. **The closure test must follow every dependency form the probes use.** `tests/test_proof_runtime_paths.py` (~41)
   follows literal `.gd` preloads and string `extends` only. Also resolve `class_name` inheritance and `class_name`
   uses (via the project's global class list), non-script resources preloaded by scripts in the closure (shaders,
   materials), and each case's `motion.gd` plus anything it preloads (cover every case root that has proof records).
   Add mutation controls for each form (class-name extends, class-name call, shader preload, case-motion preload).
   Note the review found the pixel probe passes with a deliberately invalid case `motion.gd` because it hashes the
   file without executing it: if `motion.gd` isn't executed by the pixel probe, say so in a comment where it's bound;
   if it should be, report it instead of changing probe behaviour.

Don't refresh committed rig records. Re-run only the changed Python tests, `tests/test_proof_runtime_paths.py`, the
certificate tests and the registration audit. No full suites.
