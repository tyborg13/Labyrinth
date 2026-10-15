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
| en-04 | Briar Weaver + Slag Mortar | merged 63271ccf4 (commit a2d078dd8 + sync ada498dda); encounters 8455019d7; art pending_reart | — | briefs/en-04.md |
| en-05 | Glacial Mirror + Gust Shrike | merged 062c3d40a (commit 5923db9da + sync 1530c6eb9 + director flag-rider fix); encounters c474da57f; art pending_reart | — | briefs/en-05.md |
| en-06 | Storm Capacitor + Hollow Mimic | merged (commit 156ed20f5 + sync 2801799b8); encounters 96a86b86e; art pending_reart (art-02) | — | briefs/en-06.md |
| itb-03 | Threats at rest v2 (owner direction) | merged 4fc16f982 (commit b18951e46 + sync); proof output/.../proof/itb-03/ | codex/peer-benchmark | brief briefs/itb-03.md |
| art-01 | Visual identity gate tooling (measure/kit/process/sheet/check, registry, bestiary lineup probe) | merged 2d06756f0 (+ director despill/unmix fixes c8d823082, 674637b2b) | codex/peer-benchmark@f7773b175 | spec/visual_identity_gate.md, briefs/art-01.md |
| art-02 | Re-art of the 12 section enemies through the identity kit | all 12 owner-approved 2026-10-13 and in game (11 via art-03, gust_shrike via art-04 maquette) | — | staged/reart/, spec/art_identity/jobs/, maquettes/ |
| qa-02 | Register en04/en05/en06 enemy suites in the full suite (backlog) | design | — | |
| art-03 | Integrate re-art: directional static art (front/rear + mirrored facing), portraits, density adoption, registry kit entries, gate post-steps + edge/rear-consistency metrics | merged 4aa4c3589 (commit 6b4927d2f + sync; r1 decisions; director: staged data sync, mirror exception, portrait crops) | codex/peer-benchmark | briefs/art-03.md |
| sfx-03 | Lookahead limiter for hit.blade.light, status.shatter, status.freeze | merged 6786edf5d (commit 29783a2d2: blade +7 dB, shatter +6, freeze +5; +11 dB reverted as ineffective under 12 dB GR) | codex/peer-benchmark | briefs/sfx-03.md |
| ui-01 | UI identity lint (gate phase 2, ratchet) | merged fceb55376 (1617 baseline sites) | codex/peer-benchmark | briefs/ui-01.md, spec/ui_identity_gate.md |
| rr-01 | Roster wave 1a: crawler rig recolour (Lab L×0.76, ab×0.85) | merged 7c770a7ec (signoff 3fe284a60; follow-up fa0351491); integration suite PASS 694 s, Python 388 OK | codex/peer-benchmark | briefs/rr-01.md |
| qa-03 | Python test hygiene (en05 asset pins, cutout seed, deepest route, optional modules) | merged (e66df1e67) | codex/peer-benchmark | briefs/qa-03.md |
| rr-02 | Maquette → cutout pipeline phase 1 (gaoler mq3): registration, case, rest identity, hidden-material requests, first motion reel | running (gpt-6-astra) | codex/peer-benchmark | briefs/rr-02.md |
| art-04 | Integrate the owner-approved perched gust shrike (art-03 pipeline) + canon flyer reference; gate support for maquette kits | merged 576717eae (signoff dc9de2dc3; follow-ups d9929d446) | codex/peer-benchmark | briefs/art-04.md |
| sfx-04 | Audio/visual sync audit + fixes (owner playtest 7: blink sound late, cues delayed by sequencing) | running (gpt-6-astra) | codex/peer-benchmark | briefs/sfx-04.md |
| ux-02 | Player-facing text and tooltip audit | merged 50bfcf2b7 (+ captures 0e3273caf); drafts: glossary_rewrite / relic_rewrite (Claude drafting, director review) | codex/peer-benchmark | briefs/ux-02.md |
| ux-03 | Glossary tooltips for icons and relics (data/glossary.json; card keyword stack reused for relics) | running (gpt-6-astra) | codex/peer-benchmark | briefs/ux-03.md |
| anim-01 | Pixel-true idle life for static directional enemies (data/static_enemy_idle.json) | running (gpt-6-astra) | codex/peer-benchmark | briefs/anim-01.md |
| por-01 | Rebuild 17 stale turn-order portraits from post-density art | merged (builder verify test; clock probe PASS, director-reviewed) | codex/peer-benchmark | briefs/por-01.md |
| vfx-01 | Pixel-art look for procedural elemental effects (low-res layer, element ramps, Bayer alpha) | merged 693209518 (Codex signoff 44eb4ce5f) | codex/peer-benchmark | briefs/vfx-01.md |
| chr-02 | Chronicle spells as card tiles with counts; tooltips on every tile | running (gpt-6-astra) | codex/peer-benchmark | briefs/chr-02.md |
| art-05 | Replayable director raw steps in the identity gate | merged 2eb5b4d17 (signoff 55bc9b8f3); follow-up: chain on decoded-pixel digests not PNG bytes, report SKIP as WARN, dedupe committed inputs, repo-relative doc commands | codex/peer-benchmark | briefs/art-05.md |
| qa-04 | Godot .import noise under output/, Chopin sidecar tolerance, en-05 sync test | merged bf7eca61f (review fixes 7f7cc8d7e) | codex/peer-benchmark | briefs/qa-04.md |
| fix-03 | Fatigue never amplified (owner); SPENT HUD flag; token icons; Lightning Strikes chip | merged (signoff 64d34965f); audit: Reflect, Ember Tick burst, Icefall/Lob/Tether, Meteorfall/Detonate self-hits still amplified — owner question pending on the self-hits | codex/peer-benchmark | briefs/fix-03.md |
| ux-04 | Apply approved glossary + relic text, renames, @term/@kw token convention, budgets | ready (after ux-03 merges) | codex/peer-benchmark | briefs/ux-04.md |
| ui-02 | UI ratchet cleanup (map, skill tree, section map) | merged (pixel-identical; baseline −4; 152 bespoke colours inventoried in staged/ui/near_palette_ui02.md — median ΔE76 8.5, needs a palette review, not a ratchet) | codex/peer-benchmark | briefs/ui-02.md |
| art-06 | Identity gate robustness (pixel digests not PNG bytes, SKIP as WARN, dedupe inputs, rear→front job link, mutant tests) | merged bf3ed130a (signoff 16881db9a) | codex/peer-benchmark | briefs/art-06.md |
| art-07 | Tone max_chroma filter + palette_match keeps bright/accent-hue pixels (lancer blade, wisp cores greyed) + art-06 leftovers | merged (Codex signoff 66018ccab) | codex/peer-benchmark | briefs/art-07.md |
| anim-02 | Static idle review fixes (jitter-safe lanes, sticky lanes + in-place sync, glow redraw test, instrumentation out of runtime) — continues anim-01 (session stuck replaying) | running (gpt-6-astra) | codex/anim-01 | briefs/anim-02.md |
| rr-03 | Gust Shrike cutout rig from its maquette (idle/move/dive/talon rake/hover/hit/death) | running (gpt-6-astra) | codex/peer-benchmark | briefs/rr-03.md |
| anim-01/anim-02 | Static enemy mesh-warp idle | shelved (owner: ripple + bird bounce rejected) | — | feedback.md 2026-10-15 |
| fix-04 | Briar Weaver loses turn + intent after Thornwall (owner playtest 8) | merged 81e7f0dc9 (Codex signoff 6e3caa464) | codex/peer-benchmark | briefs/fix-04.md |
