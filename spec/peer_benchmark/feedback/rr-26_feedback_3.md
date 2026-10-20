# rr-26 feedback 3 (director): finish the integration merge by consolidating the shared humanoid tooling

**Context.**
- Integration (`6077f772d`) now holds the Thrall (rr-24), Mortar (rr-25) and Weaver (rr-21) on rig v2.
- The director has started merging it into this worktree (`git merge --no-commit 6077f772d`). The merge is in progress.
- All conflicts are resolved except `tools/humanoid_cutout/gates.py`. Registries, shadow cache, `cutout_context.gd`
  and `presentation.gd` are resolved; the shadow cache already holds the Mimic's and the Seer's rebuilt records.
- Three parallel units built their own copies of the same tooling. This round makes it one of each.
- **Git:** do not run any git command that writes (add, commit, merge, checkout, stash, reset). Remove conflict markers
  by editing. The director commits.

**Decisions (binding).**

1. **One detached-provenance classifier.**
   - Home: `tools/humanoid_cutout/source_space.py`.
   - It implements spec §1 "Negative space vs holes" exactly:
     - a pocket passes when every pixel maps to air in the approved painting;
     - a detached component passes only if it is detached in the approved painting (strict provenance, any size,
       any darkness).
   - Fold this unit's `rest_space.DetachedSource` into it.
     - Where the two implementations differ, the one that matches §1 wins. Report every behavioural difference you
       find.
   - Delete the duplicate classification code from `rest_space.py`. Keep a helper only if something else uses it.
   - The Mirror's `rigid_air` air policy stays. It is a separate concern: pockets on rigid pieces.
   - Resolve `native_errors` in `gates.py` to one path, with every caller migrated.

2. **One compact sample-record format.**
   - Canonical format: `full_samples: {file, sha256}` (rr-21's).
   - Migrate both writers to emit it: `experiments/cutouts/slag_mortar/rr22_records.py` (`full_report`/`full_sha256`)
     and `experiments/cutouts/hollow_mimic/proof_records.py` (`full_evidence`).
   - One reader: `bone_evidence.read_report(case)`.
     - Remove `load_samples` and `read_samples`, and point their importers at `read_report`.
     - `test_rr21_review`'s containment-mutation test must stay meaningful: the guard keeps containment as its first
       operand, and removing it is still caught. Adapt the test only if the guard moves. Never weaken it.

3. **One action dispatch.**
   - Case-owned adapters are declared only by `integration.json` `"action_adapter"` (a resource path).
     - The Mortar already uses it.
     - Rename the Weaver's `"action_script"` to `"action_adapter"`.
     - Move the Mirror's `Presentation.ACTION_ADAPTERS` entry into the Mirror's `integration.json` and delete the
       const.
   - `"contact_playback_clips"` stays the declaration for the shared `contact_actions.gd`.
   - `"step_selectors"` stays as clip selection inside `clip_for`.
   - `run_scene.gd` gets one call site:
     - resolve the acting unit as `source_actor_key`, falling back to `actor_key`;
     - try the case adapter first, then the shared contact adapter;
     - otherwise fall through to the existing paths.
   - No timing, gameplay, cue or outcome change.

4. **Continuations stay as merged.** `gait_continuations.active_recipe` and `humanoid_continuations.gd` are not in
   scope.

5. **No visible change.**
   - Every unit's pose rows stay byte-identical: Seer, Thrall, Mirror, Mimic, Weaver, Mortar and Capacitor (each view
     and clip it has).
   - Prove it with a before/after pose-hash table: before = each unit's committed records, after = the consolidated
     tree.

6. **Records.**
   - Regenerate every headless record that binds a changed runtime or tool hash: samples, compact records, headless
     gates.
   - Then list, per unit, the exact windowed command sequence the director must run (the stages its proof script
     defines) to bring native gates, production and review records current.

7. **Strict census.** Zero unmatched detached components for the Mimic, Seer, Mirror, Capacitor, Thrall, Weaver and
   Mortar (both views, every clip).

8. **Tests.**
   - Focused tests only:
     - each unit's test files;
     - the gates / bone-evidence / source-space tests;
     - the Godot runtime checks under `tests/rr*/`.
   - Report the command and its result for each. No full suites.
   - Delete dead code you make dead.
