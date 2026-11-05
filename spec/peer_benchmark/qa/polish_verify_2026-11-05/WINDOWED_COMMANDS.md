# Proof for the design owner — windowed commands (not run)

Run from this exact worktree/HEAD. All captures request 1920×1080 and 100% UI scale. `observe.gd` saves fixed-state captures; `manual_capture.gd` resumes through production Continue, enables real input for 60 s, logs frame state and saves 5 s checkpoints. Press **F9** for an immediate checkpoint. Where `QA52_BURST=1`, mouse releases and hand-hover ownership changes trigger 30 rendered checkpoint frames, covering brief hover/take beats. Native file writes may affect frame pacing; use these for visible states rather than strict performance claims. Audio commands use CoreAudio; other commands use Dummy.

Commands have a 180 s process budget and 75 s startup budget because the production Continue observer allows 60 s plus a 60 s interactive observation. They run once, with no backend retry specified. Each result manifest is fresh-only; preserve or rename a prior manifest before deliberately repeating a command. Dragon and guardian commands use their checked-in pre_battle fixture cases and require a real Start press, so their opening is observed. Other resumed-combat fixtures are not opening proof.

The brief's `/private/tmp/labyrinth_codex/qa-52/tools/` and historical `output/polish/pol-NN/clip_tool/` were absent. These report-owned observers are supplied instead of claiming those tools were reused. No `inspection_fixture.py` handoff is required for a verify-only report; manual_capture uses the same checked-in fixture builder in an isolated runner namespace and boots its save through the real menu transition. For fresh-profile proof, `QA52_FRESH=1` chooses the actual New Run menu path and leaves the menu interactive while waiting for it.

Run a single case with `python3 spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/run_native.py --case reward`, or all cases sequentially with `--case all`, after changing into this worktree. The wrapper prints each recipe and invokes its exact visual-runner command; each manual case still needs your real input. `--dry-run` prints without opening a window.

## treasure

Close room dialogue and wait for the actual treasure reveal; inspect the concurrent Relic Cache, Relic and CLAIM YOUR TREASURE labels.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/treasure python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_treasure.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario treasure --seed 83
```

Output: `native/treasure/*.png`, `native/treasure/state.jsonl`, `native/manifest_treasure.json`.

## meteorfall

Play Meteorfall and advance to its impact. Inspect staggered meteor arrivals and comet shape against the historical comparison only if the director still wants that comparison; no old branch is applied.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/meteorfall QA52_BURST=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_meteorfall.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --enemy-types ashen_reaver --hand meteorfall,quick_stab
```

Output: `native/meteorfall/*.png`, `native/meteorfall/state.jsonl`, `native/manifest_meteorfall.json`.

## combat

Inspect the ordinary HUD/action captions; use F9 for a checkpoint.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/combat python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_combat.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --hand quick_stab,volt_surge,whetstone,tempest_form,updraft
```

Output: `native/combat/*.png`, `native/combat/state.jsonl`, `native/manifest_combat.json`.

## hover

Park the real pointer, select/deselect, Pass into a redeal, play a card under the resting pointer, sweep at 3–5 rendered frames/card, then inspect Tempest Form. Burst capture is enabled.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/hover QA52_BURST=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_hover.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --hand quick_stab,volt_surge,molten_reach,thunderline,tempest_form,updraft
```

Output: `native/hover/*.png`, `native/hover/state.jsonl`, `native/manifest_hover.json`.

## adjacent

Apply Barbed Mail, move the hero/foes into adjacent screen rows, inspect hero status row and overlapping bars/numbers. Check multiple adjoining positions; a single still does not cover the family.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/adjacent python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_adjacent.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --enemy-types harrier,warden --player-position 3:4 --enemy-positions 4:4,5:4 --hand barbed_mail,quick_stab,brace
```

Output: `native/adjacent/*.png`, `native/adjacent/state.jsonl`, `native/manifest_adjacent.json`.

## character

Close dialogue/map, open Character. Inspect both gear/item Pack rows with controller focus, then Gear/Magic full Deck lists.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/character python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_character.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario character --seed 83 --equipment-inventory iron_cleaver,duelist_rapier --item-inventory crimson_draught,mossglass_elixir --attuned-magic updraft,crosswind,eye_of_the_storm,cinder_fusillade
```

Output: `native/character/*.png`, `native/character/state.jsonl`, `native/manifest_character.json`.

## boon

Existing force_boon(elemental_gift) fixture, seed 2; capture its current spell strips. This is a static debug offer, not a new content design.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=boon QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/boon python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/proof_boon.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_boon.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Output: `native/boon/*.png`, `native/boon/state.jsonl`, `native/manifest_boon.json`.

## scavenger

Inspect portrait sampling, Purge service and price placement.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/scavenger python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_scavenger.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario scavenger --seed 83 --held-embers 1000
```

Output: `native/scavenger/*.png`, `native/scavenger/state.jsonl`, `native/manifest_scavenger.json`.

## continue

Production Continue with a 60 s phase/performance deadline. Reproduce competing-load conditions separately; one pass cannot exclude an intermittent stall.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=continue QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/continue python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/proof_continue.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_continue.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Output: `native/continue/*.png`, `native/continue/state.jsonl`, `native/manifest_continue.json`.

## defeat

Settled zero-score recap after the existing heirloom decision; compare Chronicle outcome wording using the recorded run identity. The title observer lists seeded mismatches.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=defeat QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/defeat python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/proof_defeat.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_defeat.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Output: `native/defeat/*.png`, `native/defeat/state.jsonl`, `native/manifest_defeat.json`.

## victory

Settled all-six victory recap; compare button treatment with defeat. This fixture does not prove the real escape transition.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=victory QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/victory python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/proof_victory.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_victory.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Output: `native/victory/*.png`, `native/victory/state.jsonl`, `native/manifest_victory.json`.

## chronicle

Empty profile on main menu. Inspect ESCAPE/profile text around the Chronicle frame.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=chronicle QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/chronicle python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/proof_chronicle.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_chronicle.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Output: `native/chronicle/*.png`, `native/chronicle/state.jsonl`, `native/manifest_chronicle.json`.

## settings

Main-menu Settings, Restore confirmation, and real routed outside click on Chronicle; both static captures and the input result are emitted.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=settings QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/settings python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/proof_settings.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_settings.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Output: `native/settings/*.png`, `native/settings/state.jsonl`, `native/manifest_settings.json`.

## map

Open Scout; hover mystery rooms and rooms near other choices; inspect the current-room marks and background title. Revisit cleared noncombat rooms to compare room/map names. For L87 repeat with seeds 81,84,85 via the native game/fixture rather than assuming seed 83 covers them.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/map python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_map.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario start --seed 83
```

Output: `native/map/*.png`, `native/map/state.jsonl`, `native/manifest_map.json`.

## prebattle

Fixture equips Iron Cleaver; inspect Equip icon and deck strips.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=pre_battle QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/prebattle python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/proof_prebattle.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_prebattle.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/observe.gd
```

Output: `native/prebattle/*.png`, `native/prebattle/state.jsonl`, `native/manifest_prebattle.json`.

## pass

Use an actual mouse click on Pass, keep the pointer there through the enemy turn and the deal; inspect stale tooltip text and bright/dim transitions.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/pass QA52_BURST=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_pass.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --hand quick_stab,brace,patch_up,updraft
```

Output: `native/pass/*.png`, `native/pass/state.jsonl`, `native/manifest_pass.json`.

## crate

Select an attack, move the actual pointer onto/off the crate; inspect its preview onset/clear and hero/crate bar depth. Move into the behind-hero arrangement as needed.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/crate QA52_BURST=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_crate.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --player-position 3:4 --terrain wooden_crate@4:4 --hand quick_stab,volt_surge
```

Output: `native/crate/*.png`, `native/crate/state.jsonl`, `native/manifest_crate.json`.

## retaliate

Apply Retaliate, allow a Bleed-capable hit, compare hit/chip/cue frames; also inspect normal, Meteorfall and retaliation kill/body/bar fades. A chosen enemy action may need advancing the clock.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/retaliate QA52_BURST=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_retaliate.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --enemy-types crawler --enemy-intents skitter_strike --player-position 3:4 --enemy-positions 4:4 --hand barbed_mail,meteorfall,quick_stab
```

Output: `native/retaliate/*.png`, `native/retaliate/state.jsonl`, `native/manifest_retaliate.json`.

## reward

Click an actual reward card. Burst records the pop, ghost edge, rune/inner arc, screen close and acquisition beam; do not call the handler without its card.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/reward QA52_BURST=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_reward.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario reward --seed 83 --reward-cards quick_stab,pale_spark,sidestep_slash
```

Output: `native/reward/*.png`, `native/reward/state.jsonl`, `native/manifest_reward.json`.

## deferred

Click Skip at the reward and inspect the Deferred Choice dialog. The observer applies the supplied fixture skill to the saved profile.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/deferred python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_deferred.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario reward --seed 83 --level 3 --skills discerning_eye,deferred_choice
```

Output: `native/deferred/*.png`, `native/deferred/state.jsonl`, `native/manifest_deferred.json`.

## event_reward

Choose the offered magic reward path (Pay Embers, if available), then inspect the event reward Skip beside its other actions. Do not infer the label from a normal combat reward.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/event_reward python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_event_reward.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario event --seed 83 --held-embers 1000 --event-id whispering_well
```

Output: `native/event_reward/*.png`, `native/event_reward/state.jsonl`, `native/manifest_event_reward.json`.

## purge

Open Purge, select a card in a deck with seven distinct spells, inspect the second row/confirmation, then confirm and inspect its flight, retained notice and shop close.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/purge python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_purge.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario scavenger --seed 83 --held-embers 1000 --attuned-magic updraft,crosswind,razor_gale,eye_of_the_storm,cinder_fusillade,volt_surge,molten_reach
```

Output: `native/purge/*.png`, `native/purge/state.jsonl`, `native/manifest_purge.json`.

## audio

At default volume, select/hover/play a light hit, kill an enemy and Pass with no draw. Listen to swish/hit mix, returned-play pulse and handoff; record separately if judging loudness.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/audio python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver CoreAudio --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_audio.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --hand quick_stab,brace,patch_up
```

Output: `native/audio/*.png`, `native/audio/state.jsonl`, `native/manifest_audio.json`.

## summons

Let summons arrive and later die; compare arrival silence versus death cue. This command covers one summoner; repeat real Noctyrax/Zekarion/Lamplighter fights before generalizing.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/summons python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver CoreAudio --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_summons.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario guardian --guardian-id storm_cantor --guardian-case summon --seed 83
```

Output: `native/summons/*.png`, `native/summons/state.jsonl`, `native/manifest_summons.json`.

## event_audio

Hover/focus event choices without activating them and compare to Hearth focus using its existing fixture.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/event_audio python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver CoreAudio --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_event_audio.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario event --seed 83 --event-id hanged_knight
```

Output: `native/event_audio/*.png`, `native/event_audio/state.jsonl`, `native/manifest_event_audio.json`.

## event

Inspect Cut him down detail wrapping, event health, retained Grimoire notice, then resolve an HP-changing choice when available.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/event python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_event.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario event --seed 83 --event-id hanged_knight
```

Output: `native/event/*.png`, `native/event/state.jsonl`, `native/manifest_event.json`.

## fire

Push onto Fire, move/start a turn on Fire, inspect separate popup causes and sound. For traced arrival/cascade sound use a movement/death-cascade case, not just a direct spell hit.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/fire QA52_BURST=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver CoreAudio --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_fire.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --surfaces fire@4:4 --player-position 3:4 --enemy-types crawler --enemy-positions 4:3 --hand updraft,crosswind,barbed_mail
```

Output: `native/fire/*.png`, `native/fire/state.jsonl`, `native/manifest_fire.json`.

## guardian

Press Start on the actual guardian prebattle. Inspect its opening through the objective and deal; compare to the dragon opening.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/guardian python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver CoreAudio --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_guardian.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario guardian --guardian-id ashen_reaver --guardian-case pre_battle --seed 83
```

Output: `native/guardian/*.png`, `native/guardian/state.jsonl`, `native/manifest_guardian.json`.

## dragon

Press Start on the actual dragon prebattle; inspect roar cue, pose and facing. Repeat all six IDs to judge every rig. Source proof already establishes all six roar branches.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/dragon python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver CoreAudio --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_dragon.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario dragon --dragon-id vyraketh --dragon-case pre_battle --seed 83
```

Output: `native/dragon/*.png`, `native/dragon/state.jsonl`, `native/manifest_dragon.json`.

## escape

The enemy-hp=1 debug override shortens this capture only. Win the final fight, take/skip its actual reward, complete the existing heirloom prompt if offered, and inspect the real ESCAPED transition for intermittent Victory residue. A loaded victory fixture cannot decide this.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/escape QA52_BURST=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_escape.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario dragon --dragon-id noctyrax --dragon-depth 6 --seed 83 --enemy-hp 1
```

Output: `native/escape/*.png`, `native/escape/state.jsonl`, `native/manifest_escape.json`.

## skills

Close dialogue/map, open Character→Skills, inspect the whole tree and each connecting line.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/skills python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_skills.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario character --seed 83 --level 12
```

Output: `native/skills/*.png`, `native/skills/state.jsonl`, `native/manifest_skills.json`.

## sell

Switch to Sell, inspect disabled page arrows and select MAGIC. Confirm the filter has no sellable spells despite the attuned magic.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/sell python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_sell.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario scavenger --seed 83 --equipment-inventory iron_cleaver,duelist_rapier --item-inventory crimson_draught --attuned-magic updraft,crosswind
```

Output: `native/sell/*.png`, `native/sell/state.jsonl`, `native/manifest_sell.json`.

## opening_audio

Press Start on the actual prebattle fixture; listen and correlate planning/combat music with the objective and deal. The frame trace logs _active_music_id.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/opening_audio python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver CoreAudio --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_opening_audio.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario pre_battle --seed 83
```

Output: `native/opening_audio/*.png`, `native/opening_audio/state.jsonl`, `native/manifest_opening_audio.json`.

## graftwright

Close the Graftwright screen with its real Leave action and inspect the persistent room body/NPC list.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/graftwright python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_graftwright.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario graftwright --seed 83
```

Output: `native/graftwright/*.png`, `native/graftwright/state.jsonl`, `native/manifest_graftwright.json`.

## fresh

Starts New Run through the actual menu handler on an isolated default profile. Follow its tutorial/awakening flow. Inspect the first-room Grimoire notice; do not substitute a rich combat fixture.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/fresh QA52_FRESH=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_fresh.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd
```

Output: `native/fresh/*.png`, `native/fresh/state.jsonl`, `native/manifest_fresh.json`.

## preview

Hover/select a Block or buff card, confirm through the real input path, inspect the hero preview during the flight and buff-only playback labels.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-52 && QA52_SURFACE=manual QA52_OUTPUT=res://spec/peer_benchmark/qa/polish_verify_2026-11-05/native/preview QA52_BURST=1 python3 tools/visual_probe_runner.py --task-id qa-52 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 75 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_proof.json --result-manifest spec/peer_benchmark/qa/polish_verify_2026-11-05/native/manifest_preview.json spec/peer_benchmark/qa/polish_verify_2026-11-05/probes/manual_capture.gd -- --scenario combat --seed 83 --hand brace,whetstone,barbed_mail,updraft
```

Output: `native/preview/*.png`, `native/preview/state.jsonl`, `native/manifest_preview.json`.

