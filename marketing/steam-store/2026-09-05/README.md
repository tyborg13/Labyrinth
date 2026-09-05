# Steam gameplay media — 5 September 2026

Eight native 1920×1080 gameplay screenshots and four silent 30fps description loops. The gallery leads with tactical decisions and payoffs, then shows rewards, purchases, equipment, revealed threats and the route map. Captions are supplied as accessible alt text in `media-manifest.json`; no marketing copy is baked into any image.

The two combat loops contain complete legal sequences: Updraft → move → Cinder Bloom, and Root Snare → light reveals adjacent enemies → move → Chain Bolt. Reward and shop loops include the acquisition animation and a settled result. All loops retain the full gameplay frame and its UI. They restart with an ordinary cut; there is no reversed gameplay, artificial camera move, or time compression.

## Reproduce

Run from this store task worktree with the approved native footage directory:

```sh
python3 marketing/steam-store/2026-09-05/generate-media.py \
  --footage-root /Users/borgerding/workspace/Labyrinth.worktrees/wishlist-visual-polish-and-steam-trailer/marketing/trailer/public/footage
```

The generator resolves screenshot and trim frames from the capture cues, records hashes of every source MP4/cue file and output, and checks source bounds, dimensions, native frame rate, BT.709 metadata, silent output, and a combined description-loop budget below 15MB. It requires Python3, ffmpeg and ffprobe. The original footage is an input, never modified by this generator.

## Steam requirements checked

- Gallery assets are actual gameplay at 1920×1080, 16:9. Steam requires at least five; rewards, purchases and equipment show distinctive parts of the game. Review age suitability in Steamworks individually before marking qualifying images. [Valve screenshot documentation](https://partner.steamgames.com/doc/store/assets/standard?l=english).
- Steam's description asset uploader supports MP4/WEBM as well as GIF. It recommends 1170px width, requires animations no longer than12seconds, and recommends BT.709 metadata. These MP4 loops preserve smooth motion efficiently. [Valve extra asset documentation](https://partner.steamgames.com/doc/store/page/assets?l=english).
- The description guidance keeps individual images below5MB and combined screenshot/GIF media below15MB. These four loops also stay below both budgets. Gallery images are separate from description media. Any additional description banners or stills must be counted in the page's final combined media budget. [Valve description documentation](https://partner.steamgames.com/doc/store/page/description?l=english).

Steam transcodes uploaded media. Preview the final page after upload to verify playback, colors, ordering and accessible text.
