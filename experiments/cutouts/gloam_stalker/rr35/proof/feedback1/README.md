# rr-35 — feedback 1

All work remains uncommitted on `codex/rr-35`. Motion tuning stopped at the
explicit director limits: **front slash 30/25**, **gait lift 3**. The strict
front slash and rear move minimum-reach gates still fail. The 4° action lean
conflict is resolved. No gate was weakened, and no value beyond the supplied
bounds was tried. Native proof and publication remain director-owned.

## Final director values

| Channel | Final value |
|---|---|
| Slash torso lean: wind-up / contact / follow-through | −4° / 4° / 3° |
| Slash torso forward: contact / follow-through | 6 / 5 px |
| Front `hand_far.forward_px`: contact / follow-through | **30 / 25 px**, cap reached |
| Rear `hand_far.forward_px`: contact / follow-through | **20 / 16 px**, base keys; no override added |
| Rear `hand_far.lift_px`: wind-up | 14 px, existing override preserved |
| Move `lift_px` | **3 px**, authorized floor reached |
| Move `lane_narrowing` | 0.4 |

The staged protected motion, case import and production import are byte-identical.
Only three scalar spans differ from the director-supplied feedback-1 file: front
contact 25→30, front follow-through 20→25, and gait lift 4→3. All other supplied
bytes, including wording, are exact. The immutable supplied copy and each
measured 1 px increment are in [the input receipt](rr35/proof/feedback1_inputs.json).

## Remaining design decisions

- `TODO_DESIGN_front_slash_reach`: **17.137160 px < 18 px** at the 30/25 cap.
  Rear slash passes at **25.734375 px**, so its forward override was not added.
  The front arm's requested reach is 95.875434 px at contact versus a rest
  segment sum of 65.801515 px; the existing solver clamps it. This is diagnostic,
  not a new exception or a change to the director data.
- `TODO_DESIGN_rear_move_foot_near_reach`: **25.094914 px < 25.409323 px** at
  phase **0.860219238**, even with lift 3 and lane narrowing 0.4. Lowering below
  3 or changing any other gait value was not authorized and was not attempted.

`TODO_DESIGN_slash_torso_lean_limit` is removed from active inputs and production
metadata. The actual-bone action checks pass both views with the unchanged 4°
limit. The two remaining placeholders describe the exhausted bounds.

## Derived closure and gates

The layouts, motion compilation, production assets and density derivations are
rebuilt from the final staged bytes. Motion-conditioned gait/action continuation
recipes are regenerated from the existing approved source surfaces to close the
newly exposed seams and detached pixels. Rest paint, carapace ownership, skin
weights, draw order, anatomy and all other clips retain the round-0 design.
No art, audio, fonts, dependencies, runtime rules or generic gate changes are
introduced by feedback 1.

The accepted round-0 cut remains editable in `rr35/`. It uses a rigid head,
fused torso/carapace, pelvis, blade-claws and wrapped feet with six skinned
arm/leg/cape surfaces. Both source rests have 0 visible-pixel mismatches. As
recorded in round 0, front `(173,170)` has invisible RGB `(27,15,20)` under alpha
0; only the derived copy normalizes that one texel to transparent black. The
protected painting stays unchanged. Production native rest rebake and shadow
refresh are still pending.

Measured stance policies are unchanged: near/far **32.537166°/53.242111° front**,
**61.332177°/40.635037° rear**. Front near arm/blade and rear far arm/blade stay
above torso/pelvis/capes; head stays above both arms. Every other rig and the
accepted source/density PNGs are hash checked by `rr35_preservation.py`.

## Verification

Current exact commands, exits and result lines are in
[verification.json](rr35/proof/verification.json), with full ignored logs under
`rr35/proof/logs/feedback1/`. The round-0 report is retained separately under
[round0/](rr35/proof/round0/verification.json). Full project suites and windowed runs were
not attempted. The four round-0 focused failures are not all resolved: the two
lean-related failures pass, while front slash and rear move reach remain red.

Reproduce current headless proof from the task directory:

```sh
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_case.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_build.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_density.py --rebuild-derived-sources
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_evidence.py --refresh
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_gates.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_seams.py
python3 -B -m unittest tests.test_rr35_cutout tests.test_rr35_production
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_preservation.py
```

`rr35_continuations.py` and `--actions` regenerate the recorded motion-conditioned
coverage from current samples; normal rebuild/density/sample refresh follows.
The focused gate and test commands deliberately retain nonzero exits for the two
unresolved design limits. No peer review, commit, branch change or publication
was performed.

## Proof for the design owner

These exact stages use the visual runner at **1920×1080, 100% UI scale**. Capture
artifacts stay gitignored. The strict native/sheets/review acceptance commands
remain blocked by the two reach failures until the director resolves them.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh review
```

Outputs: `rr35/proof/{native_rest,native,contact_sheets,idle_native,production_native}`
and the idle/review MP4s at the proof root. `density` performs the native rest
rebake, rest recording, scoped Gloam shadow refresh and provenance seal. No new
`inspection_fixture.py` command is requested; the director owns fixture preparation.

## Chosen defaults and files

No new defaults were chosen in feedback 1. The final tuning values follow only
the director's explicit stepping rules and caps. Existing diagnostic defaults
remain in [chosen_defaults.json](rr35/proof/chosen_defaults.json).
[Complete current file inventory](rr35_files_changed.txt).
