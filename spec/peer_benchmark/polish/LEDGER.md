# Polish slot ledger (director owns this file)

## Items
**Slot paused** by the owner on 2026-11-02: no new picks until asked. pol-47 was already running and finishes; approvals still merge.

| Item | Title | State | Notes |
|---|---|---|---|
| pol-47 | Camp buttons say where they go, on the title menu's stone slabs | **rejected** by the owner; branch deleted (see "Owner said no") | 57 min, about 386k tokens. |
| pol-46 | A card's keywords move to its left instead of covering Pass | **rejected** by the owner; branch deleted (see "Owner said no") | 55 min, about 315k tokens. |
| pol-45 | The reward card you take pops and lifts, and the old ring blooms around it | **approved, merged** (r2: pop and lift kept, MAGIC IN DECK dropped, ring ×3.668 riding the card) | 46 min over two rounds, about 453k tokens. |
| pol-44 | A reward taken without its card no longer draws its ray from the screen corner | **merged by the director** 4af950ff8, not posted: the streak came only from probes taking a reward in code without the card; both real callers pass the clicked card, so players never saw it. 3-line guard plus a regression in `event_view_suite.gd` | 34 min, about 315k tokens. |
| pol-43 | After a deal or a deselect, the card under the pointer is the one that lifts | **approved, merged** c21d0acc6; its deal regression waited only 8 frames, so after pol-38..40 it failed while the hand still eased. `pol-43-fix` (18cbf1d0c, test only) waits on the real slide state; behaviour already matched | 65 min, about 472k tokens. |
| pol-42 | Updraft reaches 4, Cinder Fusillade hits 6, Eye of the Storm blocks 9 | **approved, merged** | 21 min, about 239k tokens. |
| pol-41 | Moving to the next card clears the old card's keyword box at once | **approved, merged** f4ae58832 | 42 min, about 245k tokens. |
| pol-40 | Sweeping across the hand eases the neighbours, instead of jumping | **approved, merged** | 60 min, about 367k tokens. |
| pol-39 | Selecting a card eases its neighbours apart, instead of popping | **approved, merged** | 40 min, about 383k tokens. |
| pol-38 | The hand slides shut after a card is played, instead of snapping | **approved, merged** | 31 min, about 331k tokens. |
| pol-37 | Pass and your counters stay put while you play your hand | **approved, merged** | 40 min, about 303k tokens. |
| pol-36 | Item rows say what the item does, so they're no longer half empty | **approved, merged** | 16 min plus a director tweak (rows drop the leading "Consume."), about 221k tokens. |
| pol-35 | No more long, empty card strips: the Magic list now uses the compact strip | **approved, merged** | 17 min, about 328k tokens. Survey of 15 screens found only the Magic list. |
| pol-34 | The enemy's move is named in a clear heading, not in small print | **approved, merged** | 75 min plus a director tweak (boss moves drop the boss's name under its bar), about 340k tokens. |
| pol-33 | The Chronicle is a quiet link on the run-end screen, not a third button | **approved, merged** | 37 min, about 280k tokens. Owner follow-up on pol-13. |
| pol-32 | Words no longer run together: the game font gets proper word spaces | **approved, merged** | 32 min, about 302k tokens. Font space advance only (250 in all three cuts); font pins refreshed on the branch. |
| pol-31 | The Character screen lists your deck once, like the fight preview | **approved, merged** | 27 min, about 229k tokens. Owner request from pol-19 and pol-22; strips at 190 px, 3 columns on Gear, 5 on Magic. |
| pol-30 | Volt Surge hits as hard as Molten Reach: 4 damage, not 3 | **approved, merged** | 21 min, about 193k tokens. Data only. |
| pol-29 | A card's Retaliate or attack bonus shows up the moment it lands | **approved, merged** | 17 min, about 262k tokens. |
| pol-28 | A status landing on a unit now pops, so you see Bleed or Expose arrive | **approved, merged** | 22 min, about 255k tokens. |
| pol-27 | A dragon fight opens on the dragon's roar, and its theme starts there | **approved, merged** | 22 min, about 244k tokens. |
| pol-26 | Damage numbers land on the hero, not over the floor beside him | **approved, merged** | 28 min, about 291k tokens. |
| pol-25 | Burning on Fire at your turn's start now shows a -3 and makes a sound | **approved, merged** | 23 min, about 289k tokens. Pairs with pol-21. |
| pol-24 | An event's "Leave" choice sits centred in its box, not at the top | **approved, merged** | 12 min, about 147k tokens. |
| pol-23 | Unknown rooms on the map get a proper medallion and a clear "?" | **approved, merged** (round 2, inbox id pol-23-r2: lighter "?" centred optically, Umbra pool under each unknown seal) | 21 min plus round 2 about 45 min, about 800k tokens in all. |
| pol-22 | Character screen: the hero stands on his shadow, empty slots say it once | **approved, merged** | 35 min, about 192k tokens. |
| pol-21 | Burning on Fire sounds like the fire flaring, not a whole fire spell | **approved, merged** | 27 min, about 279k tokens. |
| pol-20 | The Scavenger's bottom bar: two clear tabs and a Purge with its own price | **approved, merged** | 17 min, about 233k tokens. |
| pol-19 | The fight preview lists your deck once, so the whole deck fits | **approved, merged** | 64 min (25 waiting on the lock), about 267k tokens. |
| pol-18 | Cheaper cards show their Time cost in teal, and pricier ones in ember | **approved, merged** | 68 min, about 171k tokens. |
| pol-17 | Damage numbers grow with the hit: a 12 lands far bigger than a 2 | **approved, merged** | 31 min, about 205k tokens. |
| pol-16 | A room keeps its name after you win, instead of turning into "Chamber" | **approved, merged** (round 2: owner asked for Scavenger's Nook; fixed names for every room without a fight) | 27 min, about 197k tokens. |
| pol-15 | Winning clears the screen: VICTORY lands on the board alone | **approved, merged** | 78 min, about 310k tokens. |
| pol-14 | Settings no longer cuts the title in half, and every row fits | **approved, merged** | 20 min, about 200k tokens. |
| pol-13 | The Chronicle button at the end of a run finally opens | **approved, merged** | 26 min, about 244k tokens. |
| pol-12 | Light sword hits finally land instead of ticking under the card sound | **approved, merged** | 56 min, about 374k tokens. On approval, refresh the pin for `hit.blade.light_01.ogg` at merge. |
| pol-11 | Tempest Form becomes a legendary you can feel: 2 less Time per card | **approved, merged** | 30 min, about 193k tokens. Data only. |
| pol-10 | The map dissolves in after every room; Purge shows what you purged | **approved, merged** | 39 min, about 235k tokens. New `scripts/screen_crossfade.gd`. |
| pol-09 | Enemies killed outside your own action now dissolve, not blink out | **approved, merged** | 43 min, about 299k tokens. |
| pol-08 | The reward skip button stops promising health you can't gain | **approved, merged** | 71 min (mostly queue), about 238k tokens. |
| pol-07 | Searing Light finally outclasses the common card it resembles | **approved, merged** | 22 min, about 172k tokens. Data only. |
| pol-06 | Retaliate now sounds when it hits the attacker | **approved, merged** | 16 min, about 179k tokens. |
| pol-05 | Meteorfall finally lands: meteors, a slam and Fire in one beat | **approved, merged** | 78 min (about 45 queued), about 300k tokens. |
| pol-04 | Names above the Emaciated Man and Scavenger are readable, with no box | **approved, merged** | 26 min, about 143k tokens. |
| pol-03 | Crate and box health bars get a painted iron frame | **approved, merged** | 39 min, about 285k tokens. New asset needs owner approval on merge. |
| pol-02 | Cards you can't play fall into shadow instead of washing out | **parked** (owner 2026-11-03: skip for now, the faded look may be better); branch `codex/pol-02` kept | 58 min (25 queued), about 165k tokens. |
| pol-01 | Ember Hearth: four centered choices, and Purge gets its own painting | **approved, merged** 74ab664a5 | First item: 51 min, about 380k tokens. New asset needs owner approval on merge. |

## Owner said no
Reasons go here, so the slot doesn't repeat them.
- **pol-47** (2026-11-02), the camp menu on the title menu's stone slabs, with "Save and Exit to Desktop" and "Save and Return to Menu": "I don't think the stone buttons work in this menu and I also am not certain the new language is better overall." Keep the camp's plates and its labels. Don't restyle in-run menus with the title menu's slabs.
- **pol-46** (2026-11-02), a hand card's keyword box flipping to its left to avoid Pass: "I actually don't like it flipping to the other side and covering pass is fine since as soon as you move off of the card to click pass, the tooltips will be gone." The general rule: a hover pop-up may cover other controls, because reaching them dismisses it. Don't move or flip hover pop-ups to dodge controls.

## Spotted
Candidates noticed along the way, worst first. Take one if it's still the best choice.
- After deselecting a card with the pointer still on it, the card stays down until the pointer moves; it doesn't rise back into hover.
- At turn start with the pointer resting on the hand, the card that was under the pointer in the old layout lifts for about 4 frames, then hover moves to the card really under it (a 120 px jump, eased since pol-40). Same family as the deselect note above and the deal-under-a-resting-pointer note: after any redeal, hover should resolve to the card under the pointer.
- During the 2-frame hover rest the previous card's turn-order projection stays, so the portraits can briefly cover the newly lifted card's title (perf-13 keeps it on purpose).
- Tooling: `tests/locked_hand_cache_lifecycle_probe.gd` fails on the base with 5 errors (reused target pixels, ancestor_tint, fractional_transform).
- Quick Stab's 9 in green is probably its adjacency bonus (the +3 row shows a check mark with the crawler adjacent), so the "Quick Stab showed 9" note is likely correct behaviour.
- Tooling: in movie captures a pointer parked over the hand gets no hover even after a re-check, so real-mouse hover paths can't be filmed with this harness.
- An enemy standing next to the hero puts its health bar and intent number across the hero's chest (Bone Harrier at seed 83). Same family as the status-row note.
- Tooling: windowed probes failing on the base: `pass_preview_probe` ("String formatting error" in its '%d card plays' copy check, dense rail overlap, 3 missing risks), `card_completion_stall_probe`, `steam_deck_compat_probe`, `combat_interaction_probe` (board top 19% against a 15% limit).
- Item-row text uses the authored card text, so an item changed by a skill shows its base numbers there (card face and tooltip show the changed values).
- "Crimson Draug..." trims in the 190 px deck strips (with Rite of the Mountain, Shattered Reflection, Cinderweave Guard, Lodestone Reversal).
- The controller focus frame on Pack rows is drawn inside the row and crosses the eyebrow and the bottoms of the Equip and Inspect buttons (gear rows too).
- Opening boon "Elemental Gift" spell strips fill the boon card's 276 px inner width, about a third empty. Sized to the card; left.
- Scavenger "Purge a spell" button: its price tag (50) floats above the button bar, detached from the button.
- Possible softlock on Continue: in 5 of 14 movie captures the game sat on "Entering the Labyrinth." until timeout; the threaded run-scene load in `scripts/menu_run_transition.gd` never finished. Director note: the capture probe (`tests/fix18/real_fight_capture_probe.gd`) gives Continue only 20 s, and these captures ran beside other agents' Godot jobs, so this is more likely a slow cold load under load than a softlock. Cheap next step: have the probe print the transition's phase and `performance_snapshot()` on timeout, and allow 60 s. A QA unit only if a stall shows past 60 s or in a real launch.
- The action caption's soft shade keeps a 360 px minimum width, so a short caption ("Stonewake") shows a faint band wider than the word. `_layout_action_banner`; Noctyrax's reserve band uses it as a lower bound.
- Tooling: `tests/warband_ui_test.gd` fails on the base (locked-wind hash 284401706); `tests/dragon_pressure_presentation_probe.gd` fails on the base (Noctyrax `_aoe_refuge` actions never rendered, probably stale after bos-03).
- Tooling: a fresh worktree needs `python3 tools/cel_look.py build --if-stale` before captures, or clips silently use the original art. Fixture `--hand` takes card ids (Low Sweep is `hamstring_shot`); CLIP_PLAN indices count after earlier plays.
- After a defeat the Chronicle lists the run as "SLAIN" while the recap just titled it "FALLEN" (the recap's title is seeded per run). The two screens should agree.
- Tooling: `tests/run_end_recap_probe.gd` fails on integration in its two player death-cutout checks, so it exits 1 regardless of recap changes.
- Tooling: the visual-probe path doesn't run the import bootstrap, so fixture probes that boot through the main menu fail quietly in a fresh worktree ("Identifier SettingsPanel").
- Keyword pop-up bodies are only 226 px wide, so about 31 of 140 glossary entries end with one word alone on the last line. A few pixels more would fix most (a question on pol-32).
- The top bar puts a double space between "LV 1" and "EMBERS 0"; it shows more now that single spaces are right.
- "2 Card Plays" (title case) beside "2 / 2 movement" (lowercase).
- Four card names still trim in the 190 px deck strips even at 13 px: Rite of the Mountain, Shattered Reflection, Cinderweave Guard, Lodestone Reversal.
- The medallion above a door fades with the door when the door goes see-through for an actor behind it, so its "?" is hard to read (seeds 81, 84, 85).
- With the map open, the room title shows faintly through the dark backdrop above the map frame's top-left corner.
- Tooling: in a cold worktree, `card_legibility_test` fails with "SettingsPanel not declared" until a headless import builds the class cache.
- Owner follow-up from pol-27: dragon fights should open with the dragon facing the screen, with a real roar animation timed to the roar. Rig and animation work, so a Codex unit, not this slot.
- The keyword pop-ups on an area card contradict each other: RANGED says "in Range and line of sight", AREA ATTACK right below says "even unseen ones". Volt Surge, Molten Reach.
- Line cards (Volt Surge, Molten Reach, Thunderline) always open aimed the same way, not toward the most enemies; push aims follow the enemies. Check whether that's intended.
- After Volt Surge resolved, Quick Stab's face showed 9 damage in green instead of 6, with nothing on screen saying why. Not traced.
- Tooling: `tests/character_menu_polish_probe.gd` is stale (expects a reserve spell removed by deck-01) and stops before its deck checks.
- Tooling: pol-30's card-play clip copy adds CLIP_HOVER (rest the pointer on hand cards) and CLIP_ROTATE; it lives in `output/polish/pol-30/clip_tool/`.
- Stacked titles: "Relic Cache", "Relic" and "CLAIM YOUR TREASURE" on one screen; a faint "Victory" above "ESCAPED".
- Boss fights name the boss three times: top bar, objective title and objective subline. (pol-34 stops the action caption from making it four.)
- Defeat screen's score "0" sits about 120 px left of the divider's end, because it keeps room for a NEW BEST chip that isn't there.
- Event screen's "24 / 24" touches the end of the health bar.
- The room's "Speak" button peeks out below the Character panel.
- The hand may snap between bright and dim with no transition when you press Pass. Code only, not judged in motion.
- Tooling: `tests/card_drag_overlay_probe.gd` hangs headless until its 300 s timeout.
- With a card selected, a crate's damage preview appears about 0.6 s after aiming and clears about 0.6 s after leaving. Measured without a real mouse.
- The hero's bar draws over the bar of a crate behind him. Slightly more visible with the wider frame.
- The Scavenger's painting in the shop has far coarser pixels than the shelves and cards beside it.
- Unmerged branch `codex/meteorfall-card-falling-meteor-impact-effect` (2026-10-01) has staggered meteors and a fuller comet shared with Vyraketh. No verdict on record.
- A kill's returned Card Play has no sound, only a meter pulse. The old Ember pickup sound was removed on purpose in July, so this is a taste question.
- ~~Weak by the heuristic: Tempest Form, Rites of the Pyre, Tailwinds and the Storm, Vortex.~~ Closed by bal-02 (2026-11-04): none is weak in play; the scorer underrates lasting effects (Tempest Form, Tailwinds). No numbers changed.
- While a card is hovered, the turn-order strip slides over the right edge of the Objective panel and butts against "DEFEAT ALL ENEMIES".
- Searing Light and Stoke carry a faint bow watermark though neither aims at anything.
- With Retaliate up, the striker's Bleed reaches the hero about 0.4 s after its hit, arriving with the Retaliate. The chip and its sound lag the blow.
- Tooling: `tests/sfx_cue_coverage_probe.gd` already fails on two empower cues on the base.
- The turn-order strip could avoid the Objective panel: make `placement()` avoid it when it can. It follows perf-11, which holds that file.
- Reward cards sit about 60 px lower with the "Added 9 entries to the Grimoire" box up; cause not traced.
- The Deferred Choice pop-up is a plain purple-outlined box, well below the finish of the reward screen.
- Event rewards use a mixed-case "Skip" while the buttons beside it are all caps.
- Tooling: fixture scenarios blacksmith and arcanist are listed as valid but fail; --scenario character stops at the dialogue instead of opening Character.
- The pale health bar outlasts a dissolving body by about 0.25 s, over an empty tile. Seen on Meteorfall and Retaliate kills; normal kills not checked. A question on pol-09.
- Updraft (common, 4 Time) is strictly worse than Crosswind (common, 3 Time): same 3 damage, range 3 and push 2, costs more, no choice of direction. Razor Gale (rare, 4 Time) only adds 1 damage over Crosswind for 1 more Time and loses the direction choice. Updraft at push 3 would restore a real choice; not scored.
- Eye of the Storm (epic, 5 Time) gives 6 Block and a push only after you're hit. Common wards give 5 Block plus an effect for 3 Time. Heuristic 1.90, among the lowest epics.
- Cinder Fusillade (rare, 4 Time, 5 damage) is 1 damage over Firebrand Volley (common, 3 Time, 4 damage), same range and Fire. Heuristic 3.26 against 3.25.
- Deferred Choice pop-up: a plain purple hairline box with flat buttons, shown only with the `deferred_choice` skill.
- Test gap: the last-action dissolve test in `combat_pacing_regression_suite.gd` uses a Bleed kill, so it passed through the pol-09 bug. pol-09's check covers it.
- Tooling: `codex_unit.py locked` fails with "not a git repository" outside a checkout. For Meteorfall, `CLIP_TARGET` is the middle of the three-tile line, so 4:4 with the hero on 3:4 also hits the hero.
- The purged card flies to the corner in about 0.25 s, like a discard, and passes outside the dialog frame. Burning it in place would suit a permanent loss.
- In the Purge confirmation with 6 or more different spells, the grid's second row shows below the Purge and Back buttons and through the card's red glow.
- Windowed probes fail on the base: `campfire_choice_probe`, `section_map_flow_probe`, `scavenger_shop_probe`, `dragon_reward_feedback_probe`. Stale or real regressions: not checked. They give no protection for those flows today.
- During the Purge beat the bottom-right message box still shows the previous notice. Check it in a real run.
- The same dissolve could soften other hard cuts, such as closing a pop-up back to the shop after buying a Purge. Not looked at.
- ~~Scored, not applied: Cinder Fusillade 6, Eye of the Storm 9 Block, Updraft range 4.~~ All three already on release (bal-03 checked 2026-11-05; bot check found no outlier).
- The turn-order preview chip reads "Tempest Form +0" in very small text. Accurate, but it reads as if the card is free.
- Tooling: a failed capture leaves its frames folder behind and the retry refuses to run until it's deleted. The first capture in a new worktree can time out in the Continue transition under load; the retry passes.
- The card-play swish has the highest peak of any everyday sound (-1.1 in the file), and now sits level with the light hit. A question on pol-12.
- The whole game may be quiet at default volumes: music about -30, ordinary hits -21 to -25, clip peak -7.6. Not compared against another game.
- The October mix pass may have measured mono files 3 dB low, so mono cues could run 3 dB hotter than stereo cues with the same target. Confirmed for `card.select` only; `card_play_take` didn't fit. Check first.
- Enemies arriving mid-fight (reinforcements, summons) appear to have no sound. Code only.
- The YOUR TURN banner has no sound, so the hand-off is silent when no cards are drawn. A turn-start bell existed for part of 2026-09-30 and was removed that day, reason unrecorded. Taste question.
- The card hover tick fired twice with no mouse movement when the hand redrew with the pointer resting on a card. Seen in a sound trace with a probe-parked pointer.
- Tooling: the on-demand sound group has failed on the base since pol-05, from two Meteorfall call sites missing from coverage.
- Main-menu Chronicle: the top of "ESCAPE" shows above the frame and "EMBERS 0 | SKILLS 0/19" below it. On a new profile the empty state is two stranded lines.
- The Escaped screen, the best moment in the game, has plainer buttons than defeat. A question on pol-13.
- Escaped screen with all six dragons cuts the row off at "Zeka...".
- The faint "Victory" beside ESCAPED is intermittent, so it looks like a banner still fading out.
- Skill tree: the connecting lines tangle and cross unrelated nodes, so "leads to" is hard to trace. Bigger job.
- Chronicle opens as a hard cut on both paths. pol-10's dissolve could soften it if approved.
- Tooling: the game's pointer can't be moved by probe input in movie captures.
- Settings volume sliders are a plain grey bar with a white dot, the only controls on that screen outside the game's style.
- Settings copy reads like developer notes: "Window changes stay bounded and centered", "Skips supported entrance and travel flourishes".
- Restore confirmation: when "Reset every setting?" opens, a scroll bar reappears, the rows jump about 8 px left and Reduced motion is hidden. Two red buttons also sit together ("Restore" and "Restore defaults").
- Clicking outside Settings still works on the main menu, so the menu buttons stay live with it open. Not tested for anything odd.
- Tooling: `tests/pause_overlay_probe.gd` fails with 4 stale combat HUD checks on the base; `tests/selective_ui_salvage_probe.gd` reports 33 errors, unchecked against the base.
- The Pass tooltip can stay up through the enemy's turn when the pointer rests on Pass: "Ending now leaves 1 card play unused: +5 Time", after the turn has ended. Seen in pol-09's Retaliate clip at 5.0 s. Clearing it while the button is disabled should fix it.
- Word spaces in the game font are very narrow, 0.172 em against 0.665 for "n" (Bitter is 0.22 against 0.623), so text reads as "LEAVES1 CARD PLAY" and "crumblesintodust". The fix is in `tools/build_labyrinth_font.py`, but it touches every line of text and could change wrapping, so it needs its own item.
- A card dealt under a resting pointer lifts by itself, and its tooltip can cover Pass with a full hand. Hover code belongs to perf-12. (Covering Pass is fine per the owner; see pol-46 under "Owner said no".)
- The reward screen sits high: banner to Skip spans about y=120 to 690 of 1080. From stills only.
- The enemy action caption ("Ash Hound: Bite") is small and sits at the top of the screen, far from the action, and is the only text naming what an enemy is doing.
- Tooling: `program_suite_runner --suite` expects a top-level test name, so the pacing suite has to run through `tests/combat_feel_test.gd`. `tests/reward_decision_support_probe.gd` fails with 8 errors on the base.
- The map's view of a room and its fight roll different names ("Bleak Vault" against "Sealed Sanctum"). After pol-16 only a room you return to without a fight could show this. Fixing the cause means refreshing the layout goldens.
- The message box said "Unclaimed gear crumbles into dust." at a reward with no gear offered. Possibly on every win; not checked against a fight with loot.
- The Pass tooltip staying up through the enemy's turn may be a capture artifact: the clip's probe presses Pass in code with the pointer parked. Needs a real-mouse check.
- A dragon's or guardian's arrival has no moment of its own: the fight simply opens with it standing there, and from the code the roar waits for its first action. From one Tharokh clip and the sound config only. It could be a good delight item, but it adds to the boss name already shown three times.
- Event-screen health numbers keep one size, so losing 12 HP looks like losing 1. They could use pol-17's steps.
- Tooling: `real_fight_clip.py` fails with "Legal actor floor tile" for a 2x2 enemy unless all its tiles are floor. Tharokh at 5:2 with the hero at 4:3 works on seed 83.
- "Unclaimed gear crumbles into dust" may be correct: in pol-18's fight, loot was left on the floor and the notice showed. Check a fight with no floor loot before fixing it.
- The Pass button, the Card Plays counters and the Objective panel move sideways as the hand shrinks: in pol-17's clip Pass shifts by roughly 250 to 500 px over one turn and jumps right when the hand empties. A fixed Pass would be easier to hit. Needs a layout decision.
- The turn-order preview chip ("Tempest Form +0") could use pol-18's teal and ember when a cost changes.
- Tooling: `real_fight_capture_probe` doesn't accept `--enemy-hp`. Ash Hound has 5 HP at depth 1; use ashen_reaver (40 HP) for multi-card clips. `tests/card_legibility_test.gd` takes over 240 s under load and rewrites tracked files in `tests/pt13_03` on every run.
- The Character screen and the fight preview disagree about where spells go (Character keeps them out of its "Deck" list). A question on pol-19. Aligning them is in `run_scene.gd`.
- Deck strips cut long names short: "Crimson Draug..." in the preview's two-column list.
- The preview's Equip button always shows the training sword icon, whatever weapon is equipped.
- Sell mode: the page arrows at the top right of YOUR PACK are almost invisible when disabled, so they read as two empty smudges.
- Sell mode has a MAGIC filter, but spells can't be sold there because they go through Purge. It may never show anything. Not checked.
- Fire damage through traced arrival or cascade steps has no label, so the router plays nothing. Code only.
- Reinforcement spawns (Survive rooms, parked) reuse the death animation backwards, so the newcomer's death sound plays as it arrives and its real death is silent. Code only.
- Summons (Storm Cantor, Last Lamplighter, Noctyrax, Zekarion) appear with no arrival sound beyond their summoner's action. Not checked in game.
- Tooling: the sound sync programs only check onsets and coverage with `-- --assert-onsets`; run bare, they report PASS even on the base.
- Tooling: since the map rework, a probe run opens on the map. Call `_close_dialogue()`, then `_close_large_map()`, before opening the Character screen.
- In Scout mode an unknown room's tooltip says "Not yet visited" instead of saying a click will scout it; "Scout to reveal" never shows for mystery rooms because they already count as revealed.
- A room's tooltip can drop down over the room below it: hovering the top "?" at section start covers the first fight choice under it.
- The room you stand in is marked three ways at once (lantern picture, cream ring and a pointer above). Possibly one too many; taste question.
- Tooling: the UI identity lint counts dropped with pol-23; a `--tighten` pass could lock them in once the open polish branches merge.
- Blocked by pending items: the audio ideas (Fire entry and hero burn in `sfx_cue_router.gd`, held by pol-21; dragon arrival and a YOUR TURN sound in `run_scene.gd` and `sfx_cues.json`, held by pol-10/15/16 and pol-12). They free up once those land.
- Event choices make no sound on hover, while the Ember Hearth's choices tick on focus. A soft tick would only touch `event_view.gd`. Taste question, given how quiet the other menus are on hover.
- The Hanged Knight's "Cut him down" detail wraps to leave "fights)" alone on its own line.
- The notice "Added 2 entries to the Grimoire." shows faintly in the bottom-right corner under the event panel when an event opens.
- Pushing an enemy onto Fire shows the push and the burn as one number (-5) with only the push's air sound; the fire part has no sound of its own. Taste call.
- The hero's turn-start burn number has no cause icon (enemy Bleed ticks get one). A small fire icon would say "Fire" without text.
- In a cramped spot (an actor straight below on screen, tiles about 120 px), a number still doesn't fit between its own bar and the next actor's bar and jumps sideways. Headless only.
- A number reserves room for its biggest size at the top of its rise, though it has shrunk by then. Reserving its true path would free about 13 px. Shared by every number; separate item.
- Tooling: `real_fight_clip.py` with 1 round misses enemies that act later on the turn clock; the Warden's 5-Time Marching Blow needed 2 rounds.
- Guardians (Ashen Reaver, Storm Cantor and the rest) still open with no moment of their own. pol-27's hold and shudder with a heavy footfall could carry over. Taste question.
- No dragon rig has a roar or head-raise pose, so the dragon stands still under its own roar. A short roar clip per dragon is rig work.
- The planning music plays on through the whole opening of every fight; a normal fight probably swaps to its fight music only after the deal. Not checked for ordinary fights.
- Tooling: pol-27's new roar call isn't in the sound sync audit's coverage yet (adds one uncovered call; covering it touches `sync_baseline.json`, which pol-21 also changes). `Input.warp_mouse(...)` in a movie-capture probe does park the game's pointer. Fight-opening clip tools: `director_tools/fight_opening_clip.py` and `fight_opening_clip_probe.gd`.
- When an enemy stands right next to the hero, its intent chip and health bar can cover the hero's whole status row (the hero's Retaliate 3 was never visible beside the Warden).
- Tooling: a general real-fight clip that plays a list of cards (`CLIP_PLAN="0@5:2;0@self"`): `director_tools/card_play_clip.py` with `card_play_clip_probe.gd`.
- The Graftwright's room has no Graftwright standing in it once the screen closes, unlike the Scavenger's room. Check whether that's intended.
- On a fresh run the "Added 23 entries to the Grimoire" notice shows in the first room. Probe-only so far; check a real first run.
- Confirming any card first drops the preview's results on the hero (Block bar and buff badges) for about 0.4 s while the card flies in, then replays them; enemy statuses from the preview do the same before the hit. Design question in the preview-to-playback handoff in `run_scene.gd`. A question on pol-29.
- Retaliate, Quicken and next-attack steps have no label of their own in card playback (Block, Heal and Draw get "+N"), so a buff that's a card's only effect, like Whetstone, lands without text. Taste call.
- Tooling: movie clips' START_FRAME runs about 35 frames ahead of the movie's own frame count. With 2 Card Plays, a third card in a CLIP_PLAN silently does nothing; add a Pass.
- Tooling: every native soak round capture fails its 1920x1080 assert (looks like the Retina backing size), so every soak manifest reports ok=false though the report is valid. `_save_root_screenshot`'s normalization would fix it.
- Tooling: pol-40's clip probe logs at `frame_pre_draw` (movie frame = log frame) and adds a `sweep:A:B:S` pointer glide; copy in `output/polish/pol-40/clip_tool/pol40_clip_probe.gd.txt`.
- In a quick sweep (3-5 frames per card) each card's keyword box still flashes for 1-2 frames, since the 2-frame rest completes on every card. A rest counted from pointer stillness, or a short fade-in on the box, would calm it; that changes the rest rule (a question on pol-41).
- Leaving the hand: the lifted card stays raised about 7 frames after hover clears while its box hides at once (likely the lowering ease). **Already fixed on release (ui-16 traces, 2026-11-05).**
- Tooling: hover_equivalence's native --capture saves PNGs at the Retina backing size (3024x1898), so `tools/perf11/hover_proof.json`'s 1920x1080 contract fails though the oracle passes. pol-41's per-frame keyword-box log (TIPLOG, tiplog.py) is in `output/polish/pol-41/clip_tool/`.
- Razor Gale (rare, 4 Time, 4 damage, range 3, push 2) scores 3.51, below the common Crosswind (3.52): the weakest push card for its rarity. Push 3 is one option; score first. **No change (director, 2026-11-05):** 3.51 is above the rare median (3.12; p25 2.73, p75 4.07); rarity bands overlap (common p75 3.58, Threaded Path 3.99). Scored options for later: push 3 -> 4.22, damage 5 -> 3.98, Time 3 -> 3.96, range 4 -> 3.85.
- Updraft and Crosswind show a sword "Melee" icon and pop-up on cards that hit at range 3 to 4; "Melee" beside "Range 4" reads as a contradiction. **Fixed (checked 2026-11-05):** Updraft, Crosswind and Razor Gale show the Ranged icon and tooltip.
- Old Updraft numbers remain in `spec/card_targeting.md` (generated from an audit fixture) and the historical `spec/card_pool_overhaul/` proposals.
- Tooling: `tooltip_consistency_suite.gd` (2 Petrify focus-stack checks), `card_summary_fit_test` and `card_summary_fit_unit_test` fail on the base. pol-42's hover/aim/play probe (CLIP_HOVER, CLIP_AIM, CLIP_CLEAR) is in `output/polish/pol-42/clip_tool/`.
- After pol-38..40 merge, pol-43's pointer re-check stands aside while the hand's close slide runs and re-checks when it rests, so a plain play under a resting pointer lifts its card when the slide ends. Verify after those merges.
- A layout that still moves a few frames after it first draws (late width fit) is re-checked only at the old 4-frame point.
- After a deselect, the keyword box shows at once (a deselect counts as a discrete action under perf-13).
- Tooling: pol-43's probe logs after each draw, counts ticks from the sound bank, and logs the card Godot sees under the pointer; `hovlog.py` summarises. In `output/polish/pol-43/clip_tool/`. Headless tests can park a real pointer with `Input.parse_input_event` in screen coordinates.
- In real play, after the reward screen closes, the take's green line crosses the empty board for about 0.45 s (card to Character button). Intended; a question on pol-45.
- Tooling: probes that take a reward with `_on_reward_card_pressed(card_id)` and no card skip the whole take (no flair, label or line); pass the card or click it (pol-44's probe clicks, in `output/polish/pol-44/clip_tool/`). A probe that adds RunScene directly on the laptop screen records a 1920x1189 canvas that cuts off the top bar; booting through Continue gives a correct frame.
- Tooling: `tests/sfx_bank_test.gd` fails on the base (its copy of PostCombatRewardSequence fails to parse, then `play_victory` on Nil), so its accepted-reward cue check never runs. On seed 83's first combat room `real_fight_capture_probe` exits rc 1 on "Actor rest draw rect contains floor tile centre: enemy_2".
- When the taken reward card ghosts to 18%, the board shows through; after pol-45's lift the ghost's edge shows below the popped card. The reward screen has no scrim behind its cards.
- The take label sits where the player clicked, so the pointer covers part of it. Its fade outlasts the take, so it leaves at 67% opacity on the frame the screen closes (reads fine today).
- Tooling: pol-45's probe logs the take proxy's centre and scale, the label's box, its gap to the title and title visibility per frame; align before/after clips on the reward screen's closing frame (`align.py`). In `output/polish/pol-45/clip_tool/`.
- Under controller focus a card's keyword box appears at the start of its lift (no 2-frame rest) and travels about 20 px right and 50 px up as the card rises; pointer hover shows it nearly settled. The two paths feel different. **Already fixed on release (ui-16 traces, 2026-11-05).**
- Tooling: a fresh polish worktree has no class cache; `cp -cR` of integration's .godot then a headless `--import` takes about 70 s. pol-46's box/side/overlap logger (`tipcheck.py`) is in `output/polish/pol-46/clip_tool/`.
- With a controller, focusing Succumb to the Darkness turns its red plate bronze-brown, so the danger colour disappears just before the press (before and after pol-47). **In ui-15.**
- Camp with mouse and keyboard: arrows and Tab do nothing until something has focus; if a HUD control kept focus, the arrows walk the dimmed HUD behind the menu (DETAILS, the draw pile) and Enter can activate it. **In ui-15.**
- Run-end recap: the feat diamond (12 px) and NEW BEST (13 px) are under the 14 px caption floor. Camp says "Camp" in title case while the Settings panel it opens says "SETTINGS". **In ui-15.**
- Tooling: `pause_overlay_probe`, `utility_ui_layout_probe`, `selective_ui_salvage_probe`, `contextual_combat_tutorial_probe` fail on the base on unrelated stale checks, so they can't gate camp/pause UI. pol-47's camp walk-through tools (CAMP_MOVIE=1, CAMP_DESKTOP=1) are in `output/polish/pol-47/clip_tool/`.
- At pol-45-r2's size the ring's rune ticks (5-6 px) nearly vanish on a 690 px ring, and its bright inner arc, not the outer ring, is the most visible part. Keeping the inner arc outside the card would frame it more cleanly (a question on pol-45-r2).
- At turn start, Pass and the counters vanish for about 3 frames (50 ms) as the cards land, then reappear in their new place (pol-43-fix strip, before and after). **In ui-15.**
- Untested gap: after a deferred hover check, the slide's rest relies on Godot noticing a different card under the pointer. If the same card was under it at landing and at rest, it would stay down until the pointer moves. Never reproduced; a one-line fix would have the slide's rest call pol-43's resolve helper.
- Tooling: the movie writer's frame index can be off from the logged frame (31 frames in pol-43-fix's play clip); match clips by motion.
