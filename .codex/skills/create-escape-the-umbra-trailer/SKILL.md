---
name: create-escape-the-umbra-trailer
description: Create, edit, render, or review authentic gameplay trailers for Escape the Umbra using its existing capture and editing pipeline.
---

# Create Escape the Umbra Trailer

Build the trailer around what the current game genuinely does. Use editing to direct attention and improve rhythm; never use it to fabricate a cleaner but false version of play.

## Load The Right Context

1. Use `$parallel-labyrinth-task` for substantive changes and stay in its isolated worktree through inspection.
2. Inspect `marketing/trailer/README.md` and the relevant edit or capture code for the requested change. The existing Remotion renderer remains part of this project; no global Remotion skill is required.
3. Read [creative-standard.md](references/creative-standard.md) for creative decisions and [qa-checklist.md](references/qa-checklist.md) when validating a render or preparing handoff.
4. Read [capture-workflow.md](references/capture-workflow.md) for a new shot, recapture, or gameplay-authenticity fix.
5. Read [edit-grammar.md](references/edit-grammar.md) for timing, camera, text, transition, or audio changes.

For a read-only plan or review, inspect only the files needed to support the decision and stop after the shot, edit, and proof plan. Do not preflight, capture, or render until implementation is requested.

## Preserve Accepted Work

Treat follow-up feedback as a surgical edit unless the user requests a recut.

- Name the affected scene, its source clip, the real action, and the intended viewer focus.
- Keep already accepted timing, copy, footage, transitions, audio, and branding unchanged outside that scope.
- Re-render the complete master after a focused proof passes; a focused render alone is not delivery proof.
- Re-check adjacent transitions even when their code did not change.

## Choose Between Editing And Recapture

Use the existing source only when it contains the complete real action and all relevant pixels.

- Edit when the problem is emphasis, pacing, camera motion, text animation, transition timing, or sound mix.
- Recapture when the room is empty or illegal, a card bypasses production play, UI is already cropped, the map route is implausible, a reward or loadout is shallow, an effect is placeholder-quality, or a light does not mechanically clear the shown Umbra.
- Never crop, scale, or composite around missing gameplay or missing UI and call it cinematic.
- Never use the opening room as filler, a transition buffer, or a hidden underlying scene.

## Build A Shot Contract

Before implementing a new trailer or shot, record:

- the player-facing promise;
- the production source state and why it is legal;
- the visible card, choice, or item that begins the action;
- the action and result the audience must understand;
- the camera's single focus at each phase;
- the reading/action hold in frames or seconds;
- the source and composed proof required.

Reject a shot when its result needs explanation outside the frame. Prefer a smaller action that reads immediately over a spectacular but confusing one.

## Capture Authentic Gameplay

Use the deterministic production capture path; do not reconstruct game screens in Remotion.

```bash
marketing/trailer/scripts/capture-footage.sh <clip-id>...
```

Capture from `RunEngine`, `CombatEngine`, and `RunScene` with generated non-start rooms and plausible deeper-run state. Drive cards through hand selection, targeting, center-stage play, discard, and resolution. Drive merchant, reward, magic, and equipment choices through their production handlers.

Keep the scene hidden until deferred UI has settled, strip unsafe pre-roll physically, and inspect the encoded source before composing it. Follow [capture-workflow.md](references/capture-workflow.md) for the complete contract.

## Compose Around The Real Action

Use one continuous, motivated camera path per action:

- **Card play:** establish the hand card, follow its production move to center, give it a readable close look, then move attention to the board resolution.
- **Choice UI:** approach the options, hold long enough to read, accent the real selection, then pull back once.
- **Magic or equipment swap:** use a restrained approach zoom, follow the real item from source to destination, hold the equipped result, then pull back once.
- **Map traversal:** frame the active rooms and path; move the camera only when the route focus moves.

Do not chain independently eased waypoints, reverse direction without an on-screen cause, or add motion merely because the frame is static. Follow [edit-grammar.md](references/edit-grammar.md) for text, pacing, transitions, and audio.

## Render And Inspect

Verify the runtime first:

```bash
node --version
cd marketing/trailer
npm install
npm run lint
npm run render
```

Inspect the encoded master, not only Remotion Studio. At minimum:

- inspect dense full-resolution frames around every changed action;
- inspect every transition on both sides of its boundary;
- inspect a whole-master contact sheet;
- audit black gaps, frozen holds, audio level, codec, resolution, frame rate, and duration;
- watch the master once at normal speed without scrubbing.

Use the bundled audit utility to make the repeatable technical logs and proof sheets in one pass:

```bash
python3 .codex/skills/create-escape-the-umbra-trailer/scripts/audit_trailer.py \
  marketing/trailer/out/escape-the-umbra-steam-trailer.mp4 \
  --output-dir /private/tmp/escape-umbra-trailer-audit \
  --focus changed-shot:<start-frame>:<end-frame> \
  --boundary-frame <scene-boundary-frame>
```

Use unique filenames for every proof iteration. Follow [qa-checklist.md](references/qa-checklist.md), then obtain exact-HEAD peer-review signoff before user handoff.

## Non-Negotiable Regressions

Block delivery for any of these:

- the retired title or old teaser influences the cut;
- the starting room appears for even a few transition frames;
- gameplay uses synthetic, empty, impossible, or shallow run states;
- a card effect occurs without the natural center-stage card-play animation;
- a showcased kill leaves an arbitrary survivor or uses visibly placeholder effects;
- Umbra light lands where it does not clear darkness;
- options, descriptions, cards, or loadout destinations are cut off;
- the camera obscures, abandons, or oscillates around the action;
- title design resembles generic UI instead of the readable game-native Crumble face;
- acquisition sounds repeat over the progression montage;
- the Steam logo is boxed, detached from the phrase, distorted, or used without its attribution.
