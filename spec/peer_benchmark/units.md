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
| rr-02 | Maquette → cutout pipeline phase 1 (gaoler mq3): registration, case, rest identity, hidden-material requests, first motion reel | merged 0d2975df1 (Codex signoff 89af23b6c) | codex/peer-benchmark | briefs/rr-02.md |
| art-04 | Integrate the owner-approved perched gust shrike (art-03 pipeline) + canon flyer reference; gate support for maquette kits | merged 576717eae (signoff dc9de2dc3; follow-ups d9929d446) | codex/peer-benchmark | briefs/art-04.md |
| sfx-04 | Audio/visual sync audit + fixes (owner playtest 7: blink sound late, cues delayed by sequencing) | merged 7eeb4a4d9 (Codex signoff 73301ac8b) | codex/peer-benchmark | briefs/sfx-04.md |
| ux-02 | Player-facing text and tooltip audit | merged 50bfcf2b7 (+ captures 0e3273caf); drafts: glossary_rewrite / relic_rewrite (Claude drafting, director review) | codex/peer-benchmark | briefs/ux-02.md |
| ux-03 | Glossary tooltips for icons and relics (data/glossary.json; card keyword stack reused for relics) | merged a98d3683f | codex/peer-benchmark | briefs/ux-03.md |
| anim-01 | Pixel-true idle life for static directional enemies (data/static_enemy_idle.json) | dropped (owner rejected mesh-warp ripple idle; replaced by cutout rigs) | codex/peer-benchmark | briefs/anim-01.md |
| por-01 | Rebuild 17 stale turn-order portraits from post-density art | merged (builder verify test; clock probe PASS, director-reviewed) | codex/peer-benchmark | briefs/por-01.md |
| vfx-01 | Pixel-art look for procedural elemental effects (low-res layer, element ramps, Bayer alpha) | merged 693209518 (Codex signoff 44eb4ce5f) | codex/peer-benchmark | briefs/vfx-01.md |
| chr-02 | Chronicle spells as card tiles with counts; tooltips on every tile | merged 9d711ceb5 | codex/peer-benchmark | briefs/chr-02.md |
| art-05 | Replayable director raw steps in the identity gate | merged 2eb5b4d17 (signoff 55bc9b8f3); follow-up: chain on decoded-pixel digests not PNG bytes, report SKIP as WARN, dedupe committed inputs, repo-relative doc commands | codex/peer-benchmark | briefs/art-05.md |
| qa-04 | Godot .import noise under output/, Chopin sidecar tolerance, en-05 sync test | merged bf7eca61f (review fixes 7f7cc8d7e) | codex/peer-benchmark | briefs/qa-04.md |
| fix-03 | Fatigue never amplified (owner); SPENT HUD flag; token icons; Lightning Strikes chip | merged (signoff 64d34965f); audit: Reflect, Ember Tick burst, Icefall/Lob/Tether, Meteorfall/Detonate self-hits still amplified — owner question pending on the self-hits | codex/peer-benchmark | briefs/fix-03.md |
| ux-04 | Apply approved glossary + relic text, renames, @term/@kw token convention, budgets | merged 1a9e585e7 (Codex signoff 1eaa7b490) | codex/peer-benchmark | briefs/ux-04.md |
| ui-02 | UI ratchet cleanup (map, skill tree, section map) | merged (pixel-identical; baseline −4; 152 bespoke colours inventoried in staged/ui/near_palette_ui02.md — median ΔE76 8.5, needs a palette review, not a ratchet) | codex/peer-benchmark | briefs/ui-02.md |
| art-06 | Identity gate robustness (pixel digests not PNG bytes, SKIP as WARN, dedupe inputs, rear→front job link, mutant tests) | merged bf3ed130a (signoff 16881db9a) | codex/peer-benchmark | briefs/art-06.md |
| art-07 | Tone max_chroma filter + palette_match keeps bright/accent-hue pixels (lancer blade, wisp cores greyed) + art-06 leftovers | merged (Codex signoff 66018ccab) | codex/peer-benchmark | briefs/art-07.md |
| anim-02 | Static idle review fixes (jitter-safe lanes, sticky lanes + in-place sync, glow redraw test, instrumentation out of runtime) — continues anim-01 (session stuck replaying) | dropped (with anim-01) | codex/anim-01 | briefs/anim-02.md |
| rr-03 | Gust Shrike cutout rig from its maquette (idle/move/dive/talon rake/hover/hit/death) | merged f411c09a9 with qa-06 (Codex signoff 7d39578e6) | codex/peer-benchmark | briefs/rr-03.md |
| demo-01 | Scripted demo clips with game audio (21 clips, 3 reels: pixel FX, hit-sound sync, lightning trap + Briar Weaver) | merged (Codex signoff 19d324d38) | codex/peer-benchmark | briefs/demo-01.md |
| qa-06 | Gust Shrike proof hardening: bone-level signed motion check; production capture without pose seeking (split from rr-03) | merged f411c09a9 (Codex signoff 7d39578e6) | codex/rr-03 | briefs/qa-06.md |
| mq-02 | Sculpted maquettes fitted to source art: NumPy geometry + rasteriser, limb/torso/shell/cloak/smooth primitives, fit tool + gate, lancer r2 | merged 942b0be73 with mq-03 (Codex signoff 368ab2ca8) | codex/peer-benchmark | briefs/mq-02.md |
| mq-03 | Blender-native maquette builder (CC0 base mesh + armature, weight ownership, cloth, plates, crystals, curves), 3/4 facing check, Blender bridge client; Lancer r3 | merged 942b0be73 (Codex signoff 368ab2ca8; Godot 839.8 s PASS, Python 670 OK) | codex/mq-02 | briefs/mq-03.md |
| ux-05 | Previews mark destruction (terrain, traps, illusions, lethal pull ghosts) instead of hiding it | merged (Codex signoff 156ebec72) | codex/peer-benchmark | briefs/ux-05.md |
| pb-01 | Pre-battle: concise objective heading + one line; foes play their board idles | merged (Codex signoff 0672b0e5d) | codex/peer-benchmark | briefs/pb-01.md |
| deck-01 | Drop the magic-slot limit; spells go to the deck; Purge at Scavenger and Campfire; save migration | merged (Codex signoff d926871aa) | codex/peer-benchmark | briefs/deck-01.md |
| rr-04 | Shale Bloomer + Lightning Wisp cutout rigs from maquettes; generic semantic motion compiler; real-time review videos | merged 58c58c9af (Codex signoff b244014b8; pre-battle routing → int-02) | codex/peer-benchmark | briefs/rr-04.md |
| int-02 | Route every presentation surface (pre-battle live actors, portraits, turn order) to the maquette rigs | merged (Codex signoff 3edfebe25) | codex/peer-benchmark | briefs/int-02.md |
| boon-01 | Opening boons from the emaciated man (3 columns, rolled up front) + heirloom carry-over | fixing r3 queued (Codex review CHANGES on 1382b6916: heirloom reconciliation, unflushed receipts, 3 surviving mutations, Purge count; director: relic text padding) | codex/peer-benchmark | briefs/boon-01.md |
| rr-05 | Maquette rig polish: features never split across parts (bloomer gem, wisp eye); stepped pixel-snapped idle (no shimmer) | fixing r4 (feedback_4 silhouette gate); feedback_5 (Wisp arc_right native mismatch, run 3) to send after r4 | codex/peer-benchmark | briefs/rr-05.md |
| map-02 | Section map revision 5: StS-like branching variety (5 lanes, 6 walks, structure-then-types solver, variety metrics) | fixing r2 queued (review CHANGES on 95b6dad2f: bounded structural retries, captures recorded, public dispatch tests) | codex/peer-benchmark | briefs/map-02.md |
| cbt-01 | "Stay" on move-and-block cards (own tile as destination) + Immolation innate 3 to adjacent (score 2.24→3.00) | accepted (Codex signoff 163ccf890); merge after qa-07 lands (suite budget) | codex/peer-benchmark | briefs/cbt-01.md |
| flow-01 | Automatic next section after the dragon reward + descent/title-card transition (no map step) | ready (launch after boon-01 + map-02 land) | codex/peer-benchmark | briefs/flow-01.md |
| rr-06 | Frostglass Lancer cutout rig from the Blender-native maquette (director motion staged/rr-06) | ready (launch after mq-03 + rr-05 land) | codex/peer-benchmark | briefs/rr-06.md |
| qa-07 | Full Godot suite under budget with headroom: profile + parallel program sub-suites (target ≤ 450 s) | fixing r1 queued (review CHANGES on fb2fc0c34: Windows orphan, storage/log isolation, 2 survived mutations) | codex/peer-benchmark | briefs/qa-07.md |
| mq-04 | Fitted Blender maquettes, roster wave 1 batch A (Hoarfrost Seer, Gale Herald, Arc Thrall, Gloam Stalker); approved art kept | fixing r1 queued (bridge timeout clarified; per-view banner cloth for Gale Herald) | codex/peer-benchmark | briefs/mq-04.md |
| anim-01/anim-02 | Static enemy mesh-warp idle | shelved (owner: ripple + bird bounce rejected) | — | feedback.md 2026-10-15 |
| fix-04 | Briar Weaver loses turn + intent after Thornwall (owner playtest 8) | merged 81e7f0dc9 (Codex signoff 6e3caa464) | codex/peer-benchmark | briefs/fix-04.md |
| qa-05 | Integration: sfx sync suites fail after sfx-04 merge (interaction) | dropped: root cause = stale .godot audio imports in the integration worktree; fixed by re-import, runtime freshness workaround rejected | codex/peer-benchmark | briefs/qa-05.md |
