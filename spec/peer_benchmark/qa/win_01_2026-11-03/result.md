# win-01 result

Audited release candidate `04bceae9b9eeba947865083136d381c382f5a273` on clean `codex/win-01`. **No repository changes or fixes.** Proof tooling, logs and tables are under this directory. No commit, review, publication, preset/build/rig edits, permanent guards, full suites, or windowed runs.

| Platform | Release export through cel wrapper | Mac Godot `--main-pack` smoke | Production startup → New Run |
|---|---|---|---|
| macOS | OK, exit 0 | PASS, start + fresh-process resume | PASS |
| Windows | OK, exit 0 | PASS, start + fresh-process resume | PASS |
| Linux | OK, exit 0 | PASS, start + fresh-process resume | PASS |

Each export: `CEL_PACK_TEST paths=2939 failures=0`. Each smoke: `PACK_SMOKE START failures=0 seed=88100 room=(1, -1) played=shadow_step`; then `PACK_SMOKE RESUME failures=0 mode=combat seed=88100`. This used a new run, legal first combat/pre-battle, a naturally dealt card with legal targets, normal `current_run.save`, process exit/relaunch, full state/RNG comparison and unchanged Continue repair. The fight/card/save actions use production APIs, not simulated pointer/controller input.

**Numbered acceptance:**

1. All three full application exports passed; native dependencies inspected. Logs: `logs/export-{macos,windows,linux}.log`.
2. All three packs passed the requested sequence above. Tests/console are excluded; release templates prohibit script/path overrides. The Mac editor needs a task-local host debug-library shim before it can mount release packs. Its features remain macOS/editor, not target/release. A real Mac release default headless boot also exited 0; it does not establish graphical playability.
3. Static audit: 4,908 source/config files, 8,408 references, zero mis-cased references; 23 dynamic templates have zero fixed-component case mismatches. Each PCK: 9,955 entries, zero illegal names/case collisions. Actual runtime writes: 48 files, zero illegal names. All platform API sites, writers, length models and qa-19 delta are in [audit tables](proof/audit-tables.md).
4. No permitted-class defect was found to fix. Failing-before/passing-after product checks are therefore not applicable. All remaining findings below are reported, not edited.
5. All existing filenames, saves, fields, mechanics/RNG, protected assets, and input behavior remain unchanged. No typed-array assignments were added to product code.

**Findings by severity:**

- **Wrong behaviour, tooling-only:** packed `scripts/battlefield_rules/bot_policy.gd` cannot load because excluded `tools/encounter_bot.gd` is its superclass. All three canonical script audits: `PACK_SCRIPT_AUDIT scripts=563 invalid=1`, exit 1. No gameplay caller found. Fix: move the adapter into tooling and update tool/test references, or deliberately package its dependency.
- **Wrong behaviour, developer override:** `TODO_DESIGN_save_path` — explicit `LABYRINTH_USER_DIR_NAME` retains Windows-illegal characters/reserved names/trailing dots. It determines save paths, so the brief prohibits changing it. Owner decision: constrain developer namespace inputs.
- **Wrong behaviour, developer cache:** a 120-character namespace makes the modeled CanvasShaderRD path 313 characters; normal standalone/Steam models are 228/236. Save/archive maxima are 135/143/220, all below 260. Fix: bound developer namespaces using the cache path budget. This is a source-derived model, not a Windows GPU observation.
- **Unconfirmed Windows compatibility risk:** one new project-rule literal at `sfx_cue_router.gd:55`; typed/read-only locally. The other new site, `Font.get_rids()`, is verified typed and is a false positive. Total 710 candidates versus qa-19's 708; no confirmed new untyped transfer. Fix the constant with an explicit typed constructor if approved.
- **Cosmetic/diagnostic:** existing duplicate placeholder UID, 24 cel canvas touch-up skips, NumPy warnings and forced-exit resource warnings. Sandbox certificate/timing-cache permission diagnostics also occurred. Details and one-line follow-ups are in the tables; no assertions were rewritten.

**Tests:** cold import exit 0; Python default **`Ran 178 tests in 31.029s` / `OK`**, 19 modules, zero failures/errors; typed focused check **`TYPED_NEW_SITES PASS native_get_rids_typed=true ground_burn_constant_typed_readonly=true`**; export/pack/startup results above. No changed product scripts required additional focused suites. Expected failing script-audit logs are retained.

**Proof for the design owner:** [commands](proof/commands.md), [final smoke results](proof/final-smokes.json), [pack identities/native inventory](proof/pck-audit.json), [complete tables](proof/audit-tables.md). No captures were requested or produced. Real Windows/Linux launch must still establish native DLL/SO loading, target/release feature behavior, GPU/shader/cache paths, input/Steam/Deck integration, audio, permissions and playable save/resume.

**Chosen defaults:** proof seeds 88100–88139 (first usable seed 88100), first legal target/card, 180-second smoke/script-audit timeout; 45-second boot deadline/60-second wrapper cap; native default boot 600 frames at maximum 60 FPS/45-second cap; example date 2026-11-03 and synthetic hex hashes for length modeling. All are proof-only named fields. Export timeout and namespace limits come from existing tooling, not new tuning.

Cleanup status is recorded in `proof/cleanup.json`; exported applications/packs and temporary saves are removed after writing this report. Generated import/cel caches in the worktree remain available for the owner; Git remains clean.
