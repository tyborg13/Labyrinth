# qa-70: demo whole-run hunt

Base/HEAD `ddf534d55`, branch `codex/qa-70`. Changes are uncommitted. One fixture call repaired; no product behavior, scene, data, asset, balance value, analytics or assertion changed. Tools/raw evidence: `/private/tmp/labyrinth_codex/qa-70/`. Commands, proof contracts and chosen diagnostic defaults: [README](README.md).

| Requirement | Observed result |
|---|---|
| 1. >=12 demo runs in both campaigns, plus 3 ladder runs; per-decision presentation checks | **PASS:** six default + six no-Embrace + three ladder, all ended; 5,990 decisions; zero model mismatches and zero literal `SCRIPT ERROR:` markers. The ladder won all 17 fights naturally, with zero forced transitions. |
| 2. Boundary, end screen/links/focus, saves/Continue, progression and naming | **Headless checks pass; caveats below.** Thirteen clears end in section 0; no later room visited. Full panels/one-time links, focus reachability, one retained panel and idempotent completion pass. Two-process Exit to Desktop → Continue preserves the complete committed run/combat. Clear profiles have zero escapes/Depth unlock and one demo clear. Chronicle `demo_clear` records and approved `VICTORIOUS` recap/dragon naming pass. Five locked keystone teasers are covered by the existing panel test/probe. Exported writes stay in the Demo folder; the editor-only hook has a routing caveat. GPU pixels, hardware navigation and live Discord invite validity remain unverified. |
| 3. Sanitized Steam Demo macOS export/launch | **PASS for export, pack and paced native launch:** cel build → Steam-script rsync exclusions → `tools/export_game.py --preset "Steam Demo macOS"`; `CEL_PACK_TEST paths=3076 failures=0`; launch exit 0 with zero script errors. Exactly three files changed, all under `app_userdata/Escape the Umbra Demo`; full-game profile/save sentinel bytes and mtimes are unchanged. `export_smoke.py` rejects this preset (exit 2), as permitted to report by the brief. |
| 4. Findings with reproductions/provenance | Below; exact commands and full ledgers remain in README and the private evidence directory. No untriaged campaign model/runtime record remains. |

| Campaign | Ended | Demo clear | Embrace | Decisions |
|---|---:|---:|---:|---:|
| default, seeds 4–9 | 6 | 4 | 2 | 2,690 |
| no-Embrace, seeds 4–9 | 6 | 6 | 0 | 2,888 |
| ladder, seeds 4–6 | 3 | 3 | 0 | 412 |

Findings:

- **FIXED — stale interrupted-Embrace test fixture.** Seed `2902`, fixture checkpoint after the profile receipt commits and before Continue; no hunt decision number. `tests/demo_boundary_test.gd:282` called the removed `_run_state_with_profile_grimoire` method, then line 260 accessed an empty result. Original log: `demo-boundary.log`, two script errors despite `DEMO BOUNDARY TEST RESULT: PASS (558 assertions)`; runner correctly exited 1. One line now calls the current production `loaded_room_state.gd.merge_profile` helper. Every assertion is preserved. Regression: `demo-boundary-fixed.log`, exit 0, **`DEMO BOUNDARY TEST RESULT: PASS (566 assertions)`**, zero script errors; eight previously skipped assertions now execute. The obsolete call was authored in `868c9bf2c` and entered release with demo merge `995bc7f92`; perf-66 had already extracted the helper in `4c11b51ab` / merge `2faecbec8`. Reproduce with the focused boundary-test command in README; `fixture-fix.patch` preserves the complete change.
- **OPEN — editor-only demo flag does not route the default save folder.** Seed `701104`, startup/decision 0. With `LABYRINTH_DEMO=1`, Steam disabled and only the runner namespace variables removed inside an isolated HOME, `user://` is `.../Godot/app_userdata/Escape the Umbra/`; saving a demo profile/run changes the synthetic full-game sentinels. `scripts/demo_build.gd:6` enables demo rules, while `project.godot:14` changes the application name only for the `demo` export feature. This behavior originates in `28549da21`, integrated by `995bc7f92`. Exact reproduction: README's save-routing command; evidence `editor-save-routing.log` and `.json`. **The exported demo is isolated** (`export/save-routing-settled.json`); campaign per-seed paths are also isolated. No product routing workaround was applied.
- **TOOL LIMITATION — export smoke has no demo preset.** Seed/decision not applicable, CLI validation before launch. `tools/export_smoke.py:26–30` lists only the full-game presets; the requested command exits 2 with `invalid choice: 'Steam Demo macOS'`. Tool table: `7f0839763` / merge `d77a71c15`; the missing demo coverage became relevant when `995bc7f92` introduced the presets. No helper expansion was requested or made. `export-smoke.log` retains the exact rejection.
- **INHERITED environment diagnostic.** Every campaign seed has one macOS certificate error at startup/decision 0: `platform/macos/os_macos.mm:1014`, `Condition "ret != noErr" is true`. The same diagnostic is documented by qa-64. It is the sole finding group in each campaign report, with no script errors or failed run. No repository introducing merge applies to this engine/environment marker. Original import also retains the existing duplicate-UID warning.

Instrumentation triage: two early native launches used an uncapped `--quit-after 180`, interrupting threaded menu loading and emitting three preload/compile errors each. Both packed fonts load with expected data sizes. The original, unchanged app passes `--max-fps 60 --quit-after 900` with zero script errors and correct folder routing; see `export/triage.json`, `font-pack.log`, `export/launch-settled.log` and `export/engine-settled.log`. No startup fix is proposed. Original observer smoke/control revisions are also retained separately; none is counted among the 15 campaign runs.

Checks observed:

- Cold import exit 0; `CEL_BUILD` completed 3,076 approved inputs; protected input hashes unchanged.
- `QA70 OBSERVER VALIDATION: PASS board/stage/forecast/rail/Health poisoning detected; original references and state preserved`.
- `QA70 INPUT CONTROL: PASS normalized_prefix=40/40`.
- `QA70 QUIT MID DEMO: PASS saved_seed=4 mode=combat combat_hash=1254611098`.
- `QA70 PROCESS CONTINUE: PASS exact committed run+combat and fresh presentation`.
- `DEMO BOUNDARY TEST RESULT: PASS (566 assertions)`; `DEMO END PANEL TEST RESULT: PASS (466 assertions)`.
- `DEMO END PANEL PROBE VALIDATION: PASS (12 states)`; final whole-run/native panel scripts' headless parser checks exit 0.
- Python audit: 56 modules, 20 default modules selected. After the fixture repair: **`Ran 189 tests in 50.386s` / `OK`**, suite exit 0. Optional timing-cache write denied by read-only Git metadata. No full suites ran and no new repository Python module was added.
- `CEL_PACK_TEST paths=3076 failures=0`; native launch runner exit 0, zero script errors; `QA70 EXPORTED SAVE ISOLATION: PASS changed=3 outside_demo=0 full_unchanged=True`.

**Proof for the design owner:** README contains the exact two windowed commands, contracts and expected capture paths for whole-run `{combat,map,demo_end}.png` and the twelve approved panel/menu/settings/keystone states. Required size/scale: 1920×1080 / 100%. No windowed attempt or worker PNG capture occurred. The brief requests no inspection-fixture command; the director owns review, fixture, commit and publication.

**TODO_DESIGN:** none. **Chosen defaults:** diagnostic-only named bounds/seeds/paths in README, including six/six/three runs, inherited hunt Health/time/caps, and paced native launch at 60 FPS for 900 frames. **Open issues:** unnamespaced editor save routing, unsupported demo inventory-smoke preset, live Discord invite validity, and owner-only renderer/controller inspection. The Steam wishlist destination resolves to the [Escape the Umbra store page](https://store.steampowered.com/app/4530510/); local link dispatch uses the protected data URLs.
