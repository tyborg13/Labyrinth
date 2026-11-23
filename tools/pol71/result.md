# pol-71 playback proof

Baseline `codex/mrg-15` at `76aac505bcc3f1f915344a5e7b14e8e20e1e1fae`. Updated project `codex/pol-71` with local edits. Both ran the same real card input, resolver, board and SFX code through the task runner. The headless probe samples the HUD's forecast-decorated draw inputs and cue-bank requests. Pixel captures require the native run.

## Round 1 commit-time validation

`CombatHudForecast.begin()` transfers the board's disclosed forecast into playback. Immediately after `CommittedBattlefieldRules.player_card()`, the restored `confirm()` checks held values, keyword badges, status previews and damage previews against the committed snapshot. A contradiction triggers a stage refresh with the pre-card state. A matching forecast is carried through to its delivery beat, where the matching pill is acknowledged without another pop.

The divergent fixture submits Expose 3 to the board during hover. The real Crosswind still applies Expose 2 at Ice contact. At the card-play audio request, the probe samples the board and counts stage refreshes beyond the ordinary animation-lock refresh. It also logs the displayed Expose value on every frame from the submitted hover to delivery.

| Divergent Expose | Candidate 4 | Round 1 |
| --- | --- | --- |
| Hover frames −8 through −1 | Forecast Expose 3 | Forecast Expose 3 |
| Commit through frame 41 | Pre-card Expose 0, no pill | Pre-card Expose 0, no pill |
| Delivery frame 42 | Expose 2 | Expose 2 |
| Extra commit refreshes | 0 | 1 |

All seven matching scenarios recorded zero extra commit refreshes and zero second status pops. Block 8 remained visible across confirmation. Both projects sampled the Expose strip at frames 0, 4, 8, 12, 16, 20, 24, 28, 32, 36 and 40, plus a separate delivery sample at frame 42.

### Round 1 verification

- `POL71 gameplay proof: 0 failures` on each project.
- `PREVIEW HANDOFF: PASS (contradicted Expose pruned at commit, matching previews held without a second pop or extra refresh)`
- `RULE VALUE GUARD: PASS (8 scenarios, Health, Block, statuses and surface events identical)`
- `RECT COMPARISON: PASS (443 matched paths, maximum edge delta 0.0000 px)`
- `CARD BUFF PLAYBACK TEST RESULT: PASS (525 checks, 0 failures)`
- `BOSS HEALTH PREVIEW TEST: PASS (0 failures)`
- `SURFACE FEEDBACK UI TEST RESULT: PASS`
- `TEST RESULT: PASS board surface presentation`

All four focused programs exited 0. The Surface Feedback UI test reported two resources still in use at shutdown. The native round 1 PNGs are pending.

[Per-frame trace and refresh counts](/private/tmp/labyrinth_codex/pol-71/round1-dry-run.log) · [Headless receipts](/private/tmp/labyrinth_codex/pol-71/headless-y3e3jt71) · [Focused test logs](/private/tmp/labyrinth_codex/pol-71/round1-tests)

## Round 0 observations

1. **Buff labels — STALE.** Candidate 4 already showed Whetstone `+4` with `next_attack`, Hourglass Sand `+4` with `quicken`, and Undertaker Stand `+5` with `retaliate`. The existing floating-text suite verifies the Block placement and motion defaults. Card buff playback was left alone.
2. **Push onto Fire — reproduced and fixed.** Crosswind showed `−5` on the base and played `push.slide` and `spell.air`. The update shows `−3` at frame 42 and Fire `−2` at frame 52. The cue bank played `surface.fire` at frame 52. With a wall collision, `−7` became `−5` at frame 40 and Fire `−2` at frame 49, with `push.collision` and the Fire cue at those respective frames. Bottled Gale across two Fire tiles shows one Fire `−4` and plays one Fire cue. The original physical impact still uses the combined Health loss.
3. **Preview handoff — partly reproduced.** Matching Block 8, Retaliate 5, and enemy Expose 2 stayed visible on candidate 4. Retaliate and Expose both popped again at delivery. Round 0 removed the second pop and introduced the divergence regression corrected in round 1.
4. **Warden adjacency — STALE.** The fixture put Warden one tile north, east, south and west with hero Retaliate 3 and Quicken 2. The production bar and intent-chip rectangles intersected neither status chip in any direction. Each cell below is Health overlap / intent overlap, measured as a percentage of the hero chip's rectangle.

| Warden tile | Retaliate 3 | Quicken 2 |
| --- | ---: | ---: |
| North | 0.00% / 0.00% | 0.00% / 0.00% |
| East | 0.00% / 0.00% | 0.00% / 0.00% |
| South | 0.00% / 0.00% | 0.00% / 0.00% |
| West | 0.00% / 0.00% | 0.00% / 0.00% |

### Ground contact inventory

Fire is the only persistent ground that deals Health damage in `CombatEngine._surface_contact`. Ice applies Expose. Electrified ground conducts damage through the separate electrical resolver. Rubble and ordinary floor have no entry damage. Armed traps are separate board objects with their own eruption, cue and wake. The arrival resolver triggers them before checking persistent ground, and the Fire split uses only actual Health lost from Fire's entry receipts.

The owner accepted the Fire split and cue, the matching-pill handoff and the two stale decisions from the round 0 native proof. [Native captures](/private/tmp/labyrinth_codex/pol-71/native-zu_eilp7) · [Confirm strip](/private/tmp/labyrinth_codex/pol-71/confirm_strip.png)

## Round 0 verification

- `POL71 gameplay proof: 0 failures` on each project.
- `RULE VALUE GUARD: PASS (8 scenarios, Health, Block, statuses and surface events identical)`
- `BUFF LABELS: STALE (3 existing icon-plus-number labels on candidate 4)`
- `push_fire: −5 → −3 then Fire −2, surface.fire played once`
- `push_fire_collision: −7 → −5 then Fire −2, surface.fire played once`
- `area_push_fire: Fire −4 across two tiles, one number and one cue`
- `PREVIEW HANDOFF: PASS (matching previews held without a second pop, divergent Expose held until delivery)`
- `RECT COMPARISON: PASS (443 matched paths, maximum edge delta 0.0001 px)`. The comparison includes drawn Health, intent and status rectangles as well as control edges, with pol-69's 0.001 px camera tolerance.
- `CARD BUFF PLAYBACK TEST RESULT: PASS (525 checks, 0 failures)`
- `TEST RESULT: PASS board surface presentation`
- `SURFACE FEEDBACK UI TEST RESULT: PASS`
- `BOSS HEALTH PREVIEW TEST: PASS (0 failures)`
- `python3 tests/test_ui_identity_lint.py` reported `Ran 25 tests` and `OK`.
- `python3 tests/test_rules_text_lint.py` reported `PASS: Rules text lint (16 existing hits)`.
- `POL71 SIDECARS: PASS`

The Godot invocations emitted the host certificate warning `Condition "ret != noErr" is true. Returning: ""` on both projects. The worktree was also missing several ignored imported textures. Copies from the matching candidate's existing import cache cleared those resource errors for the final checks.

[Headless receipts and logs](/private/tmp/labyrinth_codex/pol-71/headless-yfispf0a) · [Launcher summary](/private/tmp/labyrinth_codex/pol-71/dry-run.log)

## Proof for the design owner

Run from a logged-in macOS desktop. The launcher uses the visual probe and Godot task runners, sets `LABYRINTH_CEL_LOOK=all`, and prints the fresh output folder. Each project gets `before/` or `after/` receipts, the visual runner manifest and validated PNGs. The probe prints each absolute PNG path as a standalone line.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-71 && /private/tmp/labyrinth_codex/pol-71/native.sh
```

The round 1 launcher captures two strips for each project. `block_confirm_00.png` through `block_confirm_48.png` sample every second frame. `expose_divergent_00.png` onward sample every fourth frame from release, with `expose_divergent_delivery.png` marking the first displayed real value. Each full frame has a `_2x.png` crop. The launcher has been dry-run headlessly. The round 1 PNGs require a macOS window session.

## Chosen defaults

- Probe seed 9811, with the next seed for the intentionally divergent receipt. The proof room is 9×9, the hero starts at tile (3, 4) with Health 30, and the fixtures supply enough plays to avoid automatic Pass.
- Divergent Expose receipt increment of 1. At-rest Warden fixtures use Retaliate 3 and Quicken 2.
- 60 FPS proof target, eight settle frames and a 20-second per-card playback deadline. The native runner allows 180 seconds for the full set of PNG writes.
- 320×192 source crops enlarged 2× with nearest filtering, centred on the actor HUD for each strip.

`TODO_DESIGN` placeholders: none.
