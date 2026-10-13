# sfx-01 feedback 1 (director)

Your branch is committed (8b1911aee), synced with `codex/peer-benchmark` (now includes the owner-picked assets under
`assets/audio/sfx/cues/` and the manifest), and `data/sfx_cues.json` is updated by the director (protected): 77 cues now
have `variants`, ambience.<biome> cues use `variants_from: ambience.stone` (no new beds), and `trap.trigger` is a single
cue (do NOT stack an element spell cue after it — update the router/wiring accordingly).

Decisions:
1. Galewhip → blade family.
2. Unknown weapon family → blunt; unknown enemy attack family → blunt; unknown death family → humanoid (remove the
   TODO placeholders; log a warning in debug builds only).
3. Section enemies (add to the tables now; they land in parallel units): burrow_grub claw/beast, ember_tick claw/beast,
   hoarfrost_seer blunt/humanoid, gale_herald blunt/humanoid, arc_thrall blunt/humanoid, gloam_stalker blade/spirit,
   briar_weaver claw/stone, slag_mortar blunt/humanoid, glacial_mirror blunt/stone, gust_shrike claw/avian,
   storm_capacitor blunt/stone, hollow_mimic blade/spirit. bell_tender and storm_cantor attacks → blunt (staffs).
   Elemental actions keep overriding physical families.
4. Relic trigger: play `relic.trigger` only for relics with explicit outcome records (what you have). No general pulse
   hook (fewer sounds). Remove `TODO_DESIGN_RELIC_BADGE_PULSE`.
5. **No stacked clicks**: when `map.hover`, `map.select` or `event.choose` (and card.hover/card.select) play, the shared
   cursor/UI click for that same input must not also play. You may edit the file that emits the shared cursor click
   (ui feedback / cursor feedback script) for this, minimal.
6. With real variants now present, re-run the coverage probe and report the table (expect 77 with variants, aliases,
   ambience.stone fallback, status.expose removed).

Proof wanted: suites green; coverage table; and a windowed run of `tests/sfx_cue_coverage_probe.gd` command for me
(with the real audio driver so I can capture audio if possible) — list it.
