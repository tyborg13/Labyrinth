# Dragon feedback presentation — 2026-09-28

Scope: Noctyrax shadow spells, successful Molt Shard exchange feedback, and shorter Stormroad Coil rules. Root owns combat pressure redesign. This record is presentation proof, not evidence of encounter difficulty.

## Design and boundaries

Noctyrax uses the existing elemental renderer's textured clouds, feathered ribbons and soft light: dark smoke with torn violet edges, a layered travelling breath and a rising dissipating impact. Dense material stays behind actors; only sparse translucent edges cross the foreground. Existing declared targets, per-tile depth, source visibility and reduced-motion still impacts remain authoritative. New refuge sweeps dispatch by committed shape to ground shadow, preserving the separate main attack. No rig, paint, hitbox, timing or combat changes are included.

The service decision remains trade, level-up or Leave. A durable trade briefly shows the established Ember icon and exact `+250 Embers` above the service card, with the existing 0.95-second Hearth Strength sound on the UI sound bus. Normal mode adds rising embers; reduced mode keeps a stationary glow and fade. Only a saved profile purchase starts the cue; analytics acknowledgment failure still celebrates the already-credited purchase. Empty/failing purchases do not. Duplicate activation is guarded during feedback; Leave and level-up remain available. Closing/loading invalidates pending feedback and its focus restoration.

Stormroad Coil keeps single-target/ranged, one Electrified relay and normal range per leg. Redundant line-of-sight/visibility prose is removed; the mechanics and icon identities are unchanged.

## Verification coverage

Worker-owned `python3 tools/parallel_task.py preflight` passed on clean `caea023d25edde6712cdbcd7524eb0afd15be5d9` before edits. No stage/commit/publication belongs to this worker.

- `tests/dragon_exchange_presentation_test.gd`: actual service handler via pointer/controller activation, two available shards plus duplicate signal, exact durable credit, cue identity/duration/bus, normal/reduced mode, preserved highlighted focus, no-shard and blocked profile commit, acknowledgment-only failure, Leave/load cancellation and immediate level-up. The reusable `run_live(tree, expect)` adapter isolates and restores profile, run, settings and analytics paths, then disposes its actual scene.
- `tests/dragon_pressure_presentation_probe.gd`: same service lifecycle in the real 1920×1080 renderer, plus actual resolver-backed Noctyrax release/impact/dissipation and reduced stills, and production Coil tooltip. Staged playback only.
- Existing `tests/dragon_wallet_ack_test.gd` remains the broader wallet/outbox regression.

## Iteration receipts

- Initial exchange test `1790608134966537000-59753` correctly failed runner validation despite passing its assertions: a replaced service button remained in the controller candidate dictionary. Dialogue cleanup now removes candidates owned by those buttons before freeing them.
- Focused rerun `1790608197802075000-59898` exited 0 / PASS. Wallet acknowledgment rerun `1790608221149646000-59952` exited 0 / PASS (108 checks). Their intentional acknowledgment-write failure reports are expected; no script/parse errors remain.
- Native `pressure-presentation-01.json` captured 20 images but is development proof: its first reduced Noct selector picked an auxiliary empty-area step, and release pixels exposed a brazier/action-banner overlap.
- Native `pressure-presentation-02.json` exited 0 / PASS with 20 images. Exchange/Coil and impact images are clean. **Its Night Coil release is rejected**: recomputed marker geometry was clear while the retained HUD still displayed the old overlapping label. Final proof now reads the actual drawn tooltip registrations and reserves the Noct action band before its banner appears.
- Peer static review additionally found the new secondary refuge areas inherited the physical-claw or breath fallback. Dispatch now recognizes `aoe/refuge`; final probe requires six distinct primary/secondary area actions, each with release, impact, dissipation and reduced rest witnesses (32 images including the service/Coil states).
- Fanfare completion now re-enables only Trade instead of rebuilding the footer, preserving the player's highlighted Leave/level-up button. The suite also exercises immediate level-up during the cue and asserts its purchase/focus survive cue cancellation.
- Focused adapter run `1790610301391076000-62531` (session 19814) exited 0 / PASS. It also checks restoration of caller storage paths. The only error diagnostic is the expected acknowledgment-write injection.
- Native `pressure-presentation-03.json` correctly failed on the first Night Coil release: actual retained HUD registrations still overlapped the action banner. Noctyrax effect/progress updates now invalidate that HUD layer, so the obstacle-aware layout is redrawn as the pose changes. Other actors retain their existing invalidation behavior.
- Native [pressure-presentation-04.json](../output/dragon-revision/pressure-presentation-04.json), run `dragon-pressure-presentation-04-1790610510606496000-62766-dragon_pressure_presenta-1` (session 73964), exited 0 / PASS with all 32 images validated at 1920×1080 and 100% scale. `witnesses.json` has no failures. The expected acknowledgment injection is the only error diagnostic; no script/parse errors were reported. Earlier failed/development receipts remain preserved.

## Historical v04 visual review

All 32 v04 originals were inspected at original resolution: seven exchange states, the Coil tooltip, and six distinct Noctyrax area actions with release/impact/dissipation/reduced witnesses. Exchange credit and failure copy are unclipped, Trade remains disabled only during the brief cue, and the selected Leave button survives completion. The concise Coil tooltip retains the three existing icon meanings. Noctyrax's smoke has irregular soft edges and a dissipating violet foreground; character silhouettes, damage numbers and terrain remain readable. The repaired Snuff label clears the action banner in the first release frame. All six reduced witnesses record `clip=rest` and the same declared area as normal playback.

This is a staged resolver-backed playback study, not native encounter-balance evidence. Actor/visibility depth intentionally occludes some ground effects, especially the five-cell Starless refuge beneath the large dragon silhouette; no foreground overlay was added to bypass that rule. Audio validation proves the existing complete 0.95-second Hearth cue loads, uses the UI sound bus and is requested exactly once for a durable successful purchase; this receipt does not claim a new audio recording or listening comparison.

Originals, witnesses and log are under the immutable run directory:

`/private/tmp/labyrinth-godot-home/dragon-pressure-presentation-04-1790610510606496000-62766-dragon_pressure_presenta-1/`

The manifest links every original PNG. `Library/Application Support/Escape the Umbra Visual Probe dragon-pressure-presentation-04-1790610510606496000-62766-dragon_pressure_presenta-1/probes/dragon_pressure_presentation/witnesses.json` records actual drawn brazier rectangles, action profiles, tile sets, progress and reduced rig snapshots.

Reproduction command (requires the exclusive runtime lease and a fresh output namespace):

```sh
python3 tools/visual_probe_runner.py tests/dragon_pressure_presentation_probe.gd --task-id dragon-pressure-presentation-04 --no-headless --timeout 90 --min-images 32 --expect-size 1920x1080 --result-manifest output/dragon-revision/pressure-presentation-04.json
```

The 90-second bound covers service success/cancellation waits plus four complete compound boss turns and 32 PNG encodes; it is not an extension for a startup failure. The manifest names the isolated log, source run and immutable screenshot paths.

## Scope and handoff

Production ownership: `scripts/dragon_shadow_fx.gd`, `scripts/dragon_spell_presentation.gd`, `scripts/molt_exchange_feedback.gd`, the Noct refuge branch in `scripts/dragon_presentation.gd`, exchange/choice-candidate cleanup and Noct banner reservation in `scripts/run_scene.gd`, Noct marker layout/copy/invalidation in `scripts/combat_board_view.gd`, and only the Stormroad Coil description in `data/relics.json`. Tests are the focused launcher, `tests/fixtures/dragon_exchange_run_scene.gd`, `tests/suites/dragon_exchange_presentation_suite.gd` and native presentation probe. No rig/paint/icon identity or wallet/mechanics changes belong to this worker.

The runtime lease was explicitly returned after v04 exited. The v04 lifecycle/layout review was complete within its captured scope. The later material-quality review below reopens Shadow art acceptance; separate peer review, integrated regression, native pressure studies, final commit/inspection and publication decisions belong to the coordinator. No commit, push or publication was performed by this worker.

## Current-geometry warning and presentation refresh

Later pressure tuning changed Noctyrax's secondary fields to fixed player-declaration areas with radii 3/2/1, and changed its small brazier tooltip to refer to marked ground. The two Noct Grimoire pages now distinguish Light's protection from Eclipse darkness from those independent fixed areas. V04 remains historical evidence for its source, not current-geometry acceptance.

`tests/dragon_pressure_warning_probe.gd` renders 24 focused production warnings at depths 4/8/12/16/20/24 using the inspection factory's balanced builds, progression levels, skills, natural decks and acquired equipment/trophies. It also renders the revised `combat:boss_eclipse` and `enemy:noctyrax` Grimoire pages. Witnesses retain full input states, committed action/source fields, expected/displayed threat previews, previous resolution summaries and named source hashes before/after. This is explicitly staged: later states use direct boss resolution, setup-only HP/max HP 999 restored before capture, and the entry current actor restored for display. Actual resolver terrain, surfaces, trails, helpers, positions, statuses, source snapshots and RNG remain. Helpers do not act separately. It proves warning/source fidelity, not native cadence, reaction time, hand likelihood or difficulty. Peer source review found no actionable fixture/assertion defect within that scope.

Preserved iterations:

- Warning01 exited 1 after 24 successful warnings because the probe treated the Grimoire unlock return wrapper as the run state. The owning probe was corrected.
- Warning02 exited 0 with 26 images, but early images lacked the deferred player-budget HUD; it remains development proof.
- Warning03 exited 1 on the explicit first-layout readiness assertions. A guessed delay was replaced by the real hand revision and meter visibility gates.
- [pressure-warnings-04.json](../output/dragon-revision/pressure-warnings-04.json), run `dragon-pressure-warnings-04-1790615734549523000-67035-dragon_pressure_warning-1`, session 41921, exited 0: 26 images, 1920×1080/100%, failures empty, named source hashes stable. All 26 originals were inspected. HUD, actors, complete intent rows, both full Grimoire bodies and displayed target geometry are readable. Root independently inspected Fire Breath, Earth Claw, Ice Shatter, Air Eye, Lightning Overload and Noct Eclipse.

That inspection found one real copy defect: Eye of the Storm said `Safe within 1` while its compound close bite still hit there. Root authorized removing the redundant safe-gap phrase from all ring tokens in `action_icon_library.gd`; `Ring low–high`, Mantle fuel and its tooltip remain. [pressure-ring-copy-01.json](../output/dragon-revision/pressure-ring-copy-01.json), run `dragon-pressure-ring-copy-01-1790616048821729000-67278-dragon_pressure_ring_cop-1`, session 93706, exited 0 with four Air originals. All four were inspected; Eye now shows exact ring geometry beside the separate bite without claiming safety. Runtime assertions also retain the Ice/Mantle token requirements. Root independently accepted the corrected Eye original. Warning04's old Eye text is superseded by this bounded delta. Later Grimoire copy corrections belong to root and require their own focused receipt.

[pressure-presentation-05.json](../output/dragon-revision/pressure-presentation-05.json), run `dragon-pressure-presentation-05-1790615804990187000-67107-dragon_pressure_presenta-1`, session 35456, exited 0 with 32 validated 1920×1080/100% originals and no witness failures. The expected acknowledgment-write injection is the only error diagnostic. All 32 originals were inspected: service gain/failure/focus and Coil copy remain unclipped, labels clear the banner, actual new secondary fields are retained, and six reduced witnesses stay at rest. The reduced exchange still catches the late fade, so it is not a strong peak-opacity witness; the next probe will record phase/opacity and capture the plateau without changing the cue. The later ring-token edit does not affect these Noct/exchange/Coil paths, so its separate delta is sufficient for that copy change.

## Shadow material quality — v05 rejection and bounded refinement

Root and author agree that v05 does **not** close the user's art complaint. Broad inspection confirms identical paired violet upright curves dominate each affected tile, while the mid-travel Starless release is too faint. The release witness is at progress 0.409, inside the real 0.30–0.52 travel interval; this is not a pre-release sample. Textured cloud interiors and actor depth are improvements, but the repeated glyph-like silhouette is still too mechanical.

The authorized refinement is confined to `dragon_shadow_fx.gd`: seeded, broader smoke lobes with darker interiors and varied edge lighting; a clearer short breath stream; sparse low foreground scraps. Caller-owned geometry, actor depth, timing, rig motion and reduced-motion still behavior stay unchanged. The later v07 and source-view addenda below supply comparable release/impact/dissipation/reduced originals and scoped independent review; their visibility limits remain explicit.

All immutable originals and witnesses are linked by their manifests under `/private/tmp/labyrinth-godot-home/<run-id>/`. Earlier failed/development outputs remain intact. The renderer lease was explicitly released after v05, reacquired only for the focused ring delta, and released after that process exited. Earth native play owns the runtime while the next Shadow revision is prepared.

### V06 failure and v07 material/plateau proof

The helper now layers seeded cloud lobes with offset dark interiors and a broad soft stream spine. No thin per-tile outline remains. The production delta is only `scripts/dragon_shadow_fx.gd`; its release/stream/impact arguments and all caller geometry/timing/depth gates are unchanged. Independent static review of helper SHA256 `e3d4b6760bf7cc7def21fd54ad6c0f447e8295d579ce7d21706f2aa19f430765` found no compatibility, determinism or depth blocker. The primitive count is bounded (background impact 19→13, foreground 3→2, stream 15→21, release 4→9); this is not a measured performance claim, and the larger billows still need overdraw/readability inspection.

The existing presentation probe now observes the real post-draw exchange receipt plateau (phase 0.16–0.70, opacity above 0.98) instead of accepting a timer-based late fade. The production cue behavior is unchanged. A new Starless stream sample at progress 0.48–0.52 complements the comparable 0.40 release and 0.62 impact. Named source hashes are recorded and required unchanged across the run. The stream sampler applies to both breath profiles, producing 34 images (the initial estimate of 33 omitted Night Coil’s additional sample).

[pressure-presentation-06.json](../output/dragon-revision/pressure-presentation-06.json), run `dragon-pressure-presentation-06-1790618455994456000-69415-dragon_pressure_presenta-1`, session 8387, exited 1. Its two failures were the Trade-disabled assertion occurring before the deferred footer refresh in the new immediate-capture path. The assertion now follows the real post-draw plateau capture and still precedes completion; logic-only callers keep their original wait. Production exchange behavior did not change. This failed receipt remains intact.

[pressure-presentation-07.json](../output/dragon-revision/pressure-presentation-07.json), run `dragon-pressure-presentation-07-1790618701750500000-69575-dragon_pressure_presenta-1`, session 90480, exited 0 / PASS with 34 validated originals at 1920×1080/100%, no witness failures and stable named source hashes. All 34 originals were inspected at original resolution. Broad textured billows with varied dark interiors replace the repeated thin U glyphs; the Night Coil release and late stream read as a short smoky tongue. Impact smoke stays behind actors, the small foreground accents preserve feet and damage numbers, and dissipation leaves the board readable. All six reduced cases retain rest poses and declared geometry. Normal, reduced and acknowledgment-retry exchanges are now captured during the fully opaque readable plateau; failure, empty, focus and short Coil states remain clean.

Root independently accepted the material improvement in the v06 Night Coil, Eclipse-darkness and Starless-fan impact originals. The helper is identical in v07. This is stronger material-quality evidence than the rejected v05, but one source-view limit remains: Starless fan at boss anchor `(3,3)` has `origin_visible=false` and `source_visible=false`, although nearby body cells remain visible. Its release/stream screenshots correctly do not bypass that source gate. Night Coil records source visibility true and displays the new stream. A separate five-image addendum is prepared to make Starless’s source visible by a real one-step arrival onto the authored unlit brazier. Its adjacent start/current actor are explicitly staged; held intent, ordinary movement cost, relight and engine visibility must be asserted. No visibility flag or depth rule is overridden. Until that run is inspected, v07 does not claim visible-source Starless acceptance.

Reproduction (fresh namespace and exclusive lease required):

```sh
python3 tools/visual_probe_runner.py tests/dragon_pressure_presentation_probe.gd --task-id dragon-pressure-presentation-07 --no-headless --timeout 90 --min-images 34 --expect-size 1920x1080 --result-manifest output/dragon-revision/pressure-presentation-07.json
```

[pressure-grimoire-01.json](../output/dragon-revision/pressure-grimoire-01.json), run `dragon-pressure-grimoire-01-1790618585207659000-69500-dragon_pressure_grimoire-1`, session 74761, exited 0 / PASS with nine validated 1920×1080/100% pages. Author and root each inspected every original: all complete titles/bodies fit and remain readable; obsolete Overload consumption, Air safe-eye and Ice single-lane claims are removed. These pages are a copy-only delta to Warning04, not a new encounter study.

All Godot processes exited before the runtime lease was explicitly returned to root for native Earth. The first five-image visible-source addendum has since run; its narrow runtime success and remaining pixel limitation are recorded below.

### Visible-source addendum 01 — runtime pass, stream pixel acceptance withheld

`tests/dragon_shadow_visible_source_probe.gd` received separate read-only static review at SHA256 `b923829b59f7c751c85abf342004fcb82847508f639e056b78afdf7828ff436f`. It stages the documented HP/current actor/adjacent legal start and normal movement allowance, then uses production movement for the one-step brazier arrival. It does not override visibility, Light, declared geometry or depth. The reviewer also independently inspected v07 Night Coil stream (source-visible true, progress 0.484848) and reduced exchange (phase 0.166316, opacity 1.0), accepting those two originals for legibility/depth.

[shadow-visible-source-01.json](../output/dragon-revision/shadow-visible-source-01.json), run `dragon-shadow-visible-source-01-1790620085053722000-70509-dragon_shadow_visible_so-1`, session 8467, exited 0 / PASS with five validated 1920×1080/100% originals and no witness failures. All five originals were inspected. The actual move spends one of three movement, relights the authored brazier at `(3,2)`, makes source `(3,3)` visible, and preserves the complete held intent. Normal captures record `source_visible=true`; reduced records rest. Named inputs remain stable.

**This is not a readable Starless stream acceptance.** In this held westward fan, the source and visible endpoint are behind the rear-facing dragon and adjacent acolyte. Release/stream pixels remain almost fully hidden; only a small back-left cloud is exposed at impact. The pass establishes real visibility and valid lifecycle/capture, while the images limit what it proves about the material. The preceding v07 dark-anchor witness remains preserved. No source gate or actor-depth rule was bypassed to make smoke visible, and no production change follows from this observation alone. Root was informed; further placement/depth assessment is read-only pending coordination.

```sh
python3 tools/visual_probe_runner.py tests/dragon_shadow_visible_source_probe.gd --task-id dragon-shadow-visible-source-01 --no-headless --timeout 45 --min-images 5 --expect-size 1920x1080 --result-manifest output/dragon-revision/shadow-visible-source-01.json
```

The exclusive runtime lease was explicitly returned after session 8467 exited, before static image review. No native saves were touched.

### Visible-source addendum 02 — exposed endpoint material, retained actor-depth limit

Root authorized exactly one remaining-budget variant: after real relight at `(3,2)`, use the remaining two ordinary movement to `(1,2)`. The probe asserts both legal requests, costs 1+2, zero remaining movement, retained lit brazier, real source and `(1,3)` endpoint visibility, and the unchanged full held intent. There is no production edit, new Light source override or depth change.

[shadow-visible-source-02.json](../output/dragon-revision/shadow-visible-source-02.json), run `dragon-shadow-visible-source-02-1790620589862757000-71091-dragon_shadow_visible_so-1`, session 25666, exited 0 / PASS with five validated 1920×1080/100% originals, no witness failures and stable named inputs. The lease was explicitly returned immediately after process exit. All five originals were inspected. The late stream now exposes a broad purple billowing tip to the left of the acolyte; contact produces a fuller textured cloud there, followed by clean dissipation and a reduced rest witness. The irregular edges and dark interior match the accepted v07 material, without the former repeated thin U shapes. No clipping or unintended foreground overlay appears.

Most of the source-to-target path still lies behind the actors. This accepts the exposed material and correct depth behavior, **not** an unobscured maw-to-target Starless stream. Source01's occluded view and v07's dark-source view remain honest complementary evidence. No further fixture or art expansion is planned in this bounded task. Root independently accepted v07 Night Coil stream/exchange reduced and agreed with the limited source01 verdict; the separate reviewer then inspected source02 release, stream and impact originals at 1920×1080 and accepted the exposed material with the same occlusion limit. That review also verified actual 1+2 movement, zero remaining, source/endpoint visibility, unchanged held intent and no override/static defect. The reviewer inspected those three images only; author inspection covers all five. No further expansion was requested.

```sh
python3 tools/visual_probe_runner.py tests/dragon_shadow_visible_source_probe.gd --task-id dragon-shadow-visible-source-02 --no-headless --timeout 45 --min-images 5 --expect-size 1920x1080 --result-manifest output/dragon-revision/shadow-visible-source-02.json
```
