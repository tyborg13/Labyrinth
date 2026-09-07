# Surface feedback pass — rules v5

This revision follows the user's first playable inspection. DESIGN.md owns the
current mechanics; COPY.md owns the concise player-facing language. Earlier
v4 playtest and review receipts are historical evidence, not approval of v5.

## Observable acceptance

- Every effect tooltip is a short reminder with nested concepts. Relics describe
  their own changes, without retelling shared hazards or unrelated exceptions.
- Same-area followups show one pattern. Fire precedes the Light continuation;
  radius and duration stay together. Conditions use inline surface icons,
  with no retired intensity block or card overflow.
- Held equipment, magic and item previews keep their intended dimensions from
  the first drag frame through cancellation or equipping.
- Fire is 2 on entry and 3 at actor start; Chilled adds 2 direct damage; Frozen
  triples direct damage until the skipped activation. Passive Bleed/Fire are
  not attacks. Printed direct attacks are 80% of the previous damage, rounded
  half up with a minimum of 1; paid Detonate damage is unchanged.
- Rubble charges departure, including enemy paths, large footprints and
  previews. A fresh positive allowance still permits the first legal step.
- Ordinary Electrified survives Chain and contiguous Lightning use. Stormcoal
  Fire is consumed. Conditional electrical riders and Ion Spool reward actual
  conduction. Reuse and once-per-turn caps survive saving/loading.
- Root Snare retains Rubble and loses Immobilize (Time 4). Shale Burst paints
  its entire attack footprint and displays that footprint once.
- Surface textures remain procedural and hand-animated, with material grain
  and clustered shading that fit the surrounding pixel art.

## Verification and repeatability

Run tools/godot_task_runner.py with task ID board-surface-refactor for Godot
checks; use tools/visual_probe_runner.py for 1920×1080, 100% UI renderer proof.
New focused checks live in tests/surface_feedback_ui_test.gd and its matching
native probe. Existing surface suites, migration tests, presentation tests and
cache-equivalence probes cover the revised rules rather than a second pipeline.

The full card audit is regenerated with tools/board_surface_content_audit.py.
The balance receipt retains the previous card pool/scorer and before/after
scores in output/board-surface-refactor/feedback-pass/balance. Seeded runs use
tools/board_surface_playtest.gd and unique v5 output directories. Material
proof includes all animation phases, direct-versus-retained equivalence,
furnished scenes, reduced motion and matched 24/72-tile timing receipts.

Risk is high because combat timing, movement, balance, saves and UI intersect.
Completion requires full regression checks, reviewed native proof, a committed
branch, separate exact-HEAD peer review and a verified playable fixture. This
revision does not authorize publication to master.

## Follow-up defects found during verification

The seeded Fire run exposed a pre-existing movement commit error: lethal Bleed
before the first step produced a real defeat, but UI and console discarded it
because movement spent was zero. Validated movement now carries `resolved`;
consumers commit the outcome and present in-place damage without dummy travel.
Invalid/stale requests still do not commit. The bounded policy saves and stops
on an unexpectedly rejected walk instead of retrying the same state forever.

Peer review caught conditional text fitting the outer card but crossing its
parchment inset at 220×308. The final layout measures the usable inset and wraps
long conditions; the native probe checks leaf glyphs against that inset.
Preserved unflushed v4 events retain their rules version, while newly recorded
surface events explicitly carry v5, including across a migrated save.
