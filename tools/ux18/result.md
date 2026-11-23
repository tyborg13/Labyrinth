# ux-18 result

The title and RunScene share the Grimoire panel. The worktree is on `codex/ux-18`, based on release commit `f92582e85f72107cc80abf8c72e3bc4677a93dd9`. Changes are uncommitted.

## Files

- `scripts/grimoire_panel.gd` owns the scrim, construction, browsing, search, previews, and focus lifecycle.
- `scripts/run_scene.gd` passes live context to the panel and handles the run's discovery, persistence, modal bookkeeping, and audio. The diff removed 1,289 lines and added 84 in RunScene, a net reduction of 1,205 lines.
- `scripts/main_menu.gd` adds the title button, hosts the same panel, and contains input while it is open.
- `tools/ux18/` holds `proof.gd`, `compare.py`, `before.json`, `after.json`, `native.sh`, and this report. The launch script is also at `/private/tmp/labyrinth_codex/ux-18/native.sh`.

## Acceptance

1. The shared panel keeps the existing `GrimoireScrim` and child names. The release comparison matched the visible control state for all five cases, including focus and collision loop frame 12. Native RGBA comparison is pending.
2. The title uses the same button styling and row spacing as Chronicle. The checked order is Continue, New Game, Chronicle, Grimoire, Settings, Quit. The demo path passed.
3. New-run discovery from the same profile matched in order, with 63 entries and zero unread on the fresh fixture and 374 entries and one unread on the played fixture. An entry found only in the saved checkpoint stayed undiscovered at the title.
4. Both scripted title sessions preserved profile, settings, checkpoint, and backup bytes, including absence of temporary files.
5. Native GUI input in headless mode checked pointer open and scrim dismissal, Escape and controller B, focus return, D-pad order, search-to-entry focus, and a click over the Settings button while the book was open. Existing in-run search and focus probes cover the floating keyboard and HUD return behavior.
6. Both hosts use the same scrim and immediate reveal. The release Grimoire has no entry tween. The title session verified that its audio player kept playing the same stream. The title motes remain on their existing update path.
7. The first title frame does not build the panel. The title prepares a hidden instance and the current profile's discovery catalog after presenting its first frame. The opener rereads the profile and reuses the prepared catalog when the profile still matches. An open arriving before preparation constructs it on demand.

The synchronous opening handler includes the title's disk reread. Times are a matched headless sample on the same machine.

| Profile | Title | Extracted in-run | Release in-run |
| --- | ---: | ---: | ---: |
| Fresh | 3,103 µs | 6,158 µs | 7,502 µs |
| Played | 9,824 µs | 14,321 µs | 13,976 µs |

## Run-dependent presentation

| Surface or state | Title behavior |
| --- | --- |
| Discoveries from cards, equipment, room NPCs and merchants, rewards, combat, and the saved descent | Uses persisted profile discoveries plus the starting deck, equipment, and starting-room NPC through the existing discovery rule. Checkpoint-only discoveries are excluded. |
| Unread stars and first-unread selection | Uses the profile's unread list and retains it on disk. |
| HUD unread count, discovery notice, and close-time acknowledgement | These remain part of RunScene. The title has no badge or notice and performs no acknowledgement. |
| Card previews and equipment-granted card previews | Uses the profile's card definitions, including persistent upgrades and modifications. No live projection of combat statuses, next-attack modifiers, Empower or Follow-up, time surcharges, skill and relic combat effects, rites, transient equipment effects, or board state is applied. |
| Run modal audio, music context, log visibility, and controller endpoint recovery | RunScene still manages them. The title uses its existing music and restores focus to its Grimoire button. |

The existing Grimoire has no deck counters, current-fight highlighting, or “in your deck” marks.

## Checks run

| Check | Result line |
| --- | --- |
| UI identity lint | `Ran 25 tests in 8.455s`, `OK` |
| Rules-text lint | `PASS: Rules text lint (455 existing hits)`, `OK` |
| Python default group | `Ran 192 tests in 37.059s`, `OK` |
| Grimoire search and focus-return probes | Both printed `GRIMOIRE SEARCH PROBE RESULT: PASS`. The search probe also printed `GRIMOIRE STEAM KEYBOARD: PASS`. |
| Grimoire performance | `GRIMOIRE PERFORMANCE RESULT: PASS` |
| Combat HUD buttons | `COMBAT HUD BUTTONS TEST: PASS` |
| Settings modal | `TEST RESULT: PASS — Settings modal input` |
| Demo title | `UX18 DEMO RESULT: PASS` |
| Before and after probe | Both printed `UX18 HEADLESS RESULT: PASS`. The comparator printed `UX18 RUN STATE COMPARISON: PASS (5 states)`. |
| Main menu input | Release printed `TEST RESULT: PASS — main menu input and startup transitions`. Candidate printed `TEST RESULT: FAIL — 9 main menu first-click input failure(s)`. |
| Chronicle | Release printed `CHRONICLE TEST RESULT: PASS`. Candidate printed `CHRONICLE TEST RESULT: FAIL (3 failure(s))`. |

The legacy menu and Chronicle failures follow from assertions that move directly from Chronicle to Settings or measure their former adjacency. The new probe exercises both steps in the requested order. Existing test files are outside this unit's owned paths.

Both build snapshots reported the macOS certificate lookup and an exit-time retained-resource warning during the dry run. The Python runner finished successfully and could not update its optional timing cache under the read-only Git directory.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-18 && bash /private/tmp/labyrinth_codex/ux-18/native.sh --windowed
```

The script runs the exact release snapshot and the current worktree with the approved cel look. It captures 1920×1080 at 100% UI scale from an exact-size SubViewport, and also captures the title and open book at 1280×800 with Steam Deck glyphs. It reuses a single rendered run backdrop for the five exact comparisons, so the comparison is independent of ambient movement beneath the scrim. It validates PNG dimensions and luma variation and compares decoded RGBA bytes for all five in-run pairs.

- `/private/tmp/labyrinth_codex/ux-18/windowed/before/` and `/private/tmp/labyrinth_codex/ux-18/windowed/after/` will contain `run_sections.png`, `run_entry_loop.png`, `run_search_results.png`, `run_search_empty.png`, and `run_controller_entry.png`.
- The candidate directory will also contain `title_pointer.png`, `title_controller.png`, `title_sections.png`, `title_entry_loop.png`, `title_search_results.png`, `deck_title_controller.png`, and `deck_title_grimoire.png`.
- Headless control-state and timing receipts are in `/private/tmp/labyrinth_codex/ux-18/headless/{before,after}/measurements.json`. The headless dry run printed every intended PNG path in `/private/tmp/labyrinth_codex/ux-18/dry-run-final.log`.

## TODO_DESIGN placeholders

None.

## Chosen defaults

The proof uses seed 84217, a fresh profile and a run-42 profile with one unread article, Collision at frame 12 for the tooltip, and “reshuffle” and “zzqqxxzz” for search. The fixtures use reduced motion for stable captures and pause the tooltip loop explicitly. The proof waits four layout frames and up to 2.5 seconds for loop decoding. The native runner allows 25 seconds for startup and 120 seconds for the capture sequence. All are proof-only values.
