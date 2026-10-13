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
| int-01 | Event view closes after Continue (integration failure root cause) | merged 65bfb8add (commit a27ecca6e; test timing, not production) | codex/peer-benchmark@e1032c6e9 | |
| itb-01 | Threats at rest | merged 6e1edef37 (commit d998663ac; r1 decided 6 TODO_DESIGN; native probe PASS) | codex/peer-benchmark@09af36a0c | mockup mockups/threats_at_rest.png |
| meta-01 | Run score, feats, run-end screen | merged 6f4bbacfb (commit 66ffa3966; 3 rounds; director plural fix) | codex/peer-benchmark@e1032c6e9 | mockup mockups/run_end.png; data staged/meta-01/run_end_text.json |
| sfx-01 | SFX cue bank + call sites | merged ba3cd901c (commit 215dbdb28; r0 stalled→resumed; r2 decisions) | codex/peer-benchmark@83b26b846 | data staged/sfx/sfx_cues.json (81 cues; variants_from aliases; status.expose removed) |
| meta-02 | Chronicle (run history + stats) | merged e5c36d24d (commit d3f46046f) | — | mockup mockups/chronicle.png + listed changes |
| meta-03 | Umbra Depths ladder (20 levels) | merged 90823d36d (commit 6a0f94f4e; r1 decisions + shop price display) | — | data staged/meta-03/depths.json; mockup mockups/depth_picker.png |
| fix-01 | Wave-1 peer-review fixes (13 findings) | merged 83eb01a5c + r1 21ed3604f (commit 78973e64e); peer review APPROVE at 78973e64e | codex/peer-benchmark@b39b4bba0 | feedback/peer_review_wave1.md |
| sfx-02 | Sound lab layered-design renderer | merged 8ff4eb929 (commit 59f245450); round-2 audition https://claude.ai/artifact/8RUbmHZ3gNL2Fq85Nasmq2 (db picks_r2) | codex/peer-benchmark@b39b4bba0 | recipes staged/sfx/recipes_r2.json |
| enc-01 | Data-driven section encounter tables | merged 7a12f17f7 (commit 45bb95f26; r1 found+fixed empty-board render bug on biome/layout change) | codex/peer-benchmark@52ebbefa9 | data staged/enc-01/encounters.json |
| en-01 | Burrow Grub + Ember Tick | merged d56270280 (commit 7f4c1b300; r1 decisions + director dust 5 px); encounters 5ab3b59cc | codex/peer-benchmark@8290eb183 | briefs/en-common.md + en-01.md |
| en-02 | Hoarfrost Seer + Gale Herald | merged (merge after e5c36d24d~1; commit 00d710d9f + sync 494e73676); encounters ba3dcd2d1 | codex/peer-benchmark@8290eb183 | |
| en-03 | Arc Thrall + Gloam Stalker | merged bc63d4b36 (commit 7a74e6d6b + sync 872f9647a); encounters 96926ac30 | codex/peer-benchmark@8290eb183 | |
| en-04..06 | Wave E2 mechanics (briar weaver, slag mortar, glacial mirror, gust shrike, storm capacitor, hollow mimic) | design (data staged/enemies/wave_e2.json; art approved except briar weaver r1) | — | briefs after E1 lands |
| qa-01 | Program test wiring + native combat-feel determinism | merged 5d0419efc (commit 1e5cdbe47); r1 merged 325ace5ca (commit 4761ff859; 3/3 native passes, measurements recorded) | — | reviewer nits; native heavy-hit offsets failure |
| fix-02 | run_seconds out of combat state (combat_feel regression from meta-01) | merged 0d54a5970 (commit 13ffa4a8a; director adapted live-clock test) | codex/peer-benchmark | brief briefs/fix-02.md |
| ux-01 | Owner UX backlog (start room → map, threats-at-rest redesign, SFX limiter) | merged a0855abec (commit 5f80cf506; r1 hint placement) | — | backlog_ux.md |
| en-04 | Briar Weaver + Slag Mortar | fixing r1 (painted bramble prop) | — | briefs/en-04.md |
| en-05 | Glacial Mirror + Gust Shrike | review (r0 done; 5 TODO_DESIGN decided: dive right-hand push, hero not pushed, blocked landing stops short, two tooltips) | — | briefs/en-05.md |
| en-06 | Storm Capacitor + Hollow Mimic | review (r1 done; probe pending) | — | briefs/en-06.md |
| itb-03 | Threats at rest v2 (owner direction) | review (r0 done; probe pending) | codex/peer-benchmark | brief briefs/itb-03.md |
| art-01 | Visual identity gate tooling (measure/kit/process/sheet/check, registry, bestiary lineup probe) | running | codex/peer-benchmark@f7773b175 | spec/visual_identity_gate.md, briefs/art-01.md |
| art-02 | Re-art of the 12 section enemies through the identity kit (front+rear, judge, owner sheets) | design (pilots running; subjects staged/reart/) | — | staged/reart/plan.json |
