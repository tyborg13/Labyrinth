# Audio

## Audio mix notes

- A gentle SFX glue compressor (threshold −16 dB, 2.5:1, no makeup gain) and a
  Master hard limiter (−0.8 dB ceiling) keep stacked impacts from clipping
  (`SettingsStore`). The compressor only acts on the loudest peaks.
- Short one-shots (≤1.25 s) receive a small random pitch drift (±3.5 %); UI
  hover/click ticks drift ±3–4.5 %. Stingers keep their authored pitch.
- New cues are derived from shipped recordings by `tools/generate_ui_cue_sfx.py`:
  menu page open/close, and a barely-there stone-hall room tone (the campfire
  loop's low body only, slowed and low-passed, no crackle; playback −20 dB,
  about −50 dBFS RMS effective)
  for room, combat, pre-battle, reward, treasure and event modes. Pressing Pass
  plays only the shared button click; card sounds are reserved for cards.
- Preserved owner-auditioned decisions: card draw (0 dB, ~9–11 dB under
  impacts), reward-card flip (no gain boost), door −10 dB, victory −7 dB,
  accepted reward −12 dB, hover tick −17 dB, the 8 %/4 % reverbs, and the
  no-overlap music transition.
- **Changed:** `card_play_take.wav` (+13 dB then limited; it measured ~−37 dB
  RMS and was nearly inaudible — owner approved the louder play after testing), `item_equip.wav`
  (+6 dB then limited, playback −1 dB), relic-choices-open playback −2.5 dB,
  and combat hit playback levels (melee −5.5, ranged −1, block −4.5, fire −6.5,
  earth −3.5, air 0, lightning −3, ice 0 dB; previously −4/−2/−3/−3/−2/−2/−2/−2)
  to even out their measured loudness.


## Buses and playback

`World` in the director data maps to `SettingsStore.WORLD_SFX_BUS` (room reverb);
`UI` maps to `SettingsStore.UI_SFX_BUS` (dry). Both feed the existing SFX parent,
including player volume, global headroom, glue compressor, and Master limiter.
Music, its duck stage, reverb, and non-overlapping transitions are unchanged.

`SfxBank` reads `data/sfx_cues.json` without modifying it. It preloads streams,
allocates each cue's voice pool, and rotates variants in order from a random
starting index. Tests seed a separate RNG for each cue; runtime presentation RNG
never consumes combat RNG. Volume, uniform fractional pitch jitter, cooldown,
voice stealing (oldest first), bus, and loop come from each cue's own entry.
`gain_db` is additive. Silent requests are counted, including cues awaiting assets.
`variants_from` resolves the source's variants/fallback while keeping the receiving
cue's controls; its pitch multiplier is applied before jitter. Stingers remain at
pitch 1 and retain the existing music-duck guard.

Empty `variants` uses `fallback`. Fallback paths that already shipped preserve
exactly the playback levels in the mix notes above; authored variants use the
new cue's `volume_db`. This compatibility adjustment is code-owned and never
rewrites director data. Existing `attack.*`, `action.block`, and hall ambience ids
remain aliases; run, draw/play/flip, reward, equipment and Hearth ids retain their
existing paths and levels. New loop beds change through two pooled voices with a
0.6-second amplitude crossfade; sections choose their `boss_id` biome and legacy
runs choose stone. Campfire keeps its existing fire bed. Other modes fade beds out.

## Routing and timing

The scene passes accepted action context to `SfxCueRouter`. The board exposes a
presentation-snapshot signal; the scene emits it only for committed animation
submissions, so hovering previews does not play damage sounds. The router compares
presented HP, Block, Stoneskin and status snapshots at the existing contact
boundary. Neutral casts and physical shots wait through the existing preparation
and fire at the authored effect-release sample, before contact. Walk cues occur at each authored segment's tile arrival. Death cues
occur when death-animation units enter presentation, before the hero overlay.
The router does not change gameplay, saves, analytics, or input behavior.

Weapon cards resolve the equipment that supplies that card (weapon/offhand),
while magic and weaponless cards use their action type. Physical facing areas are
melee. Push/pull/charge use blunt. Weaponless neutral spells use arcane; elements
replace the physical impact. Unknown future weapons/enemies return
`TODO_DESIGN_WEAPON_FAMILY` / `TODO_DESIGN_ENEMY_FAMILY` rather than choosing a sound.

| Weapon family | Weapons |
| --- | --- |
| blade | sword, dagger/knife, rapier, axe/hatchet, halberd, scythe, glass spear edge |
| blunt | mace, maul, hammer, club, flail, shield bash, staff |
| pierce | spear, lance, bow, crossbow/repeater, sling projectiles |

These tables derive physical contacts from the production cutouts (Harrier spear,
Lancer spear, Surgeon saw, Gaoler chain hook, Reaver blade, guardian staffs/forks,
stone fists and creature claws/teeth). An elemental action overrides the table;
Acolyte/Veilbound neutral ranged bolts use arcane rather than their melee family.
Shale Bloomer is the current `bile_bloomer` id and has the director's stone death.

| Enemy id | Physical contact | Death family |
| --- | --- | --- |
| crawler | claw | beast |
| acolyte | blunt | humanoid |
| harrier | pierce | bone |
| warden | blunt | stone |
| cinder_ooze | blunt | ooze |
| cinder_droplet | blunt | ooze |
| bile_bloomer | blunt | stone |
| chainbound_gaoler | blunt | humanoid |
| grave_surgeon | blade | humanoid |
| frostglass_lancer | pierce | humanoid |
| veilbound_acolyte | blunt | spirit |
| lightning_wisp | blunt | spirit |
| ashen_reaver | blade | humanoid |
| rimejaw | claw | beast |
| storm_cantor | pierce | humanoid |
| gallows_roc | claw | avian |
| craghide | claw | stone |
| last_lamplighter | blunt | humanoid |
| ash_hound | claw | beast |
| rime_whelp | claw | beast |
| rime_spitter | claw | beast |
| bell_tender | pierce | humanoid |
| roc_fledgling | claw | avian |
| stoneback_mite | claw | beast |
| wick_shade | claw | spirit |
| tharokh | claw | dragon |
| vyraketh | claw | dragon |
| vaeloryx | claw | dragon |
| iskaldra | claw | dragon |
| noctyrax | claw | dragon |
| zekarion | claw | dragon |

## Rules

- One damaging hit requests one impact. Fully absorbed hits replace it with
  `hit.blocked`; frozen triple hits replace it with `status.shatter`; forced
  collision damage replaces it with `push.collision`. Hero loss of at least 5 HP
  adds the one body layer `hurt.hero`. Last Block lost with HP loss adds
  `block.break` as the explicit director-authored exception.
- Repeated contact notifications for one target in the same action merge inside
  the data's 60 ms window. Area actions request one full impact and at most two
  extra impacts at −6 dB after 35/70 ms. Those authorized area instances bypass
  cue cooldown (some elemental cooldowns exceed 35 ms). Chain-hop contact instead
  uses its shown lightning element at −5 dB, at that hop's contact time.
- Beast/avian wind-up vocals use a deterministic presentation seed per action
  with a 30% branch; the bank enforces the authored 900 ms cooldown. Dragon first
  action requests a roar once per fight. Big area roar requests occur at
  resolution per the brief (the protected data's wording says start; the brief
  takes precedence); the data's 4000 ms cooldown still applies. Dragon travel
  requests wings alongside each large-enemy tile arrival.
- Trap spring precedes its element impact. Created surfaces use the separate
  `surface.*` cues, without stacking a second spell on the attack contact.
- Expose is deliberately removed. Its card/intent provides the signal. Pass
  continues to produce only the shared click. Card cues apply only to cards.

## Adding variants and proof

The design owner fills a cue's `variants` with approved `res://` audio paths after
an audition. This unit supplies no audio files. Keep `fallback` for compatibility;
remove it only as a separate owner decision. Inherited cues need no duplicate
assets. Keep authored loops loopable and specify `loop: true`; stingers must keep
zero pitch jitter. Do not change protected mix values while wiring new paths.

The bank suite covers seeded round-robin, jitter, cooldown boundaries, oldest
voice stealing, fallback levels, silence, inherited variants, crossfade and buses.
The headless coverage probe drives ordered representative states and prints every
cue's request and effective variant/fallback/silent status, plus removed entries.
Its optional `--visual` mode is a 1920×1080, 100% UI-scale real-renderer handoff.
Existing UI hover, feedback and run probes remain the owner audition surfaces.

## Integration limits for the design owner

Galewhip is a lash in the production rig; the brief supplies no whip impact
family. `TODO_DESIGN_GALEWHIP_IMPACT_FAMILY` stays silent. The generic future
weapon/enemy family placeholders are also silent until a family is supplied.
Phoenix Brand's sword art uses blade; Worldbreaker and Dawnlight Censer's heavy
blunt implements use blunt. Unknown equipment does not inherit a default sword.

The owned-file boundary excludes `cursor_feedback.gd`, which currently has no
cue override/suppression hook. Map/event commitment requests are wired, but the
shared click still occurs before those requests. Suppressing that click requires
an adjacent hook; no cursor/input behavior is changed as a workaround.

Relic trigger detection uses existing explicit reward log records and
relic-owned resolved surface events. It never treats a threshold counter increment
as a fired effect. Relics that emit neither record need an engine presentation
event; a general relic HUD badge-pulse hook is absent and reserved as
`TODO_DESIGN_RELIC_BADGE_PULSE`. The coverage table proves
representative cue requests and the live probe proves selected scene hooks; it
is not a claim that these two adjacent integration limits have been resolved.

## Proof commands for the design owner

Run each command from this task worktree. The worker has no window-server access
and has not run these commands or claimed screenshots. The coverage contract
requires two meaningful 1920×1080 captures at 100% UI scale; the existing probes
preserve their established capture/input checks. The inspection fixture remains
owned by the design owner under the workflow split.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-01 && python3 tools/visual_probe_runner.py --task-id sfx-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/sfx_cue_coverage_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/sfx-01-coverage.json tests/sfx_cue_coverage_probe.gd -- --visual
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-01 && python3 tools/visual_probe_runner.py --task-id sfx-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tests/run_sfx_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-01 && python3 tools/visual_probe_runner.py --task-id sfx-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tests/ui_feedback_sfx_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-01 && python3 tools/visual_probe_runner.py --task-id sfx-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/ui_hover_sfx_probe_contract.json tests/ui_hover_sfx_probe.gd
```

Capture paths are `user://sfx_cue_coverage/1920x1080_ui100/01_melee_contact.png`
and `02_defense_result.png`; the headless table is
`user://sfx_cue_coverage/coverage.txt`. Each runner prints its isolated absolute
path. Existing probes print `user://run_sfx_probe_v1`,
`user://ui_feedback_sfx_probe/1920x1080_ui100`, and `user://ui_hover_sfx_v1`.

Implementation reserves: `SCHEDULE_CAPACITY = 64`, `LEGACY_WARM_VOICES = 8`.
Debug proof fields: `TEST_SEED = 410`, `TEST_START_MS = 10000`,
`TEST_REQUEST_GAP_MS = 5000`; synthetic fixture HP/tiles are test-only data.
Per-call legacy gain and trim remain honored even when two moments share a file.
