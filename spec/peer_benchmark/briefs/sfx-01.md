# sfx-01 — Data-driven SFX cue bank and full call-site pass

## Header
- Goal: every meaningful action has a distinct, variant-rotating sound (Slay the Spire ships ~410 files with round-robin
  variants; we have 28). This unit builds the cue bank and wires ~80 cues at their exact moments. Assets come later as
  director data: until a cue has `variants`, it plays its `fallback` (existing files) or stays silent.
- Base: `codex/peer-benchmark` after feel-01 merges (director gives the commit).
- Owned files: new `data/sfx_cues.json` (director-authored, committed before launch, protected — read every value from
  it), new `scripts/sfx_bank.gd`, new `scripts/sfx_cue_router.gd` (maps game events → cue ids), new
  `tests/suites/sfx_bank_suite.gd` + `tests/sfx_bank_test.gd`, new `tests/sfx_cue_coverage_probe.gd`; modify
  `scripts/attack_sfx_library.gd`, `scripts/run_sfx_library.gd`, `scripts/run_scene.gd` (≤ 120 lines: route playback
  through the bank; prefer moving logic out), `scripts/combat_board_view.gd` (emit presentation events the router
  needs — prefer signals/hooks over sound calls inline), `scripts/settings_store.gd` (bus names only if needed),
  `spec/audio.md` (new; supersedes the audio-mix notes in visual_design_system.md, which you trim to a pointer),
  `tests/suites/audio_routing_suite.gd`, `tests/suites/attack_sfx_suite.gd` (update to the new ids without weakening).
- Rules: presentation only; deterministic tests (variant choice uses a seeded RNG per cue for tests; runtime may use
  the global RNG); no new audio files in this unit; respect the owner's audio rules: one impact per hit, no stacked
  cues (see `rules` in the data), stingers keep authored pitch.
- Contract: risk tier standard (audio presentation). Acceptance: (1) the bank plays cues by id with variants,
  volume, pitch jitter, cooldown, max voices, bus and loop from data; (2) every cue in the data has a wired trigger
  matching its `trigger` text, verified by a coverage probe; (3) existing sounds keep playing through fallbacks with
  today's levels; (4) the one-impact rule and merge window hold.

## Change (numbered, testable)
1. **SfxBank**: loads `data/sfx_cues.json`; `play(cue_id, opts := {})` → picks a variant by round-robin with a random
   start (never the same variant twice in a row when ≥ 2 exist), applies `volume_db` + opts.gain_db, pitch jitter
   (uniform ±fraction), `cooldown_ms` (same cue suppressed inside the window), `max_voices` (steal the oldest), bus
   (`World` → the existing world SFX bus, `UI` → the UI SFX bus), `loop` for ambience (crossfade 0.6 s on change).
   Variants list empty → fallback list; both empty → silent (no error, counted for the coverage report). Pooled
   players; no per-play allocations after warm-up.
2. **Router** (`sfx_cue_router.gd`): one function per game moment that decides the cue id:
   - Attack kind → hit cue: hero attacks use the equipped weapon's family (blade: sword, dagger, rapier, axe, halberd,
     scythe; blunt: mace, maul, hammer, club, flail, shield bash, staff; pierce: spear, lance, bow/crossbow
     projectiles); cards without a weapon use their action type (melee → blade, push/charge → blunt, ranged physical →
     pierce, neutral spell → hit.arcane, elemental → spell.<element>). Enemy attacks: a per-enemy family table you
     derive from the cutouts' weapons (spears → pierce, claws/teeth → claw, fists/stone → blunt, blades → blade); list
     the table in spec/audio.md for review. Light/heavy split at damage ≥ 6. Fully blocked → hit.blocked;
     frozen-target hit → status.shatter; collision damage → push.collision.
   - Death family table per enemy type (beast, humanoid, bone, stone, ooze, spirit, avian, dragon), also listed in
     spec/audio.md.
   - Walk steps: step.hero per tile synced to the walk cycle; enemies light/heavy by footprint/size class.
3. **Wiring.** Implement every cue's `trigger` exactly. Area/multi-target: impact once at full volume + up to 2 more
   at −6 dB staggered 35 ms. Hero hit with ≥ 5 HP lost adds `hurt.hero`. `vocal.beast` at 30% (seeded per action).
   `dragon.roar` on a dragon's first action of the fight and at each big area attack's resolution. Ambience beds by the
   section's biome (`ambience.<biome>`; legacy/non-section runs: `ambience.stone` = today's hall tone).
4. **Compatibility.** Existing cue ids (`attack.melee`, `attack.ranged`, `action.block`, `attack.elemental.*`,
   `run.*`, card draw/play/flip, reward, hearth) keep working: either alias them to new cues or keep them as-is where no
   new cue replaces them. Today's mix levels for fallbacks are preserved (owner-auditioned).
5. **Coverage probe** (`tests/sfx_cue_coverage_probe.gd`, headless): drives representative states (each attack family,
   each death family, push+collision, trap, each surface, each status, heal, illusion spawn/break, crate hit/break,
   pickups, defiance, fatigue, relic trigger, card hover/select/invalid/exhaust/shuffle, map hover/select, event choose,
   omen gain, shop buy/sell, each ambience) and asserts the expected cue ids were requested in order; prints a table
   cue → requested (yes/no) → has variants/fallback.
6. **Spec** spec/audio.md: buses, the bank, the router tables (weapon families, enemy families, death families), the
   rules, how to add variants.

## Keep
- Owner-approved levels and decisions in spec/visual_design_system.md "Audio mix notes" (move them into audio.md
  verbatim), card-play loudness, no sound on Pass beyond the click, music routing untouched.

## Proof
- Bank suite: round-robin, cooldown, max voices, fallback, silent, loop crossfade, bus routing.
- Coverage probe: every cue requested by at least one driven state.
- Keep green: audio_routing, attack_sfx, ui sfx probes/suites, full suite.

## Out of scope
- Choosing or making sound files, music, new UI.
