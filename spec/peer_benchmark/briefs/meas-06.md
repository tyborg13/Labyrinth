# meas-06: the difficulty curve when the deck grows (measurement only)

## Header
- **Open question (`spec/peer_benchmark/decisions.md`, 2026-11-01):** with a fixed bot deck, win rate falls steeply by section. At tier 2 the sections read 94, 77, 38, 9, 8, 0%. A fixed starter-tier deck against final-section enemies says little about a player with five sections of rewards. Does the drop survive when the bot plays whole runs and its deck grows, with Health carrying between rooms?
- **What exists:** `tools/encounter_bot.gd` (policy v2, the combat player), `tools/encounter_sweep.gd`, `tools/encounter_measurement_engine.gd`. `tools/headless_playtest.gd` is a manual REPL, and it is the reference for every RunEngine transition a whole run uses: map moves, pre-battle, combat, rewards, Hearth, merchant, relics, events, section change.
- **Worktree:** `/Users/borgerding/workspace/Labyrinth.worktrees/meas-06`, branch `codex/meas-06`, base `codex/peer-benchmark`.
- **Owned:** new `tools/run_curve*.gd` and `tools/run_curve*.py`, and new `spec/peer_benchmark/encounter_redesign/measurements/run_curve_2026-11/`. **No gameplay, data or balance change.** Combat policy v2 stays as it is: the default `policy_sha256` must not change.
- **Risk tier:** standard. A fresh worktree needs a cold import first: `python3 tools/godot_task_runner.py --task-id <id> --timeout 500 --stream -- godot --headless --path . --import`. Run with source art (`LABYRINTH_CEL_LOOK=off`).

## Change (director decisions; exact)
1. **A whole-run player.** Start with `create_new_run(seed, default progression)`, with section maps on and 24 Health as a new player has. Use only production RunEngine, CombatEngine and event-rules transitions, in the order the REPL uses them. Health, deck, equipment, relics and embers carry over. A run ends at death, or at the end of the final section (count that as an escape). Fights use policy v2. A fight that reaches its 30-turn cap counts as a death, and is counted separately in the report.
2. **Route, at each map choice:** a table of room kinds, best first. Ties go to engine order.
   - Health at or under 50% of max: Hearth, merchant (only with 60 or more embers), event, treasure, standard fight, special, Guardian.
   - Otherwise: standard fight, event, treasure, merchant, Hearth, special (Warband, Snare, Hoarder, Last Light), Guardian.
   - Mandatory rooms are simply entered. Unknown rooms rank as events.
3. **Everything outside fights:**
   - **Hearth:** rest if Health is below 70% of max. Otherwise take its upgrade or purge option if a production transition offers one (the highest-scored card to upgrade; a starter Strike-tier card to purge). Otherwise leave.
   - **Merchant:** buy the best affordable card by the draft policy below, at most one per visit. Then one equipment item if a slot is empty and it is affordable. Then leave.
   - **Equipment drops:** equip if the slot is empty or the rarity is higher.
   - **Relics:** the first offered.
   - **Events:** the first choice that costs less than 25% of current Health and leaves the deck no smaller. If none qualifies, the leave choice or the last choice.
   - **Anything not covered:** leave without using it, and count it per room kind in the report.
4. **Three draft policies, same seeds:**
   - `best`: take the offered card with the highest score from the card balance heuristic's scorer (`spec/card_balance_heuristic.md`). Never skip.
   - `random`: a seeded random offered card. Never skip.
   - `none`: always skip card rewards (the control). Everything else stays the same.
5. **Sample:** first seed 1, at most 3 workers, 100 runs per policy. Write results as each run finishes. **Stop launching new runs at 60 minutes of wall clock** and report the N you reached per policy, keeping N equal across policies by truncating to the common seed prefix.
6. **Report `run_curve_2026-11/report.md`:**
   - **Reach table:** for each policy and section (0-5), runs entering, died there, escaped.
   - **Entry table:** per policy and section, median Health and max Health on entry, median deck size, median relics and equipment count.
   - **Fight table:** per policy and section, fights fought, win rate by fight kind (standard, Guardian, dragon, each special), median Health lost per fight.
   - **Fixed-deck reference:** copy the fixed-deck table from `decisions.md` under it, labelled as such.
   - **One short paragraph that only states the comparisons:** where each policy's reach falls fastest, and whether the section 2 to 3 drop is present. **No tuning recommendations.**
   - **Also:** deck ids at death for the first 10 `best` runs, and raw per-run records as `.jsonl.gz` (under 5 MB).

## Proof
A focused test that one seeded run is deterministic twice over, plus the unchanged policy hash. **No full suites. No new permanent guards** beyond that focused test, which stays out of the default group. No windowed Godot.

## Out of scope
Changing the combat bot, tuning anything, UI, analytics events.

## Working rules (director)
Leave every change **uncommitted**; the director commits. Don't push, don't touch other worktrees. Headless only, at most 3 workers: the owner plays on this machine. Taste gaps get `TODO_DESIGN_<what>`; measurement-only defaults go under "Chosen defaults". If a production transition can't be reached without the scene, say which and use the closest engine call, and name it in the report. Report to `/private/tmp/labyrinth_codex/meas-06/result.md`, short, with the reach table inline.
