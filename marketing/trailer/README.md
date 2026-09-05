# Escape the Umbra — Steam gameplay trailer

Revision 3 is a 40.6-second gameplay cut built around two coherent tactical turns. Its targeting follow-up removes the redundant board arc while the hand arrow owns player aim. Only the opening gameplay source was recaptured; the approved editor, timing, framing and sound mix remain unchanged. A push and movement set up an area attack; later, Earth reveals hidden targets and lightning jumps between them. Real card rewards, an animated shop purchase, a brief route, and a weapon/deck swap separate the fights. Large captions and a centered Steam wishlist end card remain legible on a phone.

The edit is in `src/Trailer.tsx`. `SHOTS` owns trims, durations, native audio tails and camera framing; composition boundaries derive from it. Captured gameplay uses the production board, HUD, card targeting and effects. Only short editorial captions, their temporary scrims, and camera framing are added.

## Render

```sh
cd marketing/trailer
npm ci
npm run lint
npm run render
```

Output: `marketing/trailer/out/escape-the-umbra-steam-trailer.mp4`. The master is 1920×1080, 30 fps, H.264/AAC stereo with limited-range Rec.709 color. Capture conversion transforms Godot's full-range JPEG/BT.601 samples to Rec.709; PNG render intermediates preserve shadow detail. The render configuration targets H.264 and applies complete color metadata during final muxing. Replace that codec-specific filter before exporting another codec.

Regenerate caption typography with `python3 scripts/render-title-cards.py`. The end card uses the existing menu illustration. Preserve the Steam wordmark source and attribution in `public/branding/README.md`.

## Refresh captures

From the adopted task worktree root:

```sh
LABYRINTH_TASK_ID=<task-id> marketing/trailer/scripts/capture-footage.sh push_bloom spell route merchant equipment root_chain
```

The wrapper serializes native capture with the visual-probe GUI lease and launches Godot through the required task runner. It retains the movie's native gameplay sound, mutes only capture music, physically removes setup frames, and trims audio by the matching 48kHz sample count. Adjacent `.cues.json` files record source frames, game events, legality assertions, native audio metadata and available wall-clock timing. Review these after any animation change before updating edit cuts.

The scenarios use `RunEngine`, `CombatEngine` and `RunScene`, real hand selection/targeting/commit paths, legal combat resources and native enemy health. Card rewards and purchases invoke production actions; the equipment scene swaps an owned reserve weapon and shows the resulting deck. Do not pad incomplete actions with frozen frames. All six shots use natural playback speed. Native SFX share each source's exact video trim, with short reward/purchase tails crossing cuts; the production boss track connects the scenes without reconstructed effect timing.

[EDIT.md](EDIT.md) records the shot contract and verification targets; [RESEARCH.md](RESEARCH.md) records the peer study and the game/edit diagnosis. Inspect the final encoded master before delivery, including cut boundaries and phone-size playback.
