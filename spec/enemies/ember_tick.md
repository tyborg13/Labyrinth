# Ember Tick — EN01 implementation

Binding design: [director roster v1](../peer_benchmark/enemy_roster_v1.md),
protected `ember_tick` entry in `../peer_benchmark/staged/enemies/wave_e1.json`,
and the supplied EN01/shared brief plus director feedback 1. Staged light Cinder Crown enemy:
6 HP, initiative 8, 6 Embers. Compare Tunnel Crawler (14 HP, initiative 8,
8 Embers): Tick has a lighter body and kill-order/friendly-fire pressure.

4. Every tick death queues Burst exactly once. A shared FIFO finishes all
   occupants of one eight-tile burst before the next queued tick bursts.
   Hero, illusions and enemies use existing normal Block/damage rules.
   Burst damage is 4 plus stored Kindled bonus, and Fire is placed on the
   dead tick's own tile. Enemy kills retain the existing Ember policy; only
   the initiating player-card kill grants the existing bonus card play.
   Living ticks show the approved `burst` icon plus total damage in the status row.
   Tooltip: “Bursts: when this dies, it deals <N> damage to everything next to it.” Pointer/controller
   focus or a lethal card preview outlines the actual eight-neighbor footprint.
   The production action forecast includes burst losses/lethality for both sides.
5. Kindle stores +2 in `kindled_bonus`, capped at +4 until death. At the cap
   it is unavailable to AI. The badge shows total Burst damage, and the
   additive abdomen ellipse is 70% tile width × 40% tile height, `#ff8a3a`,
   alpha 35% at +2 and 55% at +4. Its alpha pulses ±10% over 1.2 s; reduced
   motion keeps it steady. The board render dictionary carries the stored bonus.
6. Scuttle reuses Move 3 and melee 2 from the protected data.

Mechanics live in `scripts/enemy_mechanics/death_burst.gd` and `kindle.gd`;
their `_view.gd` helpers own overlays and presentation. The ordinary enemy
dictionary persists Kindled state and the once-only death flag. Burst event
snapshots drive breadth-first presentation after dissolve begins; existing
each subsequent burst starts 0.18 s after the previous start, and individual
dissolves begin when their units actually die. The dashed preview ring is
2 px `#e8722c` at 85% alpha, dash 8 px / gap 6 px. No new analytics event or audio
asset was added. Existing fire/attack cues remain the sound source.

Approved raw art was keyed with the existing biome-art tool, trimmed and
registered on a 255×255 canvas with base y=251 (Chainbound Gaoler).
The silhouette is 97 pixels high: 45% of the 216 px standing hero reference,
rounded to a source pixel. Protected data keeps default `art_scale=1`, zero
offsets and static fallback. The density pipeline processed only this new entry;
no rig rebake is needed. Raw SHA-256 records are in `spec/assets/enemies/`.
The 128×128 portrait centres the front shell at approximately 70% portrait width,
with the existing transparent background and 8 px margin. It is explicitly
registered in the turn clock. The approved `burst` painting is shared by Kindle,
Kindled and the passive badge. No art, font or audio was generated or downloaded.

Encounter pools are unchanged: `enc-01`/`data/encounters.json` is absent here.
The director must add `fire_ticks` and `fire_tick_swarm` after that unit lands.
The cadence is 12 before spawn stagger; roster context is mirrored in
`spec/card_balance_heuristic.md` and `tools/card_heuristic.py` without changing
intrinsic card coefficients.

Proof: `tests/en01_enemies_test.gd`, extracted full-suite registration, and
`tests/en01_enemies_probe.gd` plus its adjacent 1920×1080/100% contract.
Captures 04–09 cover three ticks/ring, Kindle, lethal preview and chain Burst.
See [EN01 proof commands](en01_proof.md) for exact owner commands.
