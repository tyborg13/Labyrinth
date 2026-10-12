# Units ledger (peer-benchmark)

| id | title | state | base | notes |
|---|---|---|---|---|
| ev-01 | Data-driven event engine + omens (rules, save, headless, stopgap UI) | merged 5ca4bfe87 (commit 4589cef72) | codex/peer-benchmark@9485213ba | data: staged/ev-01/events.json (27 events, 11 omens) |
| sfx-00 | Sound lab tooling | merged fca2df5d6 + director fixes (no-clip cap, peak-limited tolerance) | codex/peer-benchmark | sources output/sfx-sources-2026-10-12 (Mixkit excluded) |
| feel-01 | Hit-stop, shake tiers, enemy-phase pacing, Combat speed setting | merged 09af36a0c (commit a4205772a; director set decay/ease/copy) | codex/peer-benchmark | native frame-offset check flaky — clip-verified |
| ev-02 | Illustrated event screen, omen HUD, event/omen art processing | merged f3fcff1fc (commit db94d2120) | codex/peer-benchmark@5ca4bfe87 | |
| biome-01 | Section biomes | merged 8c71fa17b (commit ddafb53f1) | codex/peer-benchmark | data staged/biomes/biomes.json; raw art output/.../raw_art/biomes |
| map-01 | Section map v2 (+ r2: Cartographer scouts mysteries on rev 4) | merged e1032c6e9 | codex/peer-benchmark@9485213ba | event view "closes after Continue" failure on integration → int-01 |
| feel-02 | Health-bar damage ghost | merged 102106be6 | codex/peer-benchmark | conflict in combat_board_view.gd resolved (kept biome reload + ghost observe) |
| itb-02 | Undo free movement until a card commits | merged 28170510d (commit d58dc4de3; 3 rounds) | codex/peer-benchmark | 60 px dock move is pre-existing board-centering tween; run_scene conflicts resolved (event view input first, then undo) |
| int-01 | Event view closes after Continue (integration failure root cause) | running | codex/peer-benchmark@e1032c6e9 | |
| itb-01 | Threats at rest | running | codex/peer-benchmark@09af36a0c | mockup mockups/threats_at_rest.png |
| meta-01 | Run score, feats, run-end screen | running | codex/peer-benchmark@e1032c6e9 | mockup mockups/run_end.png; data staged/meta-01/run_end_text.json |
| sfx-01 | SFX cue bank + call sites | running | codex/peer-benchmark@83b26b846 | data staged/sfx/sfx_cues.json (81 cues; variants_from aliases; status.expose removed) |
| meta-02 | Chronicle (run history + stats) | design (mockup mockups/chronicle.png; brief pending; after meta-01) | — | |
| meta-03 | Umbra Depths ladder (20 levels) | ready (brief briefs/meta-03.md; after meta-01 — shares run_end_recap_overlay/progression_store/run_engine) | — | data staged/meta-03/depths.json; mockup mockups/depth_picker.png |
