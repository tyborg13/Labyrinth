# Steam gameplay media — revised 6 September 2026

Eight genuine 3840×2160 native gameplay screenshots and five silent 1920×1080, 30 fps description loops. The gallery renderer keeps the same 1920×1080 logical layout and 100% UI scale while rendering at 2× resolution. Moving footage is recorded at native 1080p to preserve production animation timing. The gallery leads with tactical decisions and payoffs, then shows rewards, purchases, equipment, revealed threats and the route map. Accessible captions live in `media-manifest.json`; no marketing copy is baked into the gameplay.

The combat loops show Updraft → move → Cinder Bloom, and Root Snare → light reveals adjacent enemies → move → Chain Bolt. Reward and shop loops show their real acquisition feedback. The fifth loop shows the production campfire choices and recovery. Each retains natural timing and the complete game frame, with an ordinary cut at the restart.

## Reproduce

Run the generator against the approved native video captures (seven cue/PNG sequences) and separate 4K gallery captures (six cue/PNG sequences):

```sh
python3 marketing/steam-store/2026-09-05/generate-media.py \
  --footage-root /absolute/path/to/lossless-video \
  --stills-root /absolute/path/to/native-4k-stills
```

The cue metadata records each sequence path and its source-frame offset. The generator requires native 1920×1080 video frames and genuine 3840×2160 gallery frames, both RGB PNG with explicit sRGB metadata. It validates every usable frame and records a digest of the indexed frame hashes. Gallery files are byte-for-byte copies of selected native frames. MP4 review proxies are not inputs. The manifest records cue and output hashes, frame bounds, dimensions, and the source repository revision/dirty state at generation. Actual capture origins (including dirty capture state and captured script hashes) stay attached to every source independently of the final reviewed commit. Both video and still archives have their own collection digest and reviewed binding; a video-only refresh does not require regenerating unchanged, separately reviewed stills. Each collection also preserves `reviewed_capture_heads` per clip, allowing unchanged clips to retain an older verified capture commit after a one-scene recapture. The legacy top-level `source_repository_head` refers to the video bank, while `screenshot_collection_provenance` records the still bank. Native frame checksums must match the original capture RGB round-trip proof; the renderer must be Mobile and the offscreen viewport must inherit the game root’s MSAA. The preserved `native-collection.json` supplies the reviewed capture revision after relocation, so an archive inside a different checkout is not mislabeled with that checkout’s HEAD. The final reviewed source commit is bound at handoff.

Description loops encode once from lossless native 1080p RGB into near-lossless H.264 CRF 1 with 4:2:0 chroma for browser compatibility. The separately captured 4K gallery sequences never feed moving footage: recording them continuously exceeded the frame-time budget, so their timing is unsuitable for video. Metadata explicitly describes limited-range BT.709 primaries/matrix and the native sRGB transfer. There is no exposure, brightness, contrast or gamma adjustment. Video is a compatibility encode; the original RGB PNGs remain the lossless source.

The old screenshots inherited a BT.709 transfer cICP tag from compressed video, unlike the renderer's native sRGB PNG. An identical-pixel managed Chrome comparison demonstrated that this profile mismatch darkened the old screenshots. Fresh native grayscale references and browser image/video comparisons establish the correction. The final five loops compare all 973 frames at 63.47–68.43 dB encoder-only PSNR against the same native RGB-to-YUV conversion; sampled RGB differences are under 1.32 code values on average, including chroma subsampling. Proof is in `build/refresh-steam-store-page-with-tactical-media-and-copy/proof/color-fidelity/`. The compact native/browser baseline, final quality reports and inspection contact sheets are also hash-verified under the main checkout’s `output/steam-store-refresh-2026-09-06/proof/color-fidelity/`, so they survive task cleanup.

## Native color reference

After changing capture or export code, run the reusable probe from the game task checkout. Set the task ID to that checkout's active task; keep the existing native dimensions and UI 100% acceptance:

```sh
MEDIA_TASK_ID=wishlist-visual-polish-and-steam-trailer
python3 tools/visual_probe_runner.py tests/steam_media_color_probe.gd \
  --project . --task-id "$MEDIA_TASK_ID" \
  --no-headless --display-driver macos --audio-driver Dummy \
  --rendering-method mobile --rendering-driver metal \
  --expect-size 1920x1080 --expect-size 3840x2160 --min-images 2 \
  --result-manifest "build/$MEDIA_TASK_ID/proof/media-color-reference.json"
```

It loads a static production combat scene, inherits the root's MSAA, renders both real raster sizes at the same logical layout, and asserts exact native RGB values for eleven grayscale anchors. Its proof-only swatches must not appear in marketing assets. Inspect the exported references and a matched encoded/browser frame; preserve the explicit sRGB profile and native RGB values. Do not infer display fidelity from decoded RGB averages alone or apply compensating gamma to the game. A fresh source capture must additionally pass the capture helper's full native RGB/PNG round-trip proof.

## Small targeted rebuilds

For capture, copy, banners, trailer edits, Steam uploads and publication checks, follow [WORKFLOW.md](WORKFLOW.md). Reuse the surviving native collections under `output/steam-store-refresh-2026-09-06/source-archive/{video,stills}` after the source worktree is removed. Cue patterns and frame/proof references are relative to their collection, so moving the verified collection does not change its bytes.

Change the relevant `still_plan` cue/offset to choose a different gallery frame, or `loop_plan` bounds to change one loop. Then rebuild only the affected filename stem. For example:

```sh
python3 marketing/steam-store/2026-09-05/generate-media.py \
  --footage-root /absolute/path/to/source-archive/video \
  --stills-root /absolute/path/to/source-archive/stills \
  --only 01-line-up-the-cross

python3 marketing/steam-store/2026-09-05/generate-media.py \
  --footage-root /absolute/path/to/source-archive/video \
  --stills-root /absolute/path/to/source-archive/stills \
  --only 03-shop-and-grow
```

`--only` accepts one or more output stems, also accepting their `.png`/`.mp4` filenames. It needs a complete current manifest from an earlier full build. Untouched outputs keep their existing bytes only if their file hashes, selected frame/interval, alt text, and source/cue/native-proof hashes still match. If a source capture changes, include every dependent output or run a full build. The command explains which omitted output needs rebuilding rather than giving stale assets new provenance. All source frames remain verified even for a partial rebuild; only selected output files are copied/encoded.

To adjust a scenario, recapture only that scene using the trailer harness documented in `marketing/trailer/README.md`. Preserve old takes before capture; use the exact same renderer/profile/timing checks. Rebuild its affected store outputs, then run `generate-preview.py`. A text-only or banner-only change needs no gameplay capture or media encode. After any change, review the affected output at its native size and in the desktop/phone page before preparing uploads.

## Steam constraints checked

Gallery images are genuine 16:9 gameplay and exceed Steam's 1920×1080 minimum and five-image minimum. They contain no added marketing overlays. [Valve screenshot documentation](https://partner.steamgames.com/doc/store/assets/standard).

The extra-asset uploader accepts MP4/WEBM and supports images up to 4096 px wide. It recommends 1170 px width for the 780-logical-pixel column and caps animations at 12 seconds. These 1080p videos preserve detail for larger/fullscreen viewing and carry explicit color metadata. [Valve extra-asset documentation](https://partner.steamgames.com/doc/store/page/assets).

Valve's description guidance discusses image and page download budgets; it does not establish a 5 MB per-video limit. Per the user's quality priority, no arbitrary 5 MB individual or 15 MB combined local budget is imposed on these masters. The generator enforces documented dimensions, duration and codec/profile properties. [Valve description guidance](https://partner.steamgames.com/doc/store/page/description).

Steam transcodes uploaded media. Verify actual uploaded playback, colors, text and ordering before publication.
