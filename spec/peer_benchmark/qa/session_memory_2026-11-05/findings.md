# Ownership findings

## Protected asset-path cache: confirmed unbounded stale data

`AssetLoader.cache_texture_used_rect` and `texture_used_rect` store `Rect2i`
values in static `_texture_used_rect_cache`. `_texture_processing_cache_key`
uses `instance|<ObjectID>|<width>|<height>` for pathless resources and recursively
includes that identity in atlas keys. Freeing a transient texture cannot remove
that string/rectangle pair. A future texture has a different generation/ID, so
that entry is never reused. This is retained data growth, not retained texture
objects. `maquette_cutout_runtime/portrait.gd::source_texture` explicitly prewarms
bounds for atlases backed by renderer viewport textures; those identities change
with scene lifetime. The corrected session's key/ID census is the direct owner
check; `texture-bounds-repro.json` is an independent lifetime control.

The focused repro creates **empty engine texture resources**, without generating
or importing artwork, and releases all constructor temporaries in a separate call
frame. For both plain textures and atlases, 1/5/20 calls leave 1/5/20 cache entries
while every tested texture ID is already invalid. The result is
`QA53 TEXTURE BOUNDS REPRO: PASS`, exit 0. Earlier inline versions incorrectly
kept constructor temporaries in the active GDScript frame; their assertion logs
are retained and those runners were canceled with their session interrupt.

This unit leaves the asset preparation/loading path unchanged under the brief's
**“Hands off: perf-54's load path ... if a leak is there, report it with a repro”**
rule. Owner-lifetime storage for transient texture bounds, while keeping shared
bounds for stable source/atlas identities, is a root-cause direction for perf-54.
No cache cap, blanket clearing, visual value or source-loading behavior was changed.

## Resource/class warmup

In the first complete five-run series, menu resources were
`1462, 1467, 1467, 1467, 1467` and objects were
`10666, 10688, 10688, 10688, 10688`. Exactly seven native classes account for the
22-object first-death increment:

| Class | Run 1 menu | Runs 2–5 menus | Creator / retained owner |
|---|---:|---:|---|
| AudioStreamOggVorbis | 96 | 97 | Funeral-march death loop, loaded and retained by `AssetLoader._audio_cache` |
| OggPacketSequence | 96 | 97 | Packet data owned by that stream |
| CompressedTexture2D | 631 | 632 | `storm_capacitor.png`, retained by the texture cache |
| ImageTexture | 2063 | 2069 | Six first-use Storm Capacitor image sources, retained by `AssetLoader._texture_cache` |
| Image | 2944 | 2953 | Source/dummy-renderer image storage accompanying those textures; native storage is not a script reference graph |
| GDScript | 665 | 667 | Storm Capacitor `rig.gd` and `renderer.gd`, retained by the loaded rig/resource machinery |
| WeakRef | 74 | 76 | Rig source-path registry (`maquette_cutout_runtime/construction.gd`, `RigData._sources`); existing path entries are replaced, not appended per run |

The six new texture keys are the approved enemy portrait, front/rest, rear/rest,
paint/cap, paint/column and paint/column_glow_0 assets. These are first-use warmup;
all seven class counts plateau on runs 2–5. No linear live-object population was
observed in this five-run workload. This does not establish a bound for every
possible asset/loadout in the game.

The initial menu has 279 nodes. Later menus have 280: the sole added node path is
`/root/CursorFeedback/UiFocusPlayer`, a retained, lazily created audio player.
There is no further menu-node growth.

## Intentional caches and saved bookkeeping

The victory recap's 19 orphan nodes are all exact members of live cards'
`card_summary_layout` caches. The inherited qa-46 ownership guard has zero errors;
every card stays within its four-layout limit. Every return-to-menu sample has
zero orphans. Intentional summary layouts and retained batches are unchanged.
The inherited hunt's section-0-to-5 node warning is a within-run, cold-to-populated
comparison; it is retained in the raw findings and is not a cross-run leak verdict.

Chronicle terminal snapshots/visible records have a source limit of 50.
`ProgressionStore.record_chronicle` retains completed IDs for durable deduplication;
`completed_run_results` is a separate award receipt ledger. After five runs both
receipt lists and the Chronicle records have five entries. These are saved,
reachable bookkeeping, not unreachable scene objects. Their persistent growth
must not be “fixed” by dropping save/analytics deduplication state.

## Observer memory and validity

The first observer kept all prior boundary metadata dictionaries in its own
`boundaries` array. Serialized metadata reached about 2.8 MB; its in-memory
Variant/string/dictionary representation is larger. Its approximately 3.7 MB per
repeated death-run static-memory slope therefore cannot be attributed directly
to the game. The corrected observer stores full boundary reports on disk and
retains only labels between samples. Both versions take the monitor sample before
building the current object report. No Node/Object reference is kept in a report.

The first observer also tested `value is Object` on freed values in retired
bookkeeping slots. Godot reported 59 observer-only script errors and the task
runner correctly returned 1 despite five completed runs. Native class census
counts still equal the pre-census object monitor plus the two bridge objects at
all eleven boundaries, but the first ownership-reference graph is partial. The
correction checks `typeof(value) == TYPE_OBJECT` before testing instance validity.
Original logs and v1 sources remain retained. A fresh, error-free replay is
required for valid after-proof (the corrected result below supplies it); the first `QA53 SESSION: PASS` is a coverage line, not a
passing runner result.

## Exit warning control

The first complete series emits no `ObjectDB instances leaked at exit` and no
`resources still in use at exit`. Its remaining verbose warning is exactly
`Orphan StringName: BAYER (static: 0, total: 2)`.

A four-case headless control isolates that identifier:

| Control | Exit | BAYER references remaining |
|---|---:|---:|
| Empty engine/tree | 0 | 0 |
| Quantize shader + uniform-list query | 0 | 1 |
| Lines shader + uniform-list query | 0 | 1 |
| Both shaders + uniform-list queries | 0 | 2 |

See `shader-exit-repro.json`. Each helper releases its shader/material call frame
before shutdown. Both shader sources declare a `BAYER` constant. This isolates
an engine-side interned shader identifier warning; `StringName` is a value type,
not an ObjectDB scene/resource instance, and it is separate from stale
string/rectangle cache entries. The warning is retained, not hidden by renaming a
shader constant. The historical qa-45 seed-9 ObjectDB/resource warning remains
unattributed: this workload does not reproduce it, so no historical fix is claimed.

## Corrected five-run result

The fresh corrected series exits **0**:
`QA53 SESSION: PASS runs=5 boundaries=11 errors=[]`. It repeats exactly the same
victory/death sequence and decision totals, checks all five recaps visible, and
passes all eleven pre/post-census state/save/RNG/analytics nonmutation guards.
The native enumeration equals monitor + two bridge objects at every boundary.

The five settled menu populations are:

| Metric | Run 1 | Run 2 | Run 3 | Run 4 | Run 5 |
|---|---:|---:|---:|---:|---:|
| Static bytes | 1025212928 | 1027409172 | 1027414196 | 1027506596 | 1027538060 |
| Objects | 10675 | 10697 | 10697 | 10697 | 10697 |
| Nodes | 280 | 280 | 280 | 280 | 280 |
| Orphans | 0 | 0 | 0 | 0 | 0 |
| Resource monitor | 1462 | 1467 | 1467 | 1467 | 1467 |
| Bounds-cache entries | 158 | 162 | 165 | 168 | 171 |
| Bounds keys whose instance is dead | 37 | 40 | 43 | 46 | 49 |

From the first-death menu (run 2) through run 5, static memory increases only
**128,888 bytes** (0.123 MiB). The old observer increased **11,053,540 bytes** over
that interval. The corrected residual includes reachable bookkeeping/cache data;
**its exact allocation-by-allocation ownership is not established**. Do not call
all remaining memory bounded or subtract serialized JSON size as heap size.
Saved receipt lists and Chronicle snapshots grow; one AnalyticsStore per menu
also loads its idempotency index from the accumulating event file. The confirmed
unbounded dead-ID cache is separately measured by exact keys and the lifetime
control. No linear ObjectDB population is observed after warmup.

Each repeated death contributes two `atlas|instance|...` keys and one plain
`instance|...|256|383` key. The plain key's texture is present at the death recap,
referenced by `CombatBoard._door_opening_frames[0]` and its retained layers; it is
absent from the next menu's complete ObjectDB census. Its creator is
`CombatBoardView._load_door_opening_frames`, which creates owned frame textures
from the approved door-opening sheet. The two atlas keys match the viewport-backed
portrait path described above. All 49 audited dead-ID keys at the fifth menu
survive after their texture identities disappear. This is the concrete perf-54
asset-load/preparation repro, not a reason to alter the intentional retained layers.

Absolute presentation-cache populations vary between processes: the corrected
menus have eight more StyleBoxFlat objects and one more Image than the first
series. Those offsets are already present at run 1 and stay flat across all five
menus. The victory recap has 27 bounded summary-layout orphan nodes rather than
19; every member is still attributed and every menu still clears to zero.

## Equality proof and strict limitation

`semantic-integrity.json` records **PASS** for all 2,733 actions (only generated
Godot node ordinals normalized), all 2,733 recorded policy RNG states, all eleven
saved-run boundary hashes, final profile data and all **7,789 analytics records**.
Transport-ID normalization is bijective and preserves distinct run relationships.
Clock fields and one precisely derived field are excluded: the Swift feat's
“Escaped in 20 minutes” versus “Escaped in 21 minutes”. Both award the same Swift
feat and 50 points. The Chronicle stores the same detail under `title: Swift`.
The producer is `run_score_rules.gd:128`; the Chronicle projection is at
`chronicle_rules.gd:75–77`. Every other final profile/analytics field agrees.

The raw strict comparison remains **FAIL** in `strict-integrity-comparison.json`.
The initial menu samples precede seeding the diagnostic policy RNG, and its two
unseeded values differ. The first **2,595 committed-state hashes match exactly**
(the entire six-dragon victory); the remaining 138 post-win hashes differ after
carrying the clock-derived feat detail in progression. Full transient states were
not dumped, so those 138 hashes are **not** recomputed or claimed equal. No game
source changed. This explicit clock/transport audit supplements the strict report;
it does not rewrite it into a strict success.

The corrected shutdown again has only the isolated two-reference BAYER StringName
warning. There are no ObjectDB/resource-in-use exit warnings or script errors.
The interrupted earlier replay (decision 470) encountered filesystem exhaustion
and failed a checkpoint/runner output write; its exit 120 and raw log are retained
and excluded from after-proof. Reclaiming 2.2 GB of this worktree's generated
experiment/report image import cache allowed a fresh replay. No source, sidecar,
production asset, other worktree or Git metadata was removed.
