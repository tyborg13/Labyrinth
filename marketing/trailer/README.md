# Escape the Umbra — trailer workflow

The approved edit is 1,219 frames at 1920×1080/30 fps (40.63 seconds). It tells two continuous tactical stories around card rewards, a purchase, a short map shot and a weapon/deck swap. `src/Trailer.tsx` owns `SHOTS`, captions, camera keys and audio tails. Preserve that edit when the request is only a visual fix. `EDIT.md` records its shot contract; `RESEARCH.md` preserves the original genre research.

## Make a small edit

Work in the adopted task worktree and follow its contract/preflight/inspection workflow. Native Mac capture needs Godot, FFmpeg/ffprobe and Python3; editing needs Node/npm. Run `npm ci` once in `marketing/trailer`.

For a caption change, update the owning text in `scripts/render-title-cards.py`, regenerate it, and review the changed title PNG. For a cut or camera adjustment, edit only the corresponding `SHOTS` entry in `src/Trailer.tsx`. Existing verified native footage is reused:

```sh
cd marketing/trailer
python3 scripts/render-title-cards.py  # only when caption typography changed
npm run lint
npm run render -- --version v6
```

The default `npm run render` is the quality pipeline. `npm run render:preview` retains the older compressed-MP4 preview route. Use a new version label for a new reviewable delivery; it selects `out/quality-v6` and versioned filenames. Caption, trim, camera and mix changes require a fresh render. `--reuse-render` is only for re-encoding an already rendered, unchanged PNG/PCM edit; it rejects any changed source, editor, asset, cached PNG or cached WAV.

## Replace one gameplay scene

From the worktree root, replace only the affected clip. This leaves the other native scenes intact:

```sh
python3 marketing/trailer/scripts/capture-movie.py push_bloom \
  --task-id wishlist-visual-polish-and-steam-trailer \
  --lossless --render-scale 1 \
  --output-dir marketing/trailer/public/footage/lossless \
  --archive-existing
```

Use the actual current task ID after moving to another worktree. Valid current edit clips are `push_bloom`, `root_chain`, `spell`, `merchant`, `route`, and `equipment`; `campfire` is the additional store-page loop. `--archive-existing` moves the prior clip's PNGs, PCM, cues, proof and proxies to `build/<task-id>/proof/trailer/native-history/` before recording. Without that flag, a nonempty native clip directory is rejected. A failed take stays unapproved; its archived predecessor remains recoverable. Capture and export lock the selected source collection so frames cannot change during a render.

The scene contract fixes the actions and timing, while reward/shop offers come from the real generated run and current progression/loadout. The shop selects the first valid magic offer and records the purchased ID in its cues. Compare those IDs after a recapture; do not promise identical incidental stock across capture revisions. Reuse the archived clip when the request does not change that scene.

The wrapper acquires the native GUI lease and runs Godot through `godot_task_runner.py`. It uses Metal/Mobile, inherits the production root viewport's 2D MSAA, fixes logical layout at 1920×1080/100% UI scale, and records real production actions. Only music is muted. A bounded eight-frame queue spools the actual gameplay SubViewport's RGB bytes; PNG compression happens after gameplay finishes. Native MovieMaker PCM is trimmed at exactly 1,600 samples per removed 30 fps pre-roll frame. The small MP4 beside a native collection is a review proxy.

`--render-scale 2` renders genuine 3840×2160 with the same logical layout. It is useful for static gallery images. Motion takes must pass wall-clock timing review; the current approved trailer uses native 1080 because 2× capture exceeded the realtime budget. Capture-only frame pacing prevents fast fixed-clock recording from stretching production wall-clock effects. Recognition holds retain the approved idle selection cues; they never stretch an attack or movement animation.

## Sources and provenance

Each native collection contains `<clip>/frame00000000.png` onward, `<clip>.wav`, `<clip>.cues.json`, `<clip>.capture.log`, and `<clip>/native-rgb-framemd5.json`. The cue pattern and PCM references are relative to the collection root. Direct PNGs already omit pre-roll: `lossless.source_frame_offset=0`; `safe_start_raw_frame` applies to the original audio carrier only.

The native proof records every original RGB frame digest, every explicitly-sRGB PNG byte hash, actual renderer/MSAA, queue bounds and wall timestamps. Export validates the current files against those records and checks the approved video/audio coverage. PNG sRGB metadata is inserted without changing IDAT samples. The final upload converts RGB to limited-range Rec.709 YCbCr and explicitly signals the native sRGB transfer; it does not apply an artistic gamma adjustment.

The editable source bank must survive worktree cleanup. Copy it to the durable output folder with verification:

```sh
python3 marketing/trailer/scripts/copy-native-sources.py \
  marketing/trailer/public/footage/lossless \
  /Users/borgerding/workspace/Labyrinth/output/steam-store-refresh-2026-09-06/source-archive/video
```

Restore that bank into a later adopted worktree by reversing source and destination:

```sh
python3 marketing/trailer/scripts/copy-native-sources.py \
  /Users/borgerding/workspace/Labyrinth/output/steam-store-refresh-2026-09-06/source-archive/video \
  marketing/trailer/public/footage/lossless
```

After the final source commit, add `--reviewed-source-head <commit>` to the copy command. The helper verifies every captured script against that commit and records the reviewed binding separately from the original capture-time HEAD/dirty state. It never relabels the capture history.

Copying verifies all retained bytes and preserves relative cue references. Restoring an existing archive also retains and verifies its reviewed source binding when no new override is supplied; the referenced commit must remain available in the repository. A different existing destination bank is rejected; choose a new versioned folder. Keep the source archive as well as the completed movie: the completed movie alone cannot support a clean one-scene replacement.

## Export and inspect

`export-quality.py` renders the same edit from native PNGs and PCM, retaining the original gameplay sound and production soundtrack. It writes:

- `escape-the-umbra-steam-trailer-v5.mp4`: H.264 High, 8-bit 4:2:0, veryslow/CRF1, AAC 320kbps. This is the compatible Steam/mobile delivery.
- `escape-the-umbra-v5-lossless-rgb.mkv`: FFV1 RGB plus unchanged mixed PCM. Every decoded RGB frame and PCM sample is checked against the assembled PNG/WAV edit.
- Render-input binding, source fingerprints, output hashes, ffprobe records, decode logs and audio loudness measurements in the same versioned output directory.

The MP4 is an extremely high quality single-generation encode; 4:2:0 and AAC remain lossy. Steam transcodes uploaded trailers. Valve recommends the highest available resolution up to 1920×1080 and prefers H.264/AAC in supported containers: [official Steam trailer guidance](https://partner.steamgames.com/doc/store/trailer?l=english). Preserve native resolution and timing instead of upscaling an encoded movie.

Before handoff, inspect changed source recognition/aim/commit/impact/settled frames and compare their cue times with `SHOTS`. The lightning close-up finishes at source 265, before first contact near 267. Ensure the source covers every visual trim and native audio tail. Watch the full encoded MP4 at natural speed, check cut boundaries, and inspect both native-size and phone-size framing. Compare matched native/source/master pixels for sharpness and managed-display color; a source-to-master comparison alone cannot detect earlier capture loss. Read the decode and loudness logs and preserve the exact reviewed hashes.

Focused pipeline checks:

```sh
python3 marketing/trailer/scripts/test-quality-guards.py
python3 tools/godot_task_runner.py --task-id wishlist-visual-polish-and-steam-trailer --stream -- \
  godot --headless --path . --script tools/test_steam_trailer_frame_sink.gd
```

The checks cover changed-native and stale-cache rejection, exact RGB thread draining, failed disk writes, and bounded queue behavior. Broaden game tests only when game code changes require them. Retain separate exact-HEAD peer review and user inspection/publication approval under the repository workflow.
