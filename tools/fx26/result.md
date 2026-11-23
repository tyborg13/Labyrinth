# fx-26 baked area shots and Lightning hops

Worktree `codex/fx-26` is based on `092385347`. The implementation is uncommitted.

1. Ranged areas use the existing shot mapping, including card and intent overrides. RunScene supplies the resolved base card or enemy descriptor. Flight uses the fx-23 action clock and ends at the aimed tile centre. Rock uses its authored arc. Ice and Air stop submitting `ElementalSpellFx.travel` and their releases. Earth stops submitting its ground-spike path and release. The generic area fallback also yields when a shot is selected. The Shadow witness gains Shade. It had no flight at this base.
2. Each timed Lightning hop uses Spark at its existing flight height, from the resolver's source tile to its next target. The opening caster shot uses the existing fx-23 path. The old hop painter also drew dissipating contact rings at the endpoint. The same painter no longer submits for these hops. The base cases scheduled zero baked hop arrivals. The new fx-12 Lightning pair submits once at each visible hop contact. Fully blocked damage spends Block and selects `hit`. An empty conductive relay selects `floor`. The fx-24 reservation gives an existing tile burst first claim if it overlaps a hop.
3. The remaining procedural paths and their triggers are listed below.
4. The real resolver outcomes, authored beat lengths and observed contact frames match the base. The fx-14 visibility mask clips the hidden hop to `[0.0, 0.234375]` of its original line. The hidden actor and target burst are absent in the after take. Reduced motion suppresses flight while preserving visible contact rows.

## Before and after

The authored column gives contact frame over beat length. The contact and shot columns are zero-based 60 Hz samples from the start of each take. Grouped rows share those frame counts. The per-frame logs contain the separate hit and empty cases, draw flags, exact timings, and burst rows by tile. [Headless takes](/private/tmp/labyrinth_codex/fx-26/headless) · [Dry-run log](/private/tmp/labyrinth_codex/fx-26/dry-run.log)

| Resolver case | Authored contact / length | Contact sample | Baked flight samples before → after | Legacy submission before → after | Arrival |
| --- | ---: | ---: | --- | --- | --- |
| Rime Shard, hit and empty | 14 / 42 | 13 | — → Lance 3–12 | Release and Ice travel → — | Same two Ice pairs |
| Squall Shot, hit and empty | 12 / 38 | 10 | — → Blade 3–9 | Release and Air travel → — | Same five Air pairs |
| Grave Dust Satchel, hit and empty | 16 / 44 | 15 | — → Rock 3–14 | Release and ground spikes → — | Same five Earth pairs |
| Shadow resolver witness, hit and empty | 3 / 6 | 5 | — → Shade 3–4 | — | Same base arrival, zero tile pairs |
| Cinder Bloom, hit and empty | 12 / 48 | 10 | Ember 3–9 → same | — | Same five Fire pairs |
| Volt Surge, hit and empty | 8 / 30 | 5 | Spark 3–4 → same | — | Same three Lightning pairs |
| Nail Bomb, hit and empty | 3 / 6 | 5 | — → Pale 3–4 | — | Same five Shrapnel pairs |
| Craghide Groundsplit | 14 / 36 | 17 | — → Pale 8–16 | — | Same 12 Steel pairs |
| Chain Bolt, three targets | 8 / 30, 6 / 12, 6 / 12 | 5, 31, 48 | Spark 3–4 → Spark 3–4, 25–30, 42–47 | Two hop arcs and their contact rings → — | Opening contact preserved. Hit at (5,2) and (7,2) |
| Chain Bolt, hidden last target | 8 / 30, 6 / 12, 6 / 12 | 5, 31, 48 | Spark 3–4 → Spark 3–4, 25–30, clipped 42–47 | Two hop arcs → — | Hit at (5,2) only |
| Chain Bolt, reduced motion | 1 / 1 each | 0, 8, 16 | — | Two static hop arcs → — | Hit stills at (5,2) and (7,2) |
| Chain Bolt, empty floor relay | 8 / 30, 6 / 12 each | 5, 31, 45, 56 | Spark 3–4 → Spark 3–4, 25–30, 42–44, 50–55 | Three hop arcs → — | Hit, floor, hit at (5,2), (6,2), (7,1) |
| Rime Shard, reduced motion | 1 / 1 | 0 | — | — | Same Ice stills |

The base roster's ranged Shadow areas belong to Noctyrax. The Shadow witness uses a fixture-local element on Rime Shard's existing shape, resolved through the normal attack engine. For the hidden-hop witness, the resolver first selects the real route while the board is clear. A playback-only Eclipse mask then hides the last target, since the live resolver filters hidden targets out of its normal candidate list.

## Remaining procedural paths

| Trigger | Painter |
| --- | --- |
| Slag Mortar marked `lob_land` | `LobView.draw_effect` plots the rig-owned Fire lob through `ElementalSpellFx.travel`. |
| Dragon profiles that still use legacy spell travel | The Noctyrax breather branches retain the Shadow stream, including Night Coil and Starless Breath. The board still has the `noctyrax_breath` projectile fallback. The shared dragon painter retains unbaked breath and meteor fallbacks, including the Ember-shaped meteor when the scheduled fall does not own it. |
| `lightning_strikes` and other sky-strike fallbacks | The existing sky-strike cue owns the mapped falls. The board still delegates unmapped fall geometry to the dragon painter. |
| A subsequent electrical beat with a grounded conduction path, or a grouped same-tile discharge | Conductive paths use the floor-line painter. Same-tile branches without a path still use the old localized electrical discharge. |
| Electrical trace marks a range-relay delivery or Refraction beam | The trace marks the beat `ranged` with `chain_index`. It can reach the original elemental or generic projectile painter. |
| Explicit empty shot mapping or other excluded ranged descriptor reaches the legacy projectile path | Root Snare and Briar Weaver’s Lash of Thorns retain their Earth path. The explicit empty Executioner’s Fall mapping, excluded Fire and Lightning force descriptors, and any other unmapped descriptors still use the relevant generic or elemental fallback when that path is invoked. In Umbra the fallback is the clipped procedural fragment. |
| A lone Shadow projectile reflects off Glacial Mirror | `ReflectView` moves the existing Shadow sprite along the legacy Bézier outbound and return path. |
| Hoarfrost Seer wind and protected preview paths | `wind_push` keeps its custom line effect. Preview ribbons, projected cast paths and the elemental preview variants keep their current painters. |

## Verification

| Check | Observed result |
| --- | --- |
| fx-26 before and after dry run | `FX-26 VERIFY: PASS (315 checks, 0 failures)`. [Dry-run log](/private/tmp/labyrinth_codex/fx-26/dry-run.log) |
| fx-14 inventory and affected suites | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1991 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-26/fx14.log) |
| Original fx-23 verifier | Its staging could not load the historical board. It referenced absent Veilbound and Bile Bloomer scripts and painter methods removed since its base. Its selection assertions for procedural Ice, Air and Earth also reported the expected change. [Log](/private/tmp/labyrinth_codex/fx-26/fx23.log) |
| fx-23 after-side cases | `FX-23 AFTER-ONLY VERIFY: PASS (64 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-26/fx23-after.log) |
| Python default group | `Ran 194 tests in 38.686s` · `FAILED (failures=2)`. [Log](/private/tmp/labyrinth_codex/fx-26/python-default.log) · [Summary](/private/tmp/labyrinth_codex/fx-26/python-default/summary.json) |
| Rules text | `Ran 3 tests in 0.052s` · `OK` · `PASS: Rules text lint (16 existing hits)`. [Log](/private/tmp/labyrinth_codex/fx-26/rules-text.log) |
| UI identity | `Ran 25 tests in 6.433s` · `OK`. [Log](/private/tmp/labyrinth_codex/fx-26/ui-identity.log) |
| GDScript parse | Exit 0 for all three production scripts and four fx-26 probe scripts through the task runner. |
| Shell syntax, Python syntax, capture contract JSON and diff whitespace | Exit 0. |

The Python failures are the same two reported at the fx-24 base. The approved-content inventory expects `assets/art/effects/defense_heal_casts.png`. The tracked-sidecar guard expects `tools/flt01/fight_probe.gd.uid` and `tools/flt01/renderer_check.gd.uid`. Godot printed the macOS system-certificate startup warning in each headless run.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-26 && /private/tmp/labyrinth_codex/fx-26/native.sh
```

The launcher stages the base by object ID. It uses the native visual probe runner and an exact 1920×1080 SubViewport with cel look, HUD and 100% UI scale. Each 640×480 crop is sampled at release, 33% and 66% of flight, contact, contact +100 ms and contact +233 ms. The Chain Bolt strip repeats the six columns on separate rows for the opening and both hops. Outputs are planned at `/private/tmp/labyrinth_codex/fx-26/native/{before,after}/<case>/`, including `strip.png`, `native-evidence.png`, `take.json` and `manifest.json`. The five-second, 60 fps, silent reel plays Chain Bolt then Rime Shard in one RunScene fight. Its planned path is `/private/tmp/labyrinth_codex/fx-26/native/chain-ice.mp4`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-26 && /private/tmp/labyrinth_codex/fx-26/native.sh --dry-run
```

## TODO_DESIGN

None added.

## Chosen defaults

The fixtures inherit seed 7262026, Hero at (4,4), aim (4,2), 30 starting Health, 20 Block for the fully blocked target, and a 60 Hz clock. Other chain targets are at (5,2) and (7,2). The relay uses Electrified at (6,2) and moves the last witness to (7,1). The empty-area witness is parked at (7,6). Groundsplit has a 3-Health Craghide-owned outcrop at (4,3). The fixture flattens its test patch to stone. The hidden witness uses two radius-zero light sources to keep the first two targets visible under Eclipse. Crops centre on the source-to-target midpoint for each beat and clamp to the framebuffer. The reel is 300 frames. Native probe timeout is 300 seconds, as in fx-23.

## Open issues

The native strips, reel and renderer inspection require the design owner's window server. The dry runs verified the capture schedule and draw submissions. No native images or video were produced in this sandbox.
