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
replace the physical impact. Unknown weapons and enemy attacks use blunt;
unknown deaths use humanoid. Debug builds warn once per unknown id/family;
release builds remain quiet.

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
| storm_cantor | blunt | humanoid |
| gallows_roc | claw | avian |
| craghide | claw | stone |
| last_lamplighter | blunt | humanoid |
| ash_hound | claw | beast |
| rime_whelp | claw | beast |
| rime_spitter | claw | beast |
| bell_tender | blunt | humanoid |
| roc_fledgling | claw | avian |
| stoneback_mite | claw | beast |
| wick_shade | claw | spirit |
| burrow_grub | claw | beast |
| ember_tick | claw | beast |
| hoarfrost_seer | blunt | humanoid |
| gale_herald | blunt | humanoid |
| arc_thrall | blunt | humanoid |
| gloam_stalker | blade | spirit |
| briar_weaver | claw | stone |
| slag_mortar | blunt | humanoid |
| glacial_mirror | blunt | stone |
| gust_shrike | claw | avian |
| storm_capacitor | blunt | stone |
| hollow_mimic | blade | spirit |
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
  the data's 60 ms window. Same-frame area contacts play one primary impact,
  with no stacked copies. Up to two later contact frames each request one
  additional impact at −6 dB on that frame, bypassing cue cooldown. There is
  no stagger queue. Chain-hop contact uses its shown lightning element at
  −5 dB, at that hop's contact time.
- Beast/avian wind-up vocals use a deterministic presentation seed per action
  with a 30% branch; the bank enforces the authored 900 ms cooldown. Dragon first
  action requests a roar once per fight. Big area roars align their RMS peak to the wind-up release;
  the per-call rule below handles each release duration. The data's 4000 ms
  cooldown still applies. Dragon travel requests wings on the first frame of
  each tile's movement segment; heavy footsteps remain at tile arrival.
- A trap spring uses only `trap.trigger`; it never adds an element spell impact.
  If the trap creates a surface, that creation uses the separate `surface.*` cue.
- Expose is deliberately removed. Its card/intent provides the signal. Pass
  continues to produce only the shared click. Card cues apply only to cards.

Sync policy lives in `data/sfx_cues.json` under `rules.sync`. The alignment peak is the earliest local maximum within 2 dB of the strongest centered 5 ms RMS peak. Lossless asset rebuilds move the cut back to an instantaneous max-channel amplitude at least 20 dB below that selected RMS peak, retain at least 15 ms before it, and apply a 3 ms linear fade. This quiet-point interpretation applies to asset trims; runtime head skips use the separate minimum-pre-peak and fade rule. Already-short source heads stay whole, and the tail stays complete. Restoration gain must obey the build's category/sample peak cap and −1 dBTP. The maximum 100 ms BS.1770 loudness (25 ms hop) may change by −1.0…+0.5 LU; any cap-limited exceptions are listed in the current audit.

Per-call alignment targets the observed climax +15 ms at the actual selected pitch. The submitted climax frame sets an absolute deadline in the presentation clock; due calls dispatch in that same process tick, even if the bank's process callback ran earlier. No future frame interval is predicted. On a late tick, the PCM head skip increases by the pitch-adjusted wall-time lateness, bounded by the minimum 15 ms before the peak, with a verified 3 ms fade and the whole tail preserved. Presentation deadlines freeze during pause and hit-stop. The onset cap starts at playback. Blink, relay, illusion swap, swap, cast.arcane and animated dragon roars use this rule at 1×, 1.5× and 2×. The same rule handles hit.blunt.heavy and illusion.spawn because their quiet asset cuts retain too much pre-peak time for an immediate contact. Cues opt into decoding at warm-up through `sync_warm_up`; immediate contact alignment uses `sync_contact_alignment`.

Same-frame impacts collapse only identical cues. A blocked and an unblocked contact both play; additional contacts keep the −6 dB layer and the existing three-contact action limit. First-action roars fall back to action start for hidden steps, special views and effects that lack a dragon profile. Meteor and utility releases are covered alongside breath and ground attacks.

The compact [sync baseline](peer_benchmark/staged/sfx/sync_baseline.json) binds sample measurements to hashes and keeps cue/call-site identities, separate request and successful-primary/optional-layer counts, explicit cooldown/optional-priority drops, silent visuals and area loudness. Counts are recorded for every speed and frame profile: fixed 60 Hz, periodic 33 ms spikes, steady 30 fps, 144 Hz and seeded ±4 ms jitter. All aligned rows must remain 0–30 ms after the observed climax, targeting +15 ±2 ms where frame timing allows; the current harness retains the stricter +15 ±1 ms assertion. Primary priority drops fail independently of request coverage; cooldown drops must prove a preceding success within the authored cooldown. Coverage identity is file + function + normalized statement, excluding neighboring lines. The [current audit](peer_benchmark/staged/sfx/sync_audit.md) holds the policy, results, complete re-trim list, listening checklist and exceptions. Full reports regenerate under gitignored `output/sfx/` with `tools/sfx_sync_audit.py --report`; `tools/sfx_lab/sync.py` rebuilds from compact per-path provenance and is idempotent. The full Godot suite includes the bank's forced-pitch, absolute-deadline, pause/hit-stop and decoded-length checks, plus all 15 production-harness combinations.

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

## Director decisions and shared feedback

Galewhip and Phoenix Brand use blade; Worldbreaker and Dawnlight Censer use blunt.
Section enemy families above include the director's parallel-unit assignments.
Bell Tender and Storm Cantor use blunt staff contacts; elements still override.

Hand cards and map nodes own their click and hover/focus sound through dedicated
cues. Event choices own their click while retaining the shared focus tick.
The router marks these controls; `CursorFeedback` suppresses the corresponding
shared pointer press, native confirmation and UI focus tick. Cursor motion,
drag thresholds, activation and navigation remain unchanged. Ordinary buttons
and Pass retain the shared click.

Relic trigger detection uses existing explicit reward log records and
relic-owned resolved surface events. It never treats a threshold counter increment
as a fired effect. Per the director, relics without explicit outcome records
remain quiet and no general badge-pulse hook is added.

The protected data currently contains 72 direct variant lists, two variant
aliases (Stoneskin and crossbow), six ambience aliases to `ambience.stone`,
and that one fallback-only stone bed. All sections retain the existing hall tone;
no biome bed assets are added. Coverage reports both effective playback and the
alias source, and fails if any active cue has no loaded stream.

## Proof commands for the design owner

Run each command from this task worktree. The worker has no window-server access
and has not run these commands or claimed screenshots. The coverage contract
requires two meaningful 1920×1080 captures at 100% UI scale; the existing probes
preserve their established capture/input checks. The inspection fixture remains
owned by the design owner under the workflow split.

```sh
cd "$TASK_WORKTREE" && python3 tools/visual_probe_runner.py --task-id sfx-01 --no-headless --display-driver macos --audio-driver CoreAudio --expect-size 1920x1080 --proof-contract tests/sfx_cue_coverage_probe_contract.json --result-manifest "$INSPECTION_MANIFESTS/sfx-01-coverage.json" tests/sfx_cue_coverage_probe.gd -- --visual
cd "$TASK_WORKTREE" && python3 tools/visual_probe_runner.py --task-id sfx-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tests/run_sfx_probe.gd
cd "$TASK_WORKTREE" && python3 tools/visual_probe_runner.py --task-id sfx-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tests/ui_feedback_sfx_probe.gd
cd "$TASK_WORKTREE" && python3 tools/visual_probe_runner.py --task-id sfx-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/ui_hover_sfx_probe_contract.json tests/ui_hover_sfx_probe.gd
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
