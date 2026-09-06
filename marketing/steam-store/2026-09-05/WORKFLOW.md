# Targeted Steam refresh workflow

This folder owns the store page. The trailer project in `marketing/trailer/` owns the approved cut, captions, camera moves, sound mix and native capture tooling. Keep those decisions unless the requested change concerns them. Use the isolated task workflow for edits; preparing assets and saving a Steam draft do not authorize Git publication.

## Choose the smallest change

| Request | Edit | Rebuild |
| --- | --- | --- |
| Short description or one feature paragraph | `copy.json` | `generate-preview.py`; no capture or media encode |
| Banner illustration | Its function in `banners/dimensional_motifs.py` | `banners/render-banners.py`; review 1170px and 390px sheets |
| Banner wording/frame/font treatment | `banners/render-banners.py` and matching heading in `copy.json` | Banners, then preview |
| Different gallery decision point | The relevant `still_plan` frame/cue offset in `generate-media.py` | Its screenshot from the existing native 4K sequence |
| Different gameplay loop interval | The relevant `loop_plan` interval in `generate-media.py` | Its loop from the existing native 1080p sequence |
| Change a gameplay scenario | The corresponding scenario in `tools/steam_trailer_capture.gd` in the trailer task | Recapture that scene only; rebuild its dependent trailer/store outputs |
| Trailer caption wording | `CARDS` in `marketing/trailer/scripts/render-title-cards.py` | Regenerate typography, then re-export from approved native sources |
| Trailer caption timing, cut or camera tweak | `marketing/trailer/src/Trailer.tsx` | Re-export from approved native sources; no game recapture |

The trailer README documents capture and export commands. A duration-changing cut also requires matching `FRAMES` and `REQUIRED` in `marketing/trailer/scripts/export-quality.py` to the `SHOTS` edit; follow its cut-change checklist. Each archived clip retains its independently verified capture commit, so a new scene can coexist with unchanged older scenes. Preserve native PNG sequences, PCM audio, cue files and frame proofs together. The durable source archive lives with the final upload package, outside disposable worktrees; its manifest identifies the exact files. A final MP4 or FFV1 movie alone is not a replacement for that editable source bank.

## Rebuild and inspect the store page

Run from the store task's repository root. Python 3.9 or newer is sufficient for the store helpers. Gameplay media generation also requires FFmpeg/FFprobe; banner rendering requires Pillow and fontTools.

```sh
python3 marketing/steam-store/2026-09-05/generate-preview.py
python3 -m http.server 9874 --bind 127.0.0.1 --directory marketing/steam-store/2026-09-05
```

Open `http://127.0.0.1:9874/preview.html`. Inspect desktop and phone width. Confirm all headings and body text are legible, every loop starts and ends cleanly, and no media or horizontal overflow is missing. Stop the local server afterward. Do not regenerate gameplay for a text-only edit.

For native media, pass the separate video and still collections:

```sh
python3 marketing/steam-store/2026-09-05/generate-media.py \
  --footage-root /absolute/path/to/source-archive/video \
  --stills-root /absolute/path/to/source-archive/stills
```

See the media README for focused output rebuilds and the exact capture provenance rules. Gallery images must retain native sRGB pixels/profile. Moving footage must retain production timing. Do not extract new gallery images from the delivery MP4, apply a compensating brightness filter, or substitute the 4K still captures as movie footage.

## Prepare only the description uploads that changed

Choose a fresh version suffix and a new output directory. The helper validates manifests, generates the current preview and upload plan, copies verified files, and writes `READY.json` only after every copy passes its hash check.

```sh
python3 marketing/steam-store/2026-09-05/prepare-upload.py \
  --destination /private/tmp/umbra-steam-next-pass \
  --asset-version v3 \
  --changed-description-only
```

`about-assets/` contains only banners/loops whose current bytes differ from the recorded uploaded hash. Screenshots remain numbered in gallery order. `reference/upload-plan.json` supplies section order and accessibility text. An existing destination is refused so a new package cannot silently mix old and new files.

Add `--trailer /absolute/path/to/reviewed-trailer.mp4` when this pass changes the trailer. Use the verified Steam-compatible delivery file; retain the lossless archive separately. Remove `--changed-description-only` to prepare all description assets.

## Save the Steam draft

1. Use the user's authorized Chrome profile and Steamworks app **4530510**, store admin **1134255**. Confirm the game and account on screen. Open Description.
2. Under Upload Custom Images, use **Select file**, choose the prepared `about-assets` files, then click **Upload**. Verify Success and the actual uploaded group names. English suffixes group the assets correctly. Do not discard unrelated pending uploads. If Steam reports upload-URL or conversion-start request failures, inspect the visible error and refresh the saved session before retrying the same files; the September 6 session failure cleared this way. Do not infer a codec or size problem from a request failure.
3. Use **Edit Accessibility Text (Alt Text)** and save the plan's text. Banners need their heading as alt text. Verify the dialog closes and the values persist.
4. Record each actual observed group reference in `steam-asset-refs.json`. Banner mapping values are `{STEAM_APP_IMAGE}/extras/<observed-group>`. Silent animation mapping values are the complete `[img]...[/img]` markup observed in this uploader. For the same placeholder, record the exact uploaded file SHA-256 in `uploaded_sha256`. Never copy a new local hash onto an older upload reference.
5. Generate the final plain-editor text only after those records match:

```sh
python3 marketing/steam-store/2026-09-05/generate-preview.py --resolve-steam
```

Ordinary preview generation invalidates the previously generated final BBCode file. Only successful resolution recreates it. The command rejects missing/stale uploaded hashes, malformed references and unresolved placeholders. Paste `description.bbcode.txt` into About This Game. For Short Description, real typing followed by Tab is the verified route: a plain fill previously failed to update Steam's localized value. Click Save, reload, and verify both exact saved values.

6. Reload the actual Steam beta preview. Inspect all four banners and five animations; check silent playback, colors, desktop/phone readability and the campfire section after expanding Read More. Uploaded media can be transcoded, so local proof alone is insufficient.
7. Review the Steam publication diff. Publishing is a separate action from saving this draft. Preserve unrelated store settings and prior public assets until the replacement set is verified.

### Trailer and gallery upload handoff

In September 2026, the legacy trailer replacement and gallery drop zones exposed no working file chooser to browser automation. Ordinary custom-description asset uploads worked. Repeated native drag attempts did not deliver files; the Chrome Downloads fallback was explicitly security-blocked. Preserve this limitation instead of repeating failed approaches or bypassing the block.

Use the prepared trailer and eight ordered PNGs for the manual legacy upload handoff. Verify processing, full-resolution playback, gallery order and accessibility before publication. Mark this step pending until the actual Steam UI confirms completion. Do not infer an upload from the existence of local files.

## Final verified package

Once uploaded references are recorded and the final preview passes:

```sh
python3 marketing/steam-store/2026-09-05/prepare-upload.py \
  --destination /absolute/path/to/new-final-package \
  --asset-version v3 \
  --with-resolved-copy \
  --trailer /absolute/path/to/reviewed-trailer.mp4
```

Keep the final package, editable native source archive, final video quality report, store media manifest and exact reviewed source commits together. Commit the isolated branches and obtain separate peer signoff on those exact heads. Do not push, land or clean up without the user's explicit publication approval.

For mobile trailer delivery, the authorized Drive account is **mtborg13**, not Karen. Upload the reviewed compatible MP4, verify processing and ownership, and retain its direct file link. Do not change sharing settings beyond the user's authorization.
