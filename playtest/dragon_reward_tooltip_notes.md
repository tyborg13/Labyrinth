# Board tooltip cleanup at dragon victory

Follow-up to native Tharokh attempt 01 (2026-09-27): the Wooden Crate 3/3 HP
hover popup survived over the Worldheart milestone for roughly 30 seconds until
Continue was clicked. Root supplied this native observation; the focused probe is
separate staged renderer evidence, not another played encounter.

## Scope and acceptance

Use the existing shared isolated task and its original worker-owned pre-edit Git
preflight. A repeat preflight on this continuation rejected the dirty shared
checkout before Git writes; do not adopt, reset, stage, or discard the other
workers' changes. Root explicitly authorized this continuation under the existing
preflight. Risk for this change: standard UI state transition, within the task's
existing high-risk contract. Publication and branch-wide peer review remain root
owned.

At the combat-to-victory boundary, a stationary pointer must not leave a board
inspection popup above the victory beat or milestone. During reward selection,
board hover must not reopen it. Reward tooltips, focus, Continue, camera behavior,
and the subsequent room/combat inspection remain available.

Design statement: the victory and reward surfaces now answer what the player
won and offer Continue; stale terrain information has no role in that decision.
Suspend only the board's transient tooltip source, dismiss its owned popup
synchronously, and restore it outside reward mode. Use the existing reward and
UiTooltipPanel styling. Pointer and keyboard behavior remain the same; the fix
must also work with reduced motion. No copy, icon identity, payout, persistence,
reward timing, or relic-acquisition changes are intended.

## Diagnosis and planned proof

CombatBoard is retained behind reward selection. Its dynamic tooltip sentinel
stays active, and Godot's tooltip is a separate TooltipPanel Window parented to
the owner. The choice overlay/backdrop ignores pointer input, so simply drawing
it does not cancel a board popup or prevent another board hover.

`tests/dragon_reward_tooltip_probe.gd` uses the real 1920x1080 renderer at UI scale
1.0. It opens a production crate tooltip via actual pointer routing, starts the
live victory beat with a stationary pointer, renders the finished production
reward, waits beyond the tooltip delay, revisits the background hover, checks
Continue's keyboard focus and own tooltip, then restores combat inspection.
Normal and reduced motion are paired. Before/fix results and screenshot review
are recorded below when the exclusive Godot lease is available.

## Implemented and verified pair

Production changes are limited to `CombatBoard.set_tooltips_enabled()` and two
RunScene calls: disable before the victory beat, then keep disabled in reward
mode and restore outside reward mode. Disabling clears the tooltip sentinel,
guards dynamic lookup, and synchronously hides/queues deletion of board-owned
TooltipPanel windows. It does not hide the board or change camera/input routing.

- First setup run exposed a desktop-resolution probe issue and is not accepted
  visual proof (`/private/tmp/dragon-tooltip-before.json`).
- Corrected baseline `/private/tmp/dragon-tooltip-before2.json` rendered at exact
  1920x1080 and failed only the six intended lifecycle assertions: popup remained
  at victory entry, over reward, and after a stationary 1.5-second wait, in both
  motion settings. Its crate hover, reward-button tooltip/focus, and restoration
  checks passed. Inspected the obstructed Worldheart screenshot.
- Fixed run `/private/tmp/dragon-tooltip-after.json` exited 0, all assertions
  passed, and all ten exact-resolution PNGs were inspected. Victory and milestone
  screenshots have no crate popup; Continue's own tooltip remains visible when
  requested; the board crate tooltip returns after leaving reward mode.
- Reviewer `/root/boss_fun_review` read the patch separately and found no blocking
  lifecycle issue: live callers adopt reward state before the next choice refresh,
  loaded rewards start in reward mode, and filtering only direct board-owned
  TooltipPanel windows preserves reward tooltip ownership. This is a narrow
  cross-check, not the task's eventual committed-HEAD peer signoff.

The screenshot inspection exposed a probe-only snapshot alias: staging the kill
mutated the original fixture, so before/restored combat displayed a 0-HP boss.
This does not affect the reproduced tooltip lifecycle (the 3/3 crate and combat
mode were live), but the probe now duplicates the battle before that kill,
asserts the before boss is alive, and checks the disabled dynamic source directly.
The corrected fixture passed on the next root-approved Godot slot; see the final
receipt below. No further production change was made after the passing pair.

Affected rubric rows: state/consequence, visual hierarchy, interaction
completeness, accessibility, layout and visual proof pass for this narrow change.
Branch-wide committed-HEAD signoff/publication remain root owned.

The presentation reviewer also inspected both full-resolution stationary-pointer
milestone images independently. The baseline visibly obscures Worldheart's rules
with the 3/3 crate popup; the fixed image preserves the title, art, complete
three-line rules, payout and Continue with no clipping or new visual regression.


## Final corrected fixture

`/private/tmp/dragon-tooltip-after-corrected.json` is the final successful native
Metal receipt: exit 0, all assertions pass, ten 1920x1080 screenshots validated
and individually inspected. Before/restored combat now visibly retains the living
70/70 Tharokh; the live 3/3 crate tooltip appears normally, disappears at victory
entry, stays absent throughout reward, and returns after combat is loaded again.
The dynamic tooltip source is explicitly empty during reward. Reward-button hover
and keyboard focus remain intact. One generic ObjectDB-instance warning appears
at process exit; there are no script errors or failed assertions. This is a
focused staged UI probe, not proof of a complete played killing action.

The native Tharokh attempt02 journal separately confirms the stale tooltip was
absent at the actual T8 win and Continue delivered the relic and section map.

Final images live under:
`/private/tmp/labyrinth-godot-home/dragon-boss-encounters-milestone-rew-1790529562206300000-25250-dragon_reward_tooltip_pr-1/Library/Application Support/Escape the Umbra Visual Probe dragon-boss-encounters-milestone-rew-1790529562206300000-25250-dragon_reward_tooltip_pr-1/probes/dragon_reward_tooltip_v1/`.
No remaining tooltip implementation or proof work is required. No files were
staged/committed by this worker. The exclusive Godot lease was returned to root
for Iskaldra native play immediately after the successful process exit.
