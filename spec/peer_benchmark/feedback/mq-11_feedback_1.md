# mq-11 feedback 1 (director)

The `TODO_DESIGN` fields were my brief's gap. I've now filled them as director data. Don't change any of these values:

- `spec/art_identity/maquettes/hollow_mimic/owner_review/design.json`:
  - the 16-tuft mop and the scalp, measured from the built maquette;
  - generator: `spec/peer_benchmark/staged/mq11/mimic_hair.py` on the integration branch.
- `spec/art_identity/maquettes/slag_mortar/owner_review/design.json`: belt, flap rows, rear ratio 0.8.
- Two director edits in your files. Keep both:
  1. `candidate.py` GATES `front_thigh_fraction` is now **1.25**, not 0.5. The source art's front flap reaches the
     knee. Mid-thigh was my brief's mistake.
  2. `measurements.py`: the flap centre-line reference is now **the vertical through each flap's own belt attachment
     centre**, `pelvis_frame` origin ± forward × `forward_radius_m`. It was the vertical through the pelvis joint.
     - In the 3/4 views, the body's front and back midlines project about 25 px off the joint line, so the literal
       gate could never pass.
     - The ±4 px tolerance is unchanged.

## Fix
1. **The native probe crashes inside Blender.**
   - In director run `director_01`, `native_probe.py` imports `curate_delivery`, which imports PIL.
   - Blender's Python has no PIL: `ModuleNotFoundError: No module named 'PIL'`.
   - Log: `tests/mq11_proof/director_01/hollow_mimic/bridge/accessory_measurements.log`.
   - Make the probe import only what Blender's Python has. Do the hashing and writing with stdlib/numpy, or move the
     PIL-dependent steps to the host-side workflow.
   - Add a regression test: import `native_probe` with PIL made unavailable, and it must load.
2. **Tests.** Update `tests/test_mq11_accessories.py` for filled design data:
   - tests that asserted the live files are unresolved must use their own fixtures;
   - flap length uses the 1.25 fraction;
   - add a centre-line test against the attachment line (a flap centred on its attachment passes, one shifted 5 px
     fails).
3. Focused tests only. Don't run the bridge. The director runs `workflow build` natively afterwards.
