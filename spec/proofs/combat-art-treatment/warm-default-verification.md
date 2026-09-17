# Warm default verification — 2026-09-17

## Requirement and design

Warm applies to all combats by default. All five approved looks remain in a central, extensible registry with their original numerical values. No encounter-specific routing is active. The user wants durable source, artifacts and instructions, then a normal playable inspection over several combats before deciding whether to publish.

Focused UI design statement: the surface is the combat world art. The player still chooses movement/cards/targets using the same HUD, silhouettes, rules text and supported inputs. Warm supplies the shared grade and local lighting without adding a player-facing control. Proof covers native 1920×1080 at 100%, the real generated three-enemy fixture, targeting/controller focus/cancel, movement, reduced motion and board reuse.

## Implementation and durability

- `scripts/combat_lighting_profiles.gd` is the authoritative five-look registry, with `DEFAULT_ID = "warm"`, typed ID enumeration and copied definitions. `CombatArtTreatment` selects it on construction and retains the selection as room sources/elemental ambience change.
- Empty/invalid development environment overrides fall back to Warm. Valid overrides and the root-board setter remain intentional inspection tools, documented without adding automatic encounter variants.
- Warm numerical uniforms also replace the shader's unconfigured fallback. No additional rendering pass, source loop, per-frame work or gameplay/save rule is introduced.
- `spec/combat_art_treatment.md` provides ownership, every tuning field, extension rules, future per-encounter integration guidance, exact capture recipe, required tools, reference/proof links and separate reset/resume commands.
- `tools/combat_lighting_comparison.py` and its standalone HTML template reconstruct the profile chooser and optional 12-second, 60-fps, silent Warm wipe. All profile choices come from probe metadata. Source/output hashes and the ffmpeg filter/command are emitted.
- `reference/` commits all fifteen native screenshots and `lighting-capture.json`, so any agent can rebuild the artifacts without this task's temp files or access to Discord/OBS. The original source art and game font were already committed. Historical performance workload/data and the earlier implementation proof remain in this directory.

## Proof

Artifact root: `/Users/borgerding/.codex/visualizations/2026/09/17/01a0acec-2bc4-7051-8564-94947a7a7951/combat-art-treatment/warm-default-v1/`.

- Full `tests/run_tests.gd`: **PASS**, exit 0, including the new lighting profile suite. It checks ordinary/default and explicit selection, all five preserved IDs, all numeric fields reaching all three materials, per-element reconfiguration, invalid IDs and definition-copy isolation. Existing legacy migration and ObjectDB shutdown warnings remain. `full-suite.log`.
- Native `tests/combat_lighting_variants_probe.gd`: **PASS**, fifteen 1920×1080 captures, Metal Mobile on M5 Pro. Accepted receipt: `capture-v6-manifest.json`, `capture-v6.log`. All fifteen images were inspected at native resolution. The full lighting-input dictionary from ordinary startup exactly matches explicit Warm. Ambient particles are pinned through the existing presentation time seam for the fixed A/B capture; whole-frame equality is not claimed because existing torch motes sample wall time and cutouts finish deferred startup. The mean image difference is recorded as diagnostic only.
- The original realism guards pass: genuine combat metadata, original topology/spawns/loot, no merchant props and disjoint passable footprints. Negative guards reject a forced merchant room and stacked actors. The player move is engine-resolved from (1,4) to (1,3).
- All five looks remain visually distinct, with sampled backdrop/cards/HUD unchanged between looks. Each deliberate selection rebakes the floor once. Warm flicker does not rebake it; reduced-motion lighting remains exactly fixed. Movement selection, legal hover, controller focus and cancel remain available.
- Same live RunScene replaced by three independently generated combats through normal RunEngine entry: Warm stays active without selecting a new look. These are presentation transitions, not evidence that an automated player won three combats.
- Native `tests/combat_art_treatment_probe.gd`: **PASS**, eight 1920×1080 captures. Covers Warm cached/direct equivalence, five/six light sources, source-alpha preservation, untagged feedback, targeting, partial Umbra clipping and normal motion. `art-manifest.json`, `art-probe.log`.
- Reconstruction from the committed-path native reference set: **PASS**; HTML contains all five choices with Warm initially selected, and the 4.1 MB MP4 fully decodes. Chrome inspection confirmed profile switching, the 75% wipe and Warm-only view. `comparison/reconstruction.json`, `render-command.json`, `render.log` preserve reproduction inputs/output hashes.
- `git diff --check`: **PASS**. Local Markdown targets in the owning guide and reference index resolve.

The strict initial whole-frame equality experiment failed on wall-clock/deferred presentation effects. It was replaced by exact live lighting-input equality (the actual default-selection requirement) while retaining the image diagnostic, real screenshots and shader/cache/alpha proof. Earlier failed capture receipts are not accepted evidence.

## UI rubric

| Affected gate | Result |
| --- | --- |
| Immediate comprehension, hierarchy, gameplay visibility | Pass: unchanged HUD/actions, readable actors, targets and floor marks in Warm. |
| State/consequence and interaction | Pass: existing legal target, pointer-hover, controller focus and cancel paths; engine-resolved movement; no routing changes. |
| Cohesion | Pass: original approved Warm settings across every combat; shared existing materials and intent identities. |
| Accessibility | Pass: stable reduced-motion lighting and existing non-color tactical cues. |
| Copy/layout resilience | Pass: no gameplay copy, type, geometry or new icon changes; native 1920×1080 inspection. |
| Visual proof and realism | Pass: fifteen inspected native references plus renderer integration probe and verified natural fixture. |

## Play inspection and limits

Initial fixture: seed 62001, room (1,1), Hollow Grotto, before the first action. Normal 24 HP, generated hand, three natural enemies, crates, traps and loot. The run remains playable onward through rewards/map/other combats. Namespace: `combat-warm-play-20260917`; Steam disabled and isolated from the user's normal save. The guide contains self-healing restart and progress-preserving resume commands. The fixture is regenerated/verified again after exact-HEAD peer signoff before interactive launch.

Background integration remains deferred. No new hardware performance claim: the historical matched benchmark used Balanced on M5 Pro and reproduced three pre-existing Umbra equivalence failures on both sides. Warm only changes values in that existing rendering path. Windows/Steam Deck performance is still unmeasured.

Local commit and separate peer review precede the user handoff. No push or landing is authorized by this report; the user explicitly requested play inspection first.
