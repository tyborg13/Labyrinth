# Escape the Umbra — Steam gameplay trailer

A **31.0-second, gameplay-first cut** that moves from an environmental trap into card rewards, an attack that reveals enemies in the Umbra, a brief route, and a real shop purchase. A gear swap leads into air push, traveling earth spikes, and lightning chain attacks, followed by the game title and Steam wishlist call to action. Large centered headlines are designed to remain legible on a phone; combat copy clears before the real center-card play.

The edit is in `src/Trailer.tsx`; `SHOTS` keeps encoded-source cue frames and durations together, and `START` derives composition boundaries. Captured gameplay remains the production UI and board. Temporary title scrims support trailer copy and clear before the action. Gameplay effects, damage, menus, and choices come from the running game.

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
LABYRINTH_TASK_ID=<task-id> marketing/trailer/scripts/capture-footage.sh trap_combo spell umbra route merchant equipment air earth lightning
```

The source scenes use the game’s `RunEngine`, `CombatEngine`, and `RunScene`. Tactical cards follow normal hand selection, targeting, center play, and resolution. Progression includes a real card reward reveal and claim, merchant purchase, and equipment swap in a deeper run. Captures physically remove hidden setup frames before composition. Source timing must be rechecked after animation or layout changes; update `SHOTS` from freshly encoded clips and their logged cues, not estimated engine timers.

Every source must include the complete visible action and enough real tail for the edit. Do not pad incomplete actions with frozen frames. All tactical shots and choices play at normal speed. Later combat cuts remove repeated aiming lead-in and end shortly after the real result. A motivated cut skips room waiting before the Gear menu; the complete menu swap plays at 0.8× for readability.

## Editorial intent and proof

See [EDIT.md](EDIT.md) for the shot contract, peer baseline, typography requirements, and review targets. The cut uses hard cuts between gameplay scenes and a twelve-frame dissolve into the end card. Each real card commitment and impact gets a synchronized production game sound, including the respective air, earth, and lightning attack cues. The boss score connects the scenes; reward, purchase, and equipment sounds accompany their real visible events.

The shadow-dragon art is the existing menu illustration and appears only on the branded end card. It is not presented as gameplay. The Steam wordmark is the approved transparent inverse-white artwork; preserve the source and attribution in `public/branding/README.md`.
