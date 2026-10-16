# int-01 — Route every presentation surface to the maquette rigs (merge follow-up: pb-01 × rr-04)

## Header
- pb-01 (pre-battle live actors) and rr-04 (Shale Bloomer + Lightning Wisp maquette rigs) were developed in parallel.
  Merge 58c58c9af kept pb-01's `LiveActor` in `scripts/pre_battle_view.gd` and dropped rr-04's
  `maquette_cutout_runtime/portrait.gd` bind there. `LiveActor.renderer_script()` → `ActorPresentation.travel_renderer()`
  still loads the OLD `scripts/bile_bloomer_cutout/renderer.gd` / `scripts/lightning_wisp_cutout/renderer.gd`, while the
  board uses `maquette_cutout_runtime/shale_bloomer_renderer.gd` / `lightning_wisp_renderer.gd`. Result: old art in the
  pre-battle, new rigs on the board.
- Base `codex/peer-benchmark` (HEAD after 58c58c9af). Owned: `scripts/actor_presentation.gd`, `scripts/live_actor_presentation.gd`,
  `scripts/maquette_cutout_runtime/**` (API adapters only), portraits/turn-order consumers of travel_renderer, tests.

## Change
1. One source of truth for "which renderer presents identity X" used by the board, pre-battle live actors, portraits,
   turn-order/inspection and any other consumer of `travel_renderer`: maquette identities (bile_bloomer, lightning_wisp,
   and future ones registered the same way) resolve to their maquette runtime renderer.
2. The maquette renderers support the LiveActor contract (`present`, `texture`, `snapshot`, idle phase seed,
   reduced-motion rest) exactly like the other renderers; deterministic phase per slot.
3. Remove the now-unused old bloomer/wisp cutout renderers ONLY if nothing references them (list what you removed);
   otherwise leave them and report the remaining references.
4. Tests: every surface resolves bloomer/wisp to the maquette scripts (fails on current HEAD); pb-01's renderer-identity
   and SceneTree motion tests include both; full suite PASS.

## Proof
- Headless tests + full suite. Windowed (director): the pb-01 living-foes probe with a pack containing both creatures.
