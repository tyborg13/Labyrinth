# fix-10 implementation and proof

Binding design: `spec/peer_benchmark/element_rules/design.md` sections 3–4.
Changes stay uncommitted for the design owner. No design, motion, rig bindings,
views, balance, analytics, saves, assets, or input paths are changed.

## Live and retired guards

1. **Weaver continuity remains live.** The four solo/squad × range/sight fixtures
   now check marks on the first Weaver activation, then exactly those three
   health-3 Outcrops on its second activation. Helpers approach from the hero's
   side to leave the raise unobstructed. The original Lash fallback, cancelled
   badge, later scheduling, unreachable Time, no fabricated analytics, and
   reachable hit/attribution assertions all remain. Reachable Lash approaches
   from behind the Weaver, avoiding the real Outcrop sight blocker. The hover
   proof likewise waits for the second activation.
2. **Weaver chips remain live.** Both the at-rest and installed live-scene guards
   expect the already registered `upheaval` icon for Thornwall.
3. **Lifetime-only terrain is retired.** The actual destruction fixture used
   Ice Pillar (the brief called it Bramble). Both kinds are retired. There is no
   live lifetime-only terrain: `BoardSurfaceRules.terrain_is_live` requires HP,
   and Outcrops have HP without a lifetime. Remove only the lifetime-body/death
   mark and invented-health-bar assertions. Removed/destroyed HP terrain,
   consumed traps/illusions/surfaces, displacement ghosts and privacy remain.
4. **Composite Command remains live.** The partner-line fixture now resolves
   `lightning_strikes` with `line_between_thralls`. Both aura-entry and aura-exit
   cases still assert a real hit, exact resolved Command damage and preview
   damage at the post-movement origin. No combat production change was needed.
5. **Cast playback was a production regression.** The presentation selector maps
   only these two enemy/action combinations onto their protected selectors.
   Arc Thrall also reaches its existing authored contact adapter through the
   shared dispatch. No compiled motion or bound case file changes. Captures now
   choose live actions through the runtime selector, rather than matching the
   retired action name from the protected motion file. Weaver proof checks
   delayed Upheaval marks at contact and rejects early Outcrops.

## Focused negative controls

Run alone, before other suites:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-10 && python3 tests/fix10_mutations.py
```

The script runs controls before/after, mutates one implementation at a time,
requires the named assertion failure with no parser/script error, and restores
exact original bytes in `finally`. Logs and the mutation matrix are in
`output/fix-10/mutations/`. It covers missing/early marks, missing raises, wrong
health, Lash fallback/Time/cancellation/attribution, both chip surfaces,
partner-line hits, Command resolution/preview origin, both clip selectors and
the Thrall contact adapter. Python production tests additionally remove real
contact/progression and mutate early/missing marks and premature terrain.

## Proof for the design owner

The sandbox has no window server. No native proof was attempted or claimed.
Run this exact command from the owner environment:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-10 && bash tests/fix10_owner_proof.sh
```

That script contains the exact seven `visual_probe_runner.py` commands: front/rear
Thrall and Weaver production captures, Seer production capture, continuity hover
states, and live chips. Thrall uses `--view "$view"`; both figures independently
validate actual cast snapshots against `--expect-facing "$view"`.
All require 1920×1080 and 100% UI scale. Cast PNGs and result manifests go under
`output/fix-10/native/`; continuity/chip captures use runner-isolated `user://`
paths recorded in their result manifests. Production exports include the real
contact and at least six progression representatives. The cast scripts also
retain their real resolver, sound, pose, canvas-bound and recovery assertions.

No inspection fixture command is required by this unit's recorded contract:
the design owner checks the casts in the owner build. No peer review,
commit, publication, fixture packaging, or queue changes are performed here.

## Chosen defaults

All are proof-only fields; none alter player-visible values:

- `REACHABLE_HERO = (5, 1)`, `CRAWLER_POS = (2, 8)`,
  `HARRIER_POS = (8, 8)`, `THRALL_PARTNER_POS = (8, 2)`.
- Production subprocess timeout: `PROOF_TIMEOUT_SECONDS = 180`, matching the
  existing production harness. Task ID is `LABYRINTH_TASK_ID`, default `fix-10`.
- Weaver Python reports use a temporary output directory, preserving bound case
  evidence and preventing parallel fixture collisions.
- Native contracts: seven minimum proof exports, board region
  `[250, 150, 1400, 800]`, minimum luma range 20 and standard deviation 2.
  These complement the capture scripts' semantic/contact checks.

## Design placeholders and remaining work

No `TODO_DESIGN` placeholders were needed. Test outcome logs and any unrelated
full-suite failures are reported in `output/fix-10/RESULTS.md`. Native image
inspection and the owner-assigned commit/review/publication steps remain with
the design owner.

## Feedback 1

`scripts/enemy_mechanics/cast_presentation.gd` fills the rerouted casts' step
metadata from the acting enemy's identity and its authored intent. Thornwall,
Tether, and both Icefall phases therefore retain their authored banner names.
Cancelled steps retain their existing cancellation metadata. The rig adapters,
motion and bound case files are unchanged.

The three production capture harnesses now record the actual banner Label and
visibility during cast playback. `tests/fix10_capture_contract.gd` verifies those
values against authored names and, for Thrall/Weaver, verifies every cast frame's
facing against the independently requested expectation.

Run `python3 tests/fix10_feedback_mutations.py` alone for the front/rear playback
controls, wrong-flag negatives and a source mutation that drops the label. It
must reject the mutation in all four casts (Weaver, Thrall, Seer mark/land), then
pass restored controls. `PROOF_WORKERS = 3` is the only new proof-only scheduling
default. Logs/reports are under `output/fix-10/feedback-1/`. Feedback verification
is focused only; the director reruns the windowed commands above.

## Feedback 2

Thrall fixtures now supply their selected view's actor, partner and contact
tiles before either planning or playback, matching the Weaver fixture approach.
Previously `install()` reflected only playback, so the whole-run planner still
received front-view fixtures when capturing the rear. The positions and
reflection are the existing proof geometry; no new defaults or rig data are
introduced. Bounds, actual facing, actor-only playback and banner checks remain
enabled, and the owner's native capture timeouts remain 900 seconds.

`tests.test_rr07_production.RearCropTests` runs real rear playback with
`--logic-only --validate-crop`, including the two-pass crop plan and per-frame
canvas checks. It reproduces the idle-frame escape before the fix. Focused
verification also runs the existing production and crop-plan tests; logs are
under `output/fix-10/feedback-2/`. Headless crop validation checks geometry;
the director reruns `bash tests/fix10_owner_proof.sh` for windowed pixels.
