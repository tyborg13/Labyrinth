# deck-01 — round 3 (Codex peer review of 5b766ff7e: CHANGES REQUESTED)

Fix all four findings as the reviewer proposes (full review: /private/tmp/labyrinth_codex/review/deck-01-5b766ff7e.md). Director copy for #2: "Purchased magic goes straight into your deck." (list every other reserve/attune string you find, before → after, using the same wording style).

1. **Medium — Keyboard focus escapes Purge and activates underlying UI.** The list has no focus trap at [magic_purge_overlay.gd:50](/private/tmp/labyrinth_codex/review/deck-01-5b766ff7e/scripts/magic_purge_overlay.gd:50). Reproduction: open Scavenger Purge, press Tab four times, then Enter. Focus reaches `SectionMapButton` and opens the map behind Purge. Fix: contain Tab, Shift-Tab, and directional navigation within the list; block underlying toolbar actions while Purge is open. Add viewport-dispatched input coverage. [Reproduction script](/tmp/deck01-review-input.gd).

2. **Medium — Live Grimoire copy still teaches reserve ownership.** [grimoire_library.gd:38](/private/tmp/labyrinth_codex/review/deck-01-5b766ff7e/scripts/grimoire_library.gd:38) says “Purchased magic enters reserve.” This is returned by the generated Scavenger character entry. Replace it with deck wording and extend the obsolete-copy test beyond the two JSON files to generated entries.

3. **Low — The ownership guard lacks regression coverage.** Deleting the check at [run_engine.gd:1502](/private/tmp/labyrinth_codex/review/deck-01-5b766ff7e/scripts/run_engine.gd:1502) survives `magic_deck_test.gd`. An unowned valid spell can then charge Embers and advance purge counters. Add a test purging `frostbolt` from an untouched shop fixture and asserting unchanged ownership, wallet, and counters.

4. **Low — Retired implementation remains.** The reserve-sale branch at [run_engine.gd:1811](/private/tmp/labyrinth_codex/review/deck-01-5b766ff7e/scripts/run_engine.gd:1811) is unreachable after repair drains the reserve. [run_scene.gd:30983](/private/tmp/labyrinth_codex/review/deck-01-5b766ff7e/scripts/run_scene.gd:30983) also retains a magic proxy builder without callers. Remove these dead paths, preserving needed compatibility fields and the shared item animation helper.

Each fix needs a regression that fails before. Focused tests + full suite once + re-run the UI probe command. Do not commit.
