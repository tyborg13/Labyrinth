# sfx-06 cue audit

## Electrical cues

Durations are decoded file durations at nominal pitch. Cue paths are relative to
`assets/audio/sfx/`. The cue bank and all four import settings are one-shot.

| Cue | File | Before → after | Trigger and retrigger |
| --- | --- | --- | --- |
| `spell.lightning` | `cues/spell.lightning/spell.lightning_01.ogg` | 1.800 → 0.550 s | On elemental contact, with same-cue contacts collapsed per frame; may repeat on later contacts or hops |
| `spell.lightning` fallback and legacy alias | `elemental/lightning_attack.wav` | 1.000 → 0.550 s | Same cue routing; fallback plays when the primary is unavailable |
| `status.shock` | `cues/status.shock/status.shock_01.ogg` | 1.200 → 0.320 s | One request per actor whose Shock value increases, with bank cooldown; no per-tile playback |
| `surface.electric` | `cues/surface.electric/surface.electric_01.ogg` | 1.200 → 0.400 s | One request per presentation batch containing Electrified creation or replacement; batches are deduplicated by surface kind |

No additional electric asset exceeded 0.600 s. The only looping combat beds
in the registry are biome ambience, which has no electric activation or tile
trigger. The authored level reductions lower Shock from −4.9 to −6.9 dB and
Electrified creation from −6.0 to −9.0 dB. Lightning remains at −6.3 dB.

| Scenario | Direct SFX and ordinary conditional layers |
| --- | --- |
| Lightning Wisp | **Static Lash** uses `spell.lightning` for contact and `surface.electric` when its trailing action creates/replaces ground. **Capacitor Arc** uses `spell.lightning` and can apply `status.shock` to a target reached with Electrified assistance. **Spark Dart** is a neutral melee action with `swing.heavy` and `hit.blunt.light`. Movement can request `step.enemy.light` per presented step in any of these intents. Contact replacement and damage layers are listed below. |
| Shock applied | `status.shock` when the presented value rises. The triggering attack or rider owns its own contact and outcome cues. |
| Electrified ground damage | Entry and turn start have no damage or Shock rider in this release. When Lightning conducts through the connected ground, the initiating action supplies `spell.lightning` and may supply `status.shock` through an applicable rider. Conducting through or removing a tile does not play `surface.electric`. Breaking Wheel can cause Shock as part of a force collision, with the ordinary collision and relic cues. |
| Zekarion's Skybreak | `dragon.roar` on the area cast, `spell.lightning` on the strike, and `surface.electric` when the strikes create/replace ground. Targets on the same presentation frame share an identical impact cue. |
| Lightning Storm battlefield rule | The rule stages primary bolts together, then any resolved actor hops. It has no dedicated audio call or surface creation. Its board snapshots pass through the normal router and can use the previous action's impact mapping for losses, including `spell.lightning` when that context is Lightning. The rule itself adds no Shock. |
| Discharge card | `spell.lightning` for presented damage; same-frame victims share the cue. Removing the network adds no cue. The card adds no Shock; ordinary input and outcome cues can accompany it. |
| Storm Capacitor's Arc Burst | Both render paths call the legacy lightning alias once per resolved hop, including the first. It resolves to `spell.lightning`. Damage snapshots also go through the normal contact router and can request the same cue or an ordinary damage layer; Arc Burst itself adds no Shock or ground. |
| Other chain hops | `spell.lightning` for each damaging hop through the normal contact router, at −5 dB after the initial beat. Contiguous conduction victims share a beat. An empty relay has no damaging contact, and a ground creation sounds only if that beat creates/replaces ground. Shock and other status riders depend on the initiating action. |

The following one-shot files can accompany the action when the relevant
condition occurs. The Ogg files use `cues/<cue>/<filename>`; WAV paths below
are relative to `assets/audio/sfx/`. Ambient loops and unrelated activity from
the rest of the turn are outside the action cue audit.

| Cue | File and duration | Condition and retrigger |
| --- | --- | --- |
| `step.enemy.light` | `step.enemy.light_01.ogg` 0.290 s | Wisp movement; requests per visible step/tile |
| `swing.heavy` | `swing.heavy_01.ogg` 0.828 s | Spark Dart wind-up, once per swing |
| `hit.blunt.light` | `hit.blunt.light_01.ogg` 0.364 s; fallback `attack_melee_sword_first.wav` 0.680 s | Neutral Wisp melee contact, per damage beat |
| `dragon.roar` | `dragon.roar_01.ogg` 2.338 s | Skybreak cast, once per area attack subject to cooldown |
| `hit.blocked` | `hit.blocked_01.ogg` 0.497 s; fallback `action_block.wav` 0.500 s | Fully absorbed contact replaces the normal impact; per damage beat, identical contacts merged on the same frame |
| `status.shatter` | `status.shatter_01.ogg` 1.200 s | Frozen target takes damage; replaces the normal impact with same-frame merging |
| `block.break` | `block.break_01.ogg` 0.716 s | HP damage removes the last Block; per affected unit and cooldown |
| `hurt.hero` | `hurt.hero_01.ogg` 0.148 s | Hero loses at least 5 HP in a hit; per qualifying hit and cooldown |
| `death.hero` / `defiance` | `death.hero_01.ogg` / `defiance_01.ogg`, both 2.500 s | Lethal hit or Defiance rescue; respective outcome beat |
| `push.slide` / `push.collision` | `push.slide_01.ogg` 0.500 s / `push.collision_01.ogg` 0.359 s | Forced movement or collision; per movement action or contact |
| `trap.trigger` | `trap.trigger_01.ogg` 0.590 s | If a qualifying trap fires, per trap instance; event surface sound goes through the surface batch rule |
| `relic.trigger` | `relic.trigger_01.ogg` 0.888 s | If an associated relic activates, per outcome batch and cooldown |
| `crate.hit` / `crate.break` | `crate.hit_01.ogg` 0.326 s / `crate.break_01.ogg` 0.890 s | A struck crate loses HP or breaks; requests per affected crate |
| `surface.fire`, `surface.ice`, `surface.rubble` | `surface.fire_01.ogg` 0.351 s, `surface.ice_01.ogg` 1.200 s, `surface.rubble_01.ogg` 1.200 s | If a secondary event creates another surface, per surface-kind batch; Fire can also sound on ground damage |
| `status.bleed` / `status.stagger` | `status.bleed_01.ogg` 0.200 s / `status.stagger_01.ogg` 0.946 s | An existing Bleed cost or a qualifying secondary Stagger rider; per affected actor |
| `card.select` | `card.select_01.ogg` 0.201 s | Discharge card input or returned plays; per input or earned play |

If a target dies, the existing router also uses its death family once per unit.
The variants are `death.spirit_01.ogg` (1.182 s), `death.beast_01.ogg`
(1.603 s), `death.humanoid_01.ogg` (0.671 s), `death.bone_01.ogg` (0.632 s),
`death.stone_01.ogg` (2.500 s), `death.ooze_01.ogg` (0.690 s),
`death.avian_01.ogg` / `_02.ogg` / `_03.ogg` (0.372 / 0.321 / 0.500 s),
and `death.dragon_01.ogg` (2.500 s). If “Skybreak” refers to the
player card **Skybreak Current**, its contact is `spell.air_01.ogg` (1.468 s;
fallback `elemental/air_attack.wav`, 2.000 s) plus any applicable push/collision
and outcome layers. All files in this paragraph are one-shots.

### Requests inside 150 ms

- **Lightning impact/hops, 40 ms cooldown, 3 voices.** Arc Burst spaces hops
  120 ms apart at base speed. The Lightning Storm adapter also uses 120 ms
  chain beats. Player chains can repeat on 120 ms relays, 100 ms reduced-motion
  beats, or faster scaled presentation. Requests from the regular impact
  router collapse on the same frame, and optional later-frame area layers
  bypass cooldown while retaining the voice cap. Arc Burst uses ordinary
  cooldown and can drop closely submitted hop requests.
- **Shock, 200 ms cooldown, 1 voice.** One action may increase Shock on
  multiple actors in the same submission or successive hops. The cooldown
  suppresses duplicate audible starts inside 150 ms.
- **Electrified creation, 150 ms cooldown, 2 voices.** Multiple painted tiles
  in one batch issue one request. Independent batches from one action can
  request it again inside 150 ms; ordinary cooldown suppresses that request.

Routing references: `scripts/sfx_cue_router.gd`, `scripts/sfx_bank.gd`,
`scripts/combat_engine.gd`, `scripts/chain_attack_feedback.gd`,
`scripts/battlefield_rules/{playback,hit_playback,lightning_storm}.gd`,
`scripts/enemy_mechanics/{capacitor,capacitor_view}.gd`, and
`assets/units/storm_capacitor_cutout/actions.gd`.
