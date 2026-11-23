# pol-75 · Candidate 5 polish repros

Candidate `codex/mrg-16` at `86d9f6ad1411e99c1336c78b8f585b018c7d70fc`. The probe loads real RunScene fixtures into a 1920×1080 SubViewport at 100% UI scale with `LABYRINTH_CEL_LOOK=all`. The sandbox has no macOS window server. Headless receipts measure controls, resolved state and sound-bank events. The physical pointer and fresh PNGs require the director's native run.

## 1. Pass forecast during the enemy turn · Fixed

- Resume Shuttered Hall, hover Pass, leave the pointer on the button, and end the turn with a click. Repeat with P. The headless cases deliver mouse and key events through the window's GUI input path. The native cases wait for the operator's physical pointer and check the click or P event.
- Candidate 5 left the in-scene forecast fading after disable. The probe sampled opacity 0.05549 for click and 0.06319 for P at the lock. The ordinary inactive transition calls the timed fade. The older “Ending now leaves …” string is still available to semantic consumers, and the Pass button suppresses the engine's separate native tooltip. [Forecast transition](../../scripts/pass_forecast_presentation.gd#L123), [fade](../../scripts/pass_forecast_focus_tooltip.gd#L23), [tooltip override](../../scripts/pass_forecast_tooltip_button.gd#L36).
- The enemy-turn lock now conceals the retained forecast immediately. The forecast accepts pointer hover again after real motion leaves and re-enters the painted hit area while the button is live. Explicit keyboard and controller focus still use the existing focus path. Card and movement preview fades use the existing forecast lifecycle. [run_scene.gd:9974](../../scripts/run_scene.gd#L9974).
- Both updated paths had 0 opacity at the lock and 0 after unlock with the pointer still resting. Both reopened after pointer re-entry. Native before and after · `01_pass_click.png`, `01_pass_key.png`. The observation file records the local pointer position and opacity at the lock and after input unlock.

## 2. Event Health number sizes · STALE

- Resolve Pray beneath her at The Weeping Statue with 1 or 12 Health missing. Resolve Bleed into the basin at The Bloodletter's Basin with the process-local fixture loss set to 1 or 12. Each case goes through the event choice resolver and live result beat. The protected event file stays as authored.
- Both signs used 60 px for an absolute change of 1 and 113 px for 12. The existing event scale was 0.8 in each case. The strip already calls the combat damage entry, which uses the shared magnitude steps. [event_health_strip.gd:135](../../scripts/event_health_strip.gd#L135), [floating_combat_text.gd:126](../../scripts/floating_combat_text.gd#L126).
- Native before and after · `02_health_gain_1.png`, `02_health_gain_12.png`, `02_health_loss_1.png`, `02_health_loss_12.png`.

## 3. Unclaimed gear notice · STALE

- Win Shuttered Hall with Quick Stab in three floor-loot states. Leave a Ward-Kite on the floor, fight with an empty floor-loot list, or walk onto the Ward-Kite and back to the finisher tile before winning.
- The visible reward notices were “Unclaimed gear crumbles into dust.” plus the Grimoire message in (a), only the Grimoire message in (b), and “Found Ward-Kite.” plus the Grimoire message in (c). Only (a) recorded `ward_kite` in `missed_equipment`. The combat engine skips claimed loot. Both the transient and reward notices require a nonempty missed-equipment list. [combat_engine.gd:3854](../../scripts/combat_engine.gd#L3854), [run_scene.gd:23205](../../scripts/run_scene.gd#L23205), [run_engine.gd:1459](../../scripts/run_engine.gd#L1459).
- Native before and after · `03_gear_left.png`, `03_gear_none.png`, `03_gear_picked_up.png`.

## 4. Faint Victory beside ESCAPED · STALE in sampled trials

- Resume three distinct final Noctyrax fights at depth 24 with a lethal Quick Stab available. Win, press Continue on the milestone reward and choose Leave nothing at the heirloom prompt. Inspect the first recap sample and the settled recap.
- The candidate showed the fight banner in 0 of 3 trials at both observations. The settled board status was empty and the recap title was ESCAPED. RunScene waits for the presentation before committing the reward display. The fight sequence awaits the fade and hides its overlay. RunScene already suppresses the board placard on victory. [Reward boundary](../../scripts/run_scene.gd#L21924), [fight fade](../../scripts/post_combat_reward_sequence.gd#L163), [board placard](../../scripts/run_scene.gd#L27106).
- Native before and after · `04_escape_0.png`, `04_escape_1.png`, `04_escape_2.png`.

## 5. Silent mid-fight arrivals · STALE for tested arrivals

- Start an ordinary fight through the pre-battle Start control and separately start Noctyrax. In live enemy turns, pass into Storm Cantor's Call the Spark and a Survive wave. The probe records the game's `SfxBank.cue_requested` result and clock at each cue, alongside the first sampled board frame showing the arrival.
- The ordinary opening had card-deal sounds and no generic enemy arrival cue. Dragon openings have `dragon.roar`. Guardian challenges have a dedicated `step.enemy.heavy` route. Both tested mid-fight arrivals played `summon.arrive`. The arrival tracker registers resolved summons and reinforcement steps, and the router submits the shared cue. [Guardian cue](../../scripts/dragon_arrival.gd#L135), [arrival registration](../../scripts/enemy_arrival_sfx.gd#L16), [cue routing](../../scripts/sfx_cue_router.gd#L358).
- Candidate cue timestamps in the sound bank's run-local clock were `dragon.roar` at 50,080 ms, `summon.arrive` at 55,685 ms for Call the Spark, and `summon.arrive` at 58,702 ms for the Survive wave. The summon played on its first sampled visible frame. The wave cue led its first sampled visible frame by 115 ms. The router sees the reverse-dissolve body before the reveal filter runs. Native timing is pending. [run_scene.gd:26157](../../scripts/run_scene.gd#L26157).
- `TODO_DESIGN_arrival_cue` records the missing generic opening cue. Candidate 5's existing mid-fight cue is owner-authored in [sfx_cues.json:99](../../data/sfx_cues.json#L99).
- Native before and after · `05_opening.png`, `05_dragon_opening.png`, `05_summon.png`, `05_reinforcement.png`, and the cue timestamps under `sound_*` in each `observations.json`.

## 6. Reward screen sits high · STALE

- Inspected both census frames. The painted banner starts at y=274 and the Skip outline ends at y=878 inclusive in both. The block has 274 px above and 201 px below. The bottom-right inspection notice occupies y=953–1055. Both supplied frames carry that notice.
- A fresh ordinary win showed “Added 9 entries to the Grimoire.” in a panel at y=952–1058, below Skip. The control rectangles were banner y=260.76–390.24, including texture padding, and Skip y=833.24–879.24. The hand is hidden. RunScene centres the group between the top bar and the existing screen margin. [Reward layout](../../scripts/run_scene.gd#L5845), [notice position](../../scripts/run_scene.gd#L27364).
- Before census frames · [12_reward.png](/private/tmp/labyrinth_codex/pol-67/20261123T131016691207Z/1920x1080/12_reward.png), [47_combat_reward_three_cards.png](/private/tmp/labyrinth_codex/pol-67/20261123T131016691207Z/1920x1080/47_combat_reward_three_cards.png).
- Native before and after · `06_reward.png`.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-75 && /private/tmp/labyrinth_codex/pol-75/native.sh
```

Follow the window title during each version's first two cases. Hover Pass until its forecast opens, click Pass at the first prompt, and press P at the second. Hold the pointer on Pass across the hand-off. When the window title asks, move off Pass and hover it again. The wrapper stages the exact candidate locally and uses `tools/visual_probe_runner.py` for both versions. Each phase validates 17 PNGs and prints each absolute PNG path on its own line. Each phase also writes `observations.json` and a renderer manifest in its output folder.

## Chosen defaults

- Fixture seed 919042, with successive seeds for three Noctyrax trials. Quick Stab finishes the fixture fights. The boss starts at 1 Health and 0 Block, with the hero adjacent. Ward-Kite is placed at (5, 4) for the two gear-floor cases.
- Event fixture cap 48 lets the authored 25% heal give 12 or cap at 1. The game process's test-local loss amounts are −1 and −12. The reinforcement fixture schedules one wave at clock 1 and spaces later waves beyond the observation.
- Headless GUI dispatch uses the button's local (135, 33) and (32, 110) away from Pass. The rest sample waits 0.18 s. Wait limits are 20 s for scene state, 5 s for headless input and 45 s for the native pointer steps. The visual runner allows 300 s for the operator and all 17 captures.
- The viewing window fits the display with a 64×96 px margin. The proof SubViewport stays 1920×1080. The proof uses production camera and motion settings.

## Focused checks

- `POL-75 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/pol-75/headless.rz4t8i`
  [Before observations](/private/tmp/labyrinth_codex/pol-75/headless.rz4t8i/before/observations.json) and [after observations](/private/tmp/labyrinth_codex/pol-75/headless.rz4t8i/after/observations.json).
- `PTF08 FOCUSED RESULT: PASS (761 assertions, 0 failures)`
- `ATK02 CHECKS RESULT: PASS (83 assertions, 0 failures)`
- UI identity lint · `Ran 25 tests in 5.024s` · `OK`
- Rules text lint · `Ran 3 tests in 0.064s` · `OK` · `PASS: Rules text lint (16 existing hits)`

## Open issues

Native pointer and renderer confirmation are pending. The unexplained intermittent escape report did not recur in the three candidate trials. The generic arrival cue remains `TODO_DESIGN_arrival_cue`. The Survive cue timing awaits native confirmation.
