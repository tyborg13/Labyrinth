# gate-01: identity gate review sheets show the cel look

## Header
- **Why:** the owner approved an automatic cel filter as the shipped look on 2026-10-30, but `tools/art_identity_gate.py sheet` still shows unfiltered art. Board art gets approved looking different from how it plays: the filter already merged Tharokh's low-contrast head into one tone, and that was only caught in a playtest. Approval must see what ships.
- **Worktree:** `/Users/borgerding/workspace/Labyrinth.worktrees/gate-01`, branch `codex/gate-01`, base `codex/peer-benchmark`.
- **Owned:** `tools/art_identity_gate.py` (`make_sheet` and its CLI), `spec/visual_identity_gate.md` (one short paragraph), and small additions to `tools/cel_look.py` only if a public helper is needed. **No art, no cel tuning, no changes to `tools/cel_look.json`, no game code.**
- **Risk tier:** standard.

## Change (director decisions; exact)
1. **`sheet` adds one row: "as shipped".** Directly under the existing large native-size row (the row with hero, peers, candidate front, candidate rear, candidate mirrored), add a second row with the same slots at the same scale on the same backdrop, with every figure, candidate and canon peers alike, through the shipped filter. Use the real path `tools/cel_look.py` uses at build (its `fit` and `apply`), with the same settings as a production unit in that category. Canon peers use their own built cel output if one exists; otherwise filter them the same way. The label reads `as shipped`. Existing rows and their labels stay as they are.
2. **Candidate settings.** Use the default character look, merged with the entry for that unit in `tools/cel_look.json` if one exists (per-unit overrides and touch-ups included). Print one line under the sheet's metrics saying which look applied: `cel look: default` or `cel look: <unit id> override`.
3. **Metrics stay on the source painting.** All gate bands, PASS and FAIL values are unchanged. The new row is for the judge's eye only. No new pass/fail. The sheet's digest lines stay; add the cel settings digest as one more line.
4. **`--no-cel`** skips the row. The default is on. `make_canon_sheet` is unchanged.
5. **Docs:** in `spec/visual_identity_gate.md`, one short paragraph in the sheet section: judge both rows; the second is what the player sees; a form the filter merges or a colour it shifts is a reason to reject or to add a cel override, even if the source row looks fine.

## Proof
Regenerate a sheet into `/private/tmp/labyrinth_codex/gate-01/` for `burrow_grub` (`spec/art_identity/jobs/burrow_grub/mq27_front` and `mq27_rear`, `art_scale` 0.64) and `storm_cantor` (`spec/art_identity/jobs/storm_cantor/mq26_front` and `mq26_rear`, `art_scale` 1.0), with the same commands as those jobs' records. Report their paths. Run `python3 tests/test_art_identity_gate.py` and the Python default group (`tools/run_python_suite.py --shards 4`). **No full suites. No new permanent guards** beyond extending existing gate tests if one breaks. No windowed Godot; this is Python only.

## Out of scope
Rebuilding any cel output, re-judging existing art, the canon sheet, tuning.

## Working rules (director)
Leave every change **uncommitted**; the director commits. Don't push, don't touch other worktrees. Taste gaps get `TODO_DESIGN_<what>`. Report to `/private/tmp/labyrinth_codex/gate-01/result.md`, short.
