# Escape the Umbra — Steam gameplay trailer

A **31.3-second, gameplay-first cut** of Escape the Umbra. The opening shows a complete tactical card play and environmental payoff. The next action reveals enemies in the Umbra, establishing the game’s distinctive threat before a brief route and two run-building choices. A final area attack supplies the strongest combat payoff, followed by five seconds of title and Steam wishlist call to action.

The edit is in `src/Trailer.tsx`; `SHOTS` keeps encoded-source cue frames and durations together, and `START` defines the composition boundaries. Captured gameplay remains the production UI and board. There is no extra gameplay vignette, artificial particle layer, global flash, or editorial reconstruction of the game.

## Render

```sh
cd marketing/trailer
npm ci
npm run lint
npm run render
```

Output: `marketing/trailer/out/escape-the-umbra-steam-trailer.mp4`. The master is 1920×1080, 30 fps, H.264/AAC stereo with limited-range Rec.709 color. Captures convert Godot’s full-range JPEG/BT.601 samples to Rec.709; PNG intermediates preserve their shadow detail. The render configuration targets this H.264 master and uses an H.264 metadata filter during final muxing to retain complete color tags. Remove or replace that filter before exporting another video codec. Review the encoded video, including normal-speed playback, before delivery.

The title and short captions use pre-rendered game typography. Regenerate finite copy with:

```sh
python3 scripts/render-title-cards.py
```

## Refresh production captures

From the adopted task worktree root:

```sh
LABYRINTH_TASK_ID=<task-id> marketing/trailer/scripts/capture-footage.sh trap_combo umbra route relic equipment aoe
```

The source scenes use the game’s `RunEngine`, `CombatEngine`, and `RunScene`. Tactical cards follow normal hand selection, targeting, center play, and resolution. Progression shows a real relic selection, equipment pickup, and equipment swap in a deeper run. Captures physically remove hidden setup frames before composition. Source timing must be rechecked after animation or layout changes; update `SHOTS` from the freshly encoded clips, not estimated engine timers.

All six source clips must contain the complete visible action and enough real tail for the edit. Do not pad incomplete actions with frozen frames. Tactical shots, map, relic choice, and equipment pickup play at normal speed. A motivated cut removes the idle interval between pickup and the Gear menu; the complete menu swap plays at 0.8× for readability.

## Editorial intent and proof

See [EDIT.md](EDIT.md) for the shot contract, peer baseline, and review targets. The current cut uses hard cuts between tactical scenes, a six-frame dissolve from map to reward, and a twelve-frame dissolve into the end card. Each real card commitment and impact gets one synchronized game sound. The continuous boss score carries the other cuts; menus do not repeatedly play acquisition sounds.

The shadow-dragon art is the existing menu illustration and appears only on the branded end card. It is not presented as gameplay. The Steam wordmark is the approved transparent inverse-white artwork; preserve the source and attribution in `public/branding/README.md`.
