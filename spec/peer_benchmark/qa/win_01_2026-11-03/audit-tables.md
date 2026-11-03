# win-01 audit tables

Release candidate: `04bceae9b9eeba947865083136d381c382f5a273`, branch `codex/win-01`. No tracked edits. All findings existed in that snapshot. No product fixes, permanent guards, commits, reviews, or windowed runs.

## Resources and packages

| Audit | Result | Evidence |
|---|---|---|
| Literal `res://` reference case, against actual directory entries | 4,908 source/config files; 8,408 references; zero case mismatches | `static-audit.json`, `case-mismatches.md`, `../logs/static-audit.log` |
| Dynamic templates | 23 templates; zero mismatches in their fixed path components against matching disk names; arbitrary future IDs are not exhaustively proved | `dynamic-case-audit.json` |
| Source Windows filenames | Zero reserved names, illegal characters, or trailing dots/spaces | `static-audit.json` |
| PCK directory, each platform | 9,955 entries; zero illegal names or case-fold collisions | `pck-audit.json`, `<platform>/pack-table.json` |
| Windows/Linux native dependencies | Both required release native libraries exist and match repository source SHA-256 bytes | `pck-audit.json`, `<platform>/export-members.json` |
| macOS native dependencies | Both universal libraries exist. Export ad-hoc signing changes their bytes; `codesign --verify --deep --strict` returned 0. The Steam library's ad-hoc signature and loader-relative dependency were inspected | `../logs/native-macos-{inspection,signature-details}.log` |
| All canonical shipped gameplay/asset scripts | **562/563 load; one invalid** on every platform pack | `../logs/pack-<platform>-script-audit-canonical.log` |

The invalid script is `res://scripts/battlefield_rules/bot_policy.gd`: its superclass/preload `res://tools/encounter_bot.gd` is excluded from every export. Every discovered caller is under tools/tests; no gameplay caller was found. This is a packaging defect, not a reference-case defect. Suggested fix: move the tooling-only adapter under `tools/` and update its tool/test references, or explicitly package its dependency if it must be runtime code. Presets were protected and untouched.

The 25 lexical unresolved paths in `static-audit.json` are 23 format templates plus the extensionless `melee` asset stem and `column_torch_` prefix. Stem loaders add approved extensions; these are not 25 missing resources. Generated imported targets and bracket-bearing font paths are included in the case inventory. Provenance strings pointing at excluded generators are metadata, not runtime loads.

## Every requested platform API site

No `OS.execute` or `OS.shell_open` sites, and no hard-coded platform-absolute paths, were found in shipped source/config. Full site/line inventory: `platform-sites.md`, `absolute-paths.md`.

| Sites | Windows behavior | Linux behavior |
|---|---|---|
| `addons/godotsteam/godotsteam_plugin.gd:92`, `OS.get_name()` | Editor plugin checks installed Windows Steam DLL versions | Branch skipped; editor plugin does not run in a game |
| `scripts/asset_loader.gd:333`, `OS.has_feature("editor")` | Release uses imports rather than editor source-file preference | Same; Mac-editor pack proof has `editor=true`, so cannot establish release-feature branches |
| `scripts/cel_look.gd:10`, `LABYRINTH_CEL_LOOK` | Optional environment override; otherwise approved `all` default | Same |
| `scripts/combat_art_treatment.gd:55`, `LABYRINTH_ART_LOOK` | Optional art-mode override | Same |
| `scripts/input_router.gd:233,235`, `SteamDeck`, `LABYRINTH_DISABLE_STEAM` | Deck override possible; default non-Deck; test runner disables Steam | Steam Deck env/native/model detection; test runner disables Steam |
| `scripts/parallel_runtime.gd:15,16`, `LABYRINTH_USER_DIR_NAME`, `LABYRINTH_TASK_ID` | Optional custom `user://`; explicit-name sanitizer misses Windows characters/reserved names/trailing dots | Same strings are generally legal, except slash/NUL; normal Steam launch has neither override |
| `scripts/performance_telemetry.gd:398`, `OS.get_name()` | Adds `Windows` to JSON device context | Adds `Linux` |
| `scripts/performance_telemetry.gd:408`, `SteamDeck` | Deck override | Deck identification |
| `scripts/performance_telemetry.gd:446`, `LABYRINTH_TELEMETRY_TOKEN` | Optional upload credential; no credential values were read or logged | Same |
| `scripts/performance_telemetry.gd:465`, `OS.get_name()` | Selects Windows Steam metric prefix | Selects Linux/Deck Steam metric prefix |
| `scripts/performance_telemetry.gd:725`, `LABYRINTH_TELEMETRY_ENDPOINT` | Optional endpoint overrides setting; blank keeps local-only default | Same |
| `scripts/run_scene.gd:1936`, same endpoint env | Decides whether performance collection has an upload destination | Same |
| `scripts/steam_service.gd:257`, `LABYRINTH_DISABLE_STEAM` | True disables Steam initialization | Same |
| `scripts/steam_service.gd:109,526`, Steam `user://` switch | Active account chooses `%APPDATA%/Escape the Umbra/steam/<numeric-id>/`; parallel namespace takes priority | `$XDG_DATA_HOME/Escape the Umbra/steam/<numeric-id>/`, otherwise `~/.local/share/…`; same priority |
| Steam engine cache preservation | Tries links, falls back to directory mirroring when privilege denies them; cache files never copied/overwritten | Same fallback, usually links work; native renderer proof still needed |

Absolute paths are derived from `ProjectSettings`, the engine/user-data root, executable directory, or resolved asset bases. Rig loaders accept absolute inputs but contain no absolute literal production path. Nothing in humanoid rigs or maquette runtime was edited.

## Runtime filenames and lengths

`write-sites.md` records all 146 read/write/path/time candidates, manually separated into asset reads, editor updater actions, application writers and cache-directory operations. Player runtime writers are progression/run saves, recent-event history, settings, analytics, performance telemetry, and Steam pending stats. Editor updater `user://update.zip` is legal and not a game-launch action. No production screenshot writer was found; capture tools/tests are excluded.

| Writer | Name construction | Windows result |
|---|---|---|
| Profile/run checkpoint | `progression.json`, `current_run.save`, `.tmp`, `.backup` | Legal; unchanged |
| Migration archive | Original save + `.pre-surfaces-v5.<16 hex>[.tmp]` | Legal; unchanged |
| Settings/recent events | `settings.json`, `recent_events.json[.tmp]` | Legal |
| Analytics | `analytics/events-YYYY-MM-DD.jsonl`, `meta.json` | Legal; ISO timestamps and random IDs stay JSON fields |
| Telemetry | `telemetry/performance-YYYY-MM-DD.jsonl`, `meta.json` | Legal; same field/path distinction |
| Steam queue | `steam_stats_pending_<sanitized numeric ID>.json` | Legal for numeric uint64 IDs |
| Logs | Engine log basename/rotation; runner uses explicit task-local `godot.log` | Legal modeled basenames; native OS logging still needs real launch |
| Engine shader cache | `shader_cache/<shader>/<SHA256>/<SHA1>.<validated-api>.cache` | Legal components; long developer namespace can exceed MAX_PATH |

The shader layout and API-name sanitization are from [Godot 4.6.1 ShaderRD](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_rd/shader_rd.cpp#L395-L405). This is a source-derived length model, not observed Windows renderer behavior. Engine pipeline/device caches are backend controlled; the repository cache helper mirrors their existing directories rather than naming new files. Driver-specific behavior remains native-launch proof.

`runtime-lengths.md`/`.json` enumerate 63 paths using `C:\Users\<20 chars>\AppData\Roaming`, standalone Godot app-data, a maximum uint64 Steam ID, and the existing 120-character developer namespace allowance. Application save/archive maxima are **135 / 143 / 220** characters. The representative actual engine `CanvasShaderRD` cache layout is **228 / 236 / 313** characters respectively: developer-only namespace exceeds 260. Shorter actual Steam IDs reduce these lengths. A nonnumeric forged 80-character Steam ID is outside the native API contract.

`observed-paths.json`: 48 files actually written during pack/native headless work; zero illegal components. Names include analytics/telemetry JSONL, metadata, progression, current run and migration archives. No raw timestamp was used as a filename.

`TODO_DESIGN_save_path`: `_safe_user_dir_name("win-01?<>\"|*")` preserves every illegal character; `CON`/trailing-dot inputs are also not excluded by its implementation. This is a developer-supplied namespace hazard that also controls save locations. The brief explicitly protects save paths, so it was not changed. No default standalone/Steam save path is illegal or too long in the model.

## Typed arrays since qa-19

| Snapshot | Scripts | Candidates | Changes |
|---|---:|---:|---|
| qa-19 merge `ea8e19232` | 559 | 708 | Baseline retained the parked rewrite's original literals |
| Release candidate | 563 | 710 | Two added sites; zero removed |

- `scripts/sfx_cue_router.gd:55`, `GROUND_BURN_KINDS`: new bare `Array[String]` constant violates the project rule; it is typed and read-only on this Mac's Godot 4.6.1. No confirmed runtime hazard; Windows remains untested. Suggested fix: explicit typed built-in `Array` constructor.
- `scripts/section_map_skin.gd:267`, `font.get_rids()`: scanner false positive; the native return is a typed `Array[RID]`, verified directly. No fix needed.

Current pattern totals: 608 literal, 83 unresolved-source, 13 dictionary-get, 4 untyped-transform, 2 conditional; no untyped-source/map hits. Existing qa-19 debt was not mechanically rewritten. `typed-delta.json` contains exact expression-based comparison independent of line shifts. `typed-and-namespace.log` contains the focused runtime result.

## Limits, probe corrections and other diagnostics

All external proof scripts run with the repository runner. Steam is disabled. `--main-pack` is always mounted from an empty bootstrap project, with only two read-only host-native-library symlinks; game scripts/assets come from the pack. Host engine reports macOS/editor, not Windows/Linux/release. The first unshimmed attempt aborted in Mac native extension lookup; its log is retained. This does not reproduce a Windows/Linux launch defect.

Initial proof-only assumptions were corrected: a first dealt hand had no targetless card, so the probe now chooses actual legal targets without changing hand/RNG; startup's legitimate intermediate null `current_scene` is awaited. An exploratory direct `.gdc` load produced duplicate script identity/inner-class compiler errors, so final audits use the normal canonical `.gd` remaps; only the bot dependency failure remains. Historical failed probe logs remain separate from final logs.

The real macOS release binary refuses `--main-pack`/script injection because path overrides are compiled out. A subsequent default headless 600-frame launch without overrides exited 0. This proves launch under the sandbox, not a rendered or playable session. Both test/console entry points are excluded by release filters, so combat/play/save/load proof uses external scripts with Mac Godot and production engine/store APIs. Full UI input/card animation and target-native behavior are not claimed.

Other existing diagnostics, outside the permitted fixes:

| Severity | Finding | One-line follow-up |
|---|---|---|
| Cosmetic/potential wrong placeholder lookup | Duplicate UID for `player_reaver_idle.png` / `player_reaver_anime_idle.png` during import/export | Give the two resources distinct import UIDs and verify their users |
| Cosmetic | 24 approved cel entries skip inherited touch-ups because piece/rest canvas sizes differ | Design owner supplies canvas-correct per-piece touch-ups if those skips are unintended |
| Cosmetic/tool output | NumPy/Accelerate divide/overflow/invalid matmul warnings during cel build; wrapper still verifies all 2,939 packed hashes/runtime loads | Verify finite math before narrowing/silencing those warnings |
| Environment limitation | macOS certificate-store `ret != noErr` in the sandbox | Check normal OS certificate access on a native launch |
| Cosmetic/shutdown | Forced proof/native headless exit reports two resources still in use/ObjectDB leaks | Trace scene-exit ownership separately if reproduced in an ordinary quit |
| Environment limitation | Default suite cannot update the read-only Git timing cache | Owner may persist timings outside this sandbox; tests passed |

Exact non-fatal timing-cache permission diagnostic (suite exit 0):

```text
Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted: '/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/tmpw7mlh46f'
```

Temporary proof-tool syntax validation: `PROOF_TOOL_PARSE PASS 11 temporary Python files (in-memory compile; no cache writes)`. An initial `py_compile` invocation tried the system Python cache and was denied: `PermissionError: [Errno 1] Operation not permitted: /Users/borgerding/Library/Caches/com.apple.python/private/tmp/labyrinth_codex`. Validation was rerun in memory with no filesystem cache.
