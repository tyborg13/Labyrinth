# Guardian feedback pass — revision 2

This pass repairs attack planning and hand presentation, gives the six encounters sustained helper pressure, replaces placeholder attacks with recognizable cutout motion, aligns map outlines to their emblems, and limits enemy/relic descriptions to relevant mechanics.

## Behavior and regression evidence

- Direct bites, pounces and shots use the live native target planner. Authored ground patterns keep their declared tiles and lose their attack when the required approach is interrupted. Their geometry uses real walls and terrain. Tests reproduce the original empty-target bug and cover blocked approaches, broken Fire lanes, missed sword strikes leaving Fire, and outcrop removal changing the quake.
- Helpers advance on every intent, favor complementary safe attack positions, and avoid their Guardian’s held approach. A missing roster helper is announced on the next declaration, at most one replacement per activation and two living helpers total. Tests cycle five replacements in every encounter and check the cap, spawn reservation and zero repeat rewards.
- Cantor and Tender extend the same electrical network toward the target; Peal uses the complete connected component. Tests check actual damage, Shock, visible network coverage and network persistence.
- The original Storm Cantor log exposed a freed proxy being assigned before validation. A second native reproduction found stale staged-card identities leaving the hand hidden after unlock. The pool now rejects duplicate releases and freed entries; unlock restores authoritative hand controls. `logs/hand-lifecycle-before.log` is the expected failing reproduction and `logs/hand-lifecycle-after.log` is the passing fix.
- A retained board now replaces an enemy-ID renderer when the next encounter uses a different character type. The continuous native probe checks rendered identity on every sampled frame.

The full Godot suite, focused Guardian contracts, proxy lifecycle checks, motion contracts, icon identity policy and production-only package runtime pass. See `logs/`. The full suite predates only the final one-line restriction of fixed-surface explanatory text; affected Guardian contracts and all expanded panels were rerun after that correction.

## Real renderer review

`gameplay-review/capture-summary.json` records 36 complete sequences: four passes and two real card plays in each of six encounters, retaining one RunScene throughout. All thirteen authored actor actions were observed. It contains 5,631 timed native frames over 218.24 captured seconds at 1920×1080, 100% UI scale. The probe checks once-only damage, return of input, live hand visibility and actor identity. The 999 HP/extra vision settings are confined to this art-observation fixture; playable inspection saves and balance trials use normal stats.

The retained captures include settled hands, Reaver Fire appearing during recovery, a claw contact, a connected Tender hit, and a Fledgling peck. `inspection-final/` contains all fourteen expanded enemy panels with concise rules and visible complete move amounts. `map-final/` contains selected, reachable, visited and current states for all six actual emblems. Every map-choice fixture is adjacent to its Guardian.

Descriptions contain unique behavior, timing or limits. They do not give tactics or repeat standard victory, summon reward, status or surface rules. Named objectives use their title alone. The shared UI rubric records that policy. Fixed-pattern surface notes are restricted to those authored ground attacks, rather than ordinary Ice attacks.

## Cutout review

The source paint and front/rear registration remain protected. Editable v02 cases are retained under `experiments/cutouts/<actor>/v02/`. Reaver swings its rigid sword; birds wind back and peck; quadrupeds lift and swipe a foreclaw; casters use their staffs, lanterns and hands. All recover to rest. Idle motion is a coordinated body bob with planted supports; the no-ripple rule is recorded in the cutout skill and specification.

`animation-review/` contains fixed-camera full-cycle contact sheets. `proof-summary.json` identifies the final native exports, timed reels, editable scenes, input/output verification and pixel-identical save/reload counts. Raw reproducible renders remain under the ignored `cutouts/` directories; earlier proof is retained, never overwritten.

## Balance and inspection

The revised scorer assumptions and `spec/guardian_combats/balance_evidence.json` retain 18 matched one-seed policy observations: eleven victories, seven defeats, no bounded stalls, and 39 helper replacements. The same baseline cases had seventeen victories. Early mixed builds still won every encounter, with 3–24 HP remaining. These measure regressions and pacing, not human win rates or full-run progression.

`tools/guardian_inspection.py --all` creates 39 standard reload-verified saves: all six previews, encounters, relic studies, helper replacement declarations and adjacent map choices, plus entry/reward/outage/outcrop/network/summon/telegraph moments. The final catalog is regenerated against the reviewed HEAD before handoff.

Residual limits: native Windows execution is unavailable; typed-array paths were reviewed and tests run on macOS. Human balance/animation inspection remains the next step. Existing full-suite migration and shutdown warnings are unchanged. Publication and cleanup await explicit user approval.
