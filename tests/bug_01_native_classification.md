# bug-01 feedback 4 — native case classification

Based on the owner-provided `output/bug-01/native_dump_run2/` reports and all twelve representative original/restored/fresh image triplets. These are observations of the **before-fix** renderer and diagnostic fixture, not a claim that the revised native proof has passed.

All 106 raw temporal pairs and all 106 pinned temporal pairs are exactly equal. The shader-TIME hypothesis is rejected for this run. No tolerance is justified or introduced.

`original_submission` means the separate frozen historical renderer in
`tests/fixtures/static_floor_cache_reference.gd`, receiving the current case's
inputs. It is not a screenshot from an earlier state. Both it and production
retain draw commands, so they can share the same missed redraw (case 21) or
invalid private fixture setup (103/104). Equality to it alone cannot prove cache
correctness. The strict current-production fresh comparison supplies that check.

The 31 differing elemental cases are ranged/trap-effect presentations, rather
than the persistent floor-surface mutations: surface cases 65–69 and 92–96 are
all equal. Both renderers receive the same effect phase; the frozen renderer's
effect drawing is obsolete, as the supplied soft-versus-dithered images show.
Specifically, `PixelFxLayer.route()` deliberately falls back to pre-pixelation
drawing when its canvas lacks `_submit_pixel_fx`. Current production implements
that hook; the frozen reference does not. Both call the shared procedural
`ElementalSpellFx`, but only production routes it through the pixel-FX layer.
The current route and protected `data/vfx_pixel_style.json` are unchanged.
`3c19f5e6f` (vfx-01, 2026-10-15) introduced the current hook; the frozen copy was
not adapted. This is the exact stale-reference source for the 31 effect cases.

44 cases differ in at least one of the three baseline comparisons; 62 are equal controls. There is one demonstrated production defect: case 21 updates lighting correctly but misses the foreground pillar redraw when a brazier starts or stops obstructing it.

## Findings and changes

| Cases | Classification | Evidence and correction |
| --- | --- | --- |
| 2–3 | Expected change / wrong fresh fixture | The retained room entered with an empty encounter closure; the fresh room first saw a warden. `BoardFraming.capture()` intentionally freezes the room envelope at entry. Headless audit found retained origin y=225.0413 and fresh y=246.3644 with different encounter/head bounds, while each floor matched its own geometry. The fixture now supplies the future warden in `board_encounter_types` from entry, as production callers do. No geometry cache is copied to fresh. |
| 10–14 | Ghost/transient UI | Exactly 571 changed pixels in the 56×12 HP trail. The retained board saw HP 24→12, the fresh board did not. Finish the real health-ghost clock before freezing/comparing; check both trackers are inactive. |
| 21 | Production retained-command bug | 37,165 pixels at the foreground pillar, not a lighting/floor mismatch. Root and floor geometry and lighting match; new obstruction data already includes the brazier, but selective routing redraws its own tile only. Redraw candidates whose obstruction status changes. Headless onset/removal regressions fail before this production fix and pass after it. Native strict retained/fresh comparison is the pixel regression. |
| 27–28 | Expected change / wrong fresh fixture | Floors and actors agree; the fresh HP bar is misplaced. Its helper copied navigation after computing HUD/obstruction caches and refreshed only layer fields. Production public navigation updates all caches. The helper now uses that complete transform path. Independent geometry/HUD/obstruction/floor-input comparisons pass headlessly. |
| 46–47, 50–51, 54–55, 58–59, 62–63, 72–91, 101 | Expected change / obsolete original renderer | All 31 retained/fresh comparisons are exactly 0 px. The frozen reference uses older soft elemental art instead of current treated/dithered art. Use current fresh production as the complete-pixel baseline for these changed presentations; retain original pixels only for explicit unchanged submissions. Structural frozen-reference assertions and strict cached-floor comparisons stay. |
| 103 | Expected change / invalid fixture plus obsolete effects | All three differ for independent reasons. The test directly wrote zoom/pan, invalidated layout and copied dynamic fields, leaving the floor at width 183.9993 / origin (960,225.0413), while actors used width 152.7194 / origin (972,272.8142). It bypassed `_navigation_transform_changed()`. Use public zoom/pan/focus before the private presentation-only reactivation under test. The reference additionally has older fire rendering. |
| 104 | Expected change / inherited invalid fixture | The previous direct navigation writes left both retained and original floors stale; this same-state submission had no reason to repair an unsupported private mutation. Correct case 103 setup; then assert current floor geometry and complete fresh input equality in every case. |
| 105 | Expected change / wrong fresh fixture plus obsolete effects | New room floor geometry already equals current root geometry and fresh floor (width 152.7194, origin (883.6403,319.9941)); no stale-room floor. The 6,107 retained/fresh pixels are the misplaced fresh HP bar, caused by copying zoom after HUD construction. The reference separately uses old ice effects. The complete navigation route repairs fresh. |

## Production root cause and impact

`7d38b66ce` (Reduce combat animation redraw work, 2026-08-26) introduced the dedicated `scene_props` branch that queues only the old/new prop tiles. Its parent used the conservative full-redraw fallback for that key. This predates baseline `816f5e68a` (2026-10-08), so there is no later introduction to bisect within the requested baseline-onward range. Evidence: `output/bug-01/scene-prop-history.log`; no historical engine checkout/run is claimed.

A player can see a brazier appear behind an opaque foreground pillar, or a pillar remain faded after the prop disappears, until an unrelated redraw occurs. Floor lighting, zoom, pan and room invalidation are not changed by this fix. `board_scene_prop_redraws.gd` reuses the existing obstruction coverage/depth rules and queues only candidates whose old/new prop obstruction differs. No opacity, timing, art, mechanics, analytics, save or input values change.

## Every reported case

Pixel columns are retained/original, retained/fresh and fresh/original. All temporal columns are zero and omitted here for brevity.

| Case | Definition | R/O px | R/F px | F/O px | Classification |
| --- | --- | ---: | ---: | ---: | --- |
| 001 | empty | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 002 | actor clock fixture | 0 | 727662 | 727662 | Expected change / fixture: missing future warden encounter closure |
| 003 | actor clocks restored | 0 | 727662 | 727662 | Expected change / fixture: missing future warden encounter closure |
| 004 | actor clock fixture cleared | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 005 | floor lit | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 006 | same floor resubmitted 0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 007 | same floor resubmitted 1 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 008 | same floor resubmitted 2 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 009 | retained after instrumentation reset | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 010 | HP only | 571 | 571 | 0 | Ghost/transient UI: 24→12 damage trail |
| 011 | active door | 571 | 571 | 0 | Ghost/transient UI: 24→12 damage trail |
| 012 | same door gains exit label | 571 | 571 | 0 | Ghost/transient UI: 24→12 damage trail |
| 013 | locked door | 571 | 571 | 0 | Ghost/transient UI: 24→12 damage trail |
| 014 | door hidden | 571 | 571 | 0 | Ghost/transient UI: 24→12 damage trail |
| 015 | floor variant room | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 016 | floor moss ice | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 017 | floor moss fire | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 018 | floor moss lightning | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 019 | floor moss earth | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 020 | floor moss none | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 021 | floor light changed | 0 | 37165 | 37165 | Cache bug: foreground pillar opacity commands not redrawn |
| 022 | floor light cleared | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 023 | floor art enabled false | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 024 | floor art enabled true | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 025 | floor preset moody | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 026 | floor preset warm | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 027 | floor zoom | 0 | 6122 | 6122 | Expected change / fixture: fresh HUD used pre-zoom geometry |
| 028 | floor pan | 0 | 6056 | 6056 | Expected change / fixture: fresh HUD used pre-pan geometry |
| 029 | floor navigation restored | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 030 | floor cache enabled false | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 031 | floor cache enabled true | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 032 | floor source textures changed | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 033 | floor source textures restored | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 034 | in-place floor variant mutation | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 035 | restored baseline | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 036 | retained room framing | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 037 | Begin visibility changes | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 038 | retained room restored | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 039 | retained painter order recovered | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 040 | equal-content asset replacement | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 041 | in-place asset mutation | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 042 | retained geometry changed | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 043 | retained new canvases initialized | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 044 | retained reuse restored | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 045 | fire/ordinary/0.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 046 | fire/ordinary/0.38 | 37571 | 0 | 37571 | Expected change / obsolete original elemental baseline |
| 047 | fire/ordinary/0.79 | 37786 | 0 | 37786 | Expected change / obsolete original elemental baseline |
| 048 | fire/ordinary/1.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 049 | earth/ordinary/0.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 050 | earth/ordinary/0.38 | 19435 | 0 | 19435 | Expected change / obsolete original elemental baseline |
| 051 | earth/ordinary/0.79 | 25257 | 0 | 25257 | Expected change / obsolete original elemental baseline |
| 052 | earth/ordinary/1.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 053 | air/ordinary/0.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 054 | air/ordinary/0.38 | 26271 | 0 | 26271 | Expected change / obsolete original elemental baseline |
| 055 | air/ordinary/0.79 | 28102 | 0 | 28102 | Expected change / obsolete original elemental baseline |
| 056 | air/ordinary/1.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 057 | lightning/ordinary/0.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 058 | lightning/ordinary/0.38 | 111278 | 0 | 111278 | Expected change / obsolete original elemental baseline |
| 059 | lightning/ordinary/0.79 | 112458 | 0 | 112458 | Expected change / obsolete original elemental baseline |
| 060 | lightning/ordinary/1.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 061 | ice/ordinary/0.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 062 | ice/ordinary/0.38 | 20920 | 0 | 20920 | Expected change / obsolete original elemental baseline |
| 063 | ice/ordinary/0.79 | 32386 | 0 | 32386 | Expected change / obsolete original elemental baseline |
| 064 | ice/ordinary/1.0 | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 065 | surface/rubble | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 066 | surface/ice | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 067 | surface/fire | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 068 | surface/lightning | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 069 | surface/none | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 070 | lit watch brazier | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 071 | brazier cleared | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 072 | fire/ordinary/0.0 | 37055 | 0 | 37055 | Expected change / obsolete original elemental baseline |
| 073 | fire/ordinary/0.38 | 37055 | 0 | 37055 | Expected change / obsolete original elemental baseline |
| 074 | fire/ordinary/0.79 | 37055 | 0 | 37055 | Expected change / obsolete original elemental baseline |
| 075 | fire/ordinary/1.0 | 37055 | 0 | 37055 | Expected change / obsolete original elemental baseline |
| 076 | earth/ordinary/0.0 | 21793 | 0 | 21793 | Expected change / obsolete original elemental baseline |
| 077 | earth/ordinary/0.38 | 21793 | 0 | 21793 | Expected change / obsolete original elemental baseline |
| 078 | earth/ordinary/0.79 | 21793 | 0 | 21793 | Expected change / obsolete original elemental baseline |
| 079 | earth/ordinary/1.0 | 21793 | 0 | 21793 | Expected change / obsolete original elemental baseline |
| 080 | air/ordinary/0.0 | 26242 | 0 | 26242 | Expected change / obsolete original elemental baseline |
| 081 | air/ordinary/0.38 | 26242 | 0 | 26242 | Expected change / obsolete original elemental baseline |
| 082 | air/ordinary/0.79 | 26242 | 0 | 26242 | Expected change / obsolete original elemental baseline |
| 083 | air/ordinary/1.0 | 26242 | 0 | 26242 | Expected change / obsolete original elemental baseline |
| 084 | lightning/ordinary/0.0 | 109591 | 0 | 109591 | Expected change / obsolete original elemental baseline |
| 085 | lightning/ordinary/0.38 | 109591 | 0 | 109591 | Expected change / obsolete original elemental baseline |
| 086 | lightning/ordinary/0.79 | 109591 | 0 | 109591 | Expected change / obsolete original elemental baseline |
| 087 | lightning/ordinary/1.0 | 109591 | 0 | 109591 | Expected change / obsolete original elemental baseline |
| 088 | ice/ordinary/0.0 | 28390 | 0 | 28390 | Expected change / obsolete original elemental baseline |
| 089 | ice/ordinary/0.38 | 28390 | 0 | 28390 | Expected change / obsolete original elemental baseline |
| 090 | ice/ordinary/0.79 | 28390 | 0 | 28390 | Expected change / obsolete original elemental baseline |
| 091 | ice/ordinary/1.0 | 28390 | 0 | 28390 | Expected change / obsolete original elemental baseline |
| 092 | surface/rubble | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 093 | surface/ice | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 094 | surface/fire | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 095 | surface/lightning | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 096 | surface/none | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 097 | lit watch brazier | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 098 | brazier cleared | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 099 | intent ribbon | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 100 | echo ribbon | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 101 | combined effects | 259809 | 0 | 259809 | Expected change / obsolete original elemental baseline |
| 102 | combined cleared | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
| 103 | partial reactivation | 198638 | 664708 | 716508 | Expected change / fixture: private navigation writes bypassed floor/HUD invalidation; frozen reference also uses old effects |
| 104 | hidden layout reset | 0 | 702896 | 702896 | Expected change / fixture: stale floor inherited from private navigation setup in 103 |
| 105 | new room | 133281 | 6107 | 139388 | Expected change / fixture: fresh HUD used pre-zoom geometry; frozen reference also uses old effects |
| 106 | restored empty board | 0 | 0 | 0 | Equal control: no discrepancy demonstrated |
