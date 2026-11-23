# ux-18 round 1

The two title-menu suites walk Continue, New Game, Chronicle, Grimoire, Settings, Quit. The main-menu suite uses a checkpoint to enable Continue. The Chronicle fixture starts keyboard navigation at New Game and checks the node order for all six actions.

The table records the original assertion messages from the candidate's round-zero failures. Only the test route and its order expectations changed. All 12 failures cleared on the candidate. The Settings and pointer behavior assertions in the main-menu suite still run against the same controls with the same checks.

| Suite | Original failure message | Order change |
| --- | --- | --- |
| Main menu | Empty-space pointer motion must preserve Settings focus farther down the list | One Down after Chronicle now checks Grimoire focus across the pointer gap. The next Down reaches Settings and runs the original check. |
| Main menu | Sequential navigation must retain the last focused Umbra selection | The new Grimoire stop checks its molten selection and clears Chronicle's selection. The next Down reaches Settings and runs the original molten-selection check. |
| Main menu | Keyboard accept after empty-space pointer motion should open Settings | Enter runs after the extra Down has reached Settings. The original Settings visibility check remains. |
| Main menu | Keyboard ownership should focus Settings Back after empty-space pointer motion | The extra Down takes the keyboard route to Settings before Enter. The original Settings Back focus check remains. |
| Main menu | Returning from Settings should restore focus to Settings after empty-space pointer motion | The extra Down puts the existing open and Back sequence on Settings. The original Settings focus-return check remains. |
| Main menu | Mixed-input regression should establish a real stale New Game hover | The extra Down restores the intended Settings open and close sequence. The original pointer event then reaches New Game on the title. |
| Main menu | Later keyboard focus should remain on Settings while New Game is hovered | The corrected route returns to the title before the original stale-hover sequence puts keyboard focus on Settings. |
| Main menu | Focused Settings must outrank an earlier stale New Game hover during deferred restoration | The corrected route leaves Settings available for the original deferred restoration check, with New Game still hovered. |
| Main menu | Keyboard/controller handoff from a pointer gap must resume at the last selection instead of Continue Run | The corrected route leaves Settings available for the original pointer enter, pointer exit, and keyboard handoff. The assertion still requires Settings focus and excludes Continue. |
| Chronicle | Chronicle menu ordering | The test checks all six indices in order, including both adjacencies around Grimoire. |
| Chronicle | Chronicle keeps 92 px menu spacing | The test keeps the 92 px New Game to Chronicle check and requires 92 px for each new pair from Chronicle through Grimoire to Settings. |
| Chronicle | Keyboard navigation still reaches Settings after Chronicle | The next Down checks Grimoire and a separate Down checks Settings. The walk also checks Quit. |

## Release integrity

The original files in `/private/tmp/labyrinth_codex/ux-18/baseline/tests/` match their Git blob contents at release commit `f92582e85f72107cc80abf8c72e3bc4677a93dd9`. The SHA-256 of each file is identical in the snapshot and in `git show`.

| File | SHA-256 |
| --- | --- |
| `main_menu_input_test.gd` | `23b57ce77a0e26d1cf68fd80df364d3979f4e0eee8f493dc6dc08642ea9d7a8d` |
| `chronicle_test.gd` | `feb805571fd747b484a25349b1d6267a5ae87f893751a4bb667520224ffa7467` |

The previously recorded release runs passed with their original assertions.

## Capture baseline

The existing full baseline occupies 8.3 GiB (8,700,340 KiB). The slim baseline occupies 1.0 GiB (1,095,964 KiB). The revised launcher builds `/private/tmp/labyrinth_codex/ux-18/baseline-slim` from the release commit. It archives `scripts/`, `scenes/`, `data/`, `assets/`, `fonts/`, `themes/`, `shaders/`, `addons/`, and `project.godot`. It supplies the capture script from the candidate and copies the approved `cel_look_variants/`, the 1,446 warmed import artifacts addressed by the retained release sidecars, and Godot's class, extension, and UID metadata.

The slim copy omits the rest of the release tree, including `spec/`, `tests/`, `experiments/`, `marketing/`, `playtest/`, `steam/`, the original `tools/` tree, and editor and suite caches. The original full baseline remains in place.

The launchers at `tools/ux18/native.sh` and `/private/tmp/labyrinth_codex/ux-18/native.sh` are byte-identical. The headless run verified the slim project. Windowed capture remains a design-owner run.

## Verification

| Check | Candidate result |
| --- | --- |
| `tests/main_menu_input_test.gd` | `TEST RESULT: PASS — main menu input and startup transitions` (0 failures) |
| `tests/chronicle_test.gd` | `CHRONICLE TEST RESULT: PASS` (0 failures) |
| UX18 headless probe from the slim baseline | `UX18 HEADLESS RESULT: PASS` for both projects and `UX18 RUN STATE COMPARISON: PASS (5 states)`. |
| Python default group | `Ran 192 tests in 40.271s`, `OK`. |

The logs are in `/private/tmp/labyrinth_codex/ux-18/` as `main-menu-round1.log`, `chronicle-round1.log`, `headless-round1.log`, and `python-round1.log`. The Python runner could not update its optional timing cache in the read-only Git directory.

The concurrent headless run flagged a fresh-profile timing sample of 21,526 µs from the title and 11,504 µs in-run. A serial rerun of the same probe passed and recorded 4,925 µs from the title versus 6,823 µs in-run for the fresh profile, and 12,150 µs versus 15,118 µs for the played profile. See `headless-round1-serial.log`.

There are no `TODO_DESIGN_*` placeholders. This round changes only the two test files, the capture launcher, and this report. Changes remain uncommitted.
