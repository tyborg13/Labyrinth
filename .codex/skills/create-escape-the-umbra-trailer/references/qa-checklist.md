# Trailer QA Checklist

Use this checklist for every complete render. Code review and Remotion Studio playback are not substitutes for inspecting the encoded master.

## Structural Validation

- Confirm `node --version` satisfies `marketing/trailer/README.md`.
- Run `npm run lint` from `marketing/trailer`.
- Run the skill validator when the skill itself changes.
- Run `git diff --check`.
- Confirm only intended source clips, edit files, title art, branding, documentation, and memory changed.

## Source Validation

For every new or recaptured clip:

- inspect frame zero at full resolution;
- inspect the first second densely;
- inspect the action at 10–15 frames per second;
- inspect the final source frames;
- verify production state, UI completeness, and action assertions;
- verify no starting room or deferred overlay appears;
- verify cards use the complete production play path;
- verify environmental, AOE, and Umbra results match their stated purpose.

## Composed Motion Validation

For every changed shot:

- extract full-resolution frames at the start, approach, action start, action midpoint, impact or landing, result hold, and pullback;
- build a dense contact sheet across the entire camera move;
- track the intended focus across those frames;
- reject direction reversals, easing resets, edge drift, clipped UI, unmotivated shake, or zoom that pushes the action out of frame;
- watch the focused proof at normal speed and slower speed.

Use a new filename for every proof render and contact sheet to avoid cached-image confusion.

## Transition Validation

- Extract at least six frames before and after every scene boundary.
- Inspect every contributing frame at full resolution when a boundary looks suspicious.
- Reject black gaps, the starting room, an unrelated room, half-built UI, frozen empty tails, and abrupt scale or position jumps.
- Reinspect all boundaries after duration changes because downstream sequence offsets move.

## Whole-Master Validation

- Run `.codex/skills/create-escape-the-umbra-trailer/scripts/audit_trailer.py` with focused ranges and every changed or adjacent scene boundary. It writes ffprobe JSON, black/freeze/audio logs, the master hash, a whole-master sheet, focused dense sheets, a boundary sheet, and a machine-readable manifest.
- Render the complete master after the focused proof passes.
- Watch once at normal speed without pausing.
- Build a one-frame-per-second whole-master sheet.
- Build a boundary sheet covering every transition.
- Run black detection and inspect every reported interval.
- Run freeze detection and classify every reported hold as intentional reading time, an end-card hold, or a defect.
- Run audio volume analysis and inspect unexpected peaks or silence.
- Verify resolution, codec, profile, frame rate, frame count, duration, audio codec, channel count, and sample rate with ffprobe.
- Hash the final master so reviewer evidence refers to an exact file.

Expected Steam master settings for the current trailer are documented in `marketing/trailer/README.md`; do not silently change them.

## Current-Trailer Regression Matrix

- Opening uses setting/title imagery only and does not imply the shadow dragon is playable.
- Map shows a connected deeper-run route, cleared history, and legal branch choices; the camera centers the active traversal.
- Prebattle footage shows a realistic populated room and readable threat state.
- Environmental combo shows the hand card, center-stage play, real forced movement, and complete intended trap kill.
- AOE footage uses a polished current-build effect and kills every showcased target.
- Umbra footage shows the card and light landing where darkness is visibly and mechanically cleared.
- Merchant footage shows complete purchase options and the real buying animation.
- Relic footage shows all complete choices and the real selection.
- Spell reward footage shows all complete choices and the real acquisition.
- Magic menu follows the acquired spell into an attuned slot and holds the result.
- Equipment footage shows several inventory items, mixed rarities, and follows the acquired item into its loadout slot.
- Progression acquisition sounds do not repeat over the score.
- Narrative cards are readable; “Or will you...” receives a deliberate pause before the title.
- End card reads as one phrase with the transparent Steam logo directly beside `WISHLIST ON`.
- No frame uses the starting room or retired teaser.

## Handoff Gate

- Commit the complete source and reproducible capture inputs.
- Keep scratch proofs and render intermediates out of the commit.
- Obtain a separate exact-HEAD peer review.
- Give the reviewer the master path, master hash, focused proofs, contact sheets, audit results, and user requirements.
- Withhold signoff when proof is code-only, source-only, focused-render-only, or based on a stale master.
- Stop for user inspection before landing or pushing the task branch.
