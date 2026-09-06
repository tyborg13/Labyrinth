# Description preview and upload plan

`copy.json` owns the English short description, introduction, sections and their actual local media paths. `generate-preview.py` synchronizes `description.md` and `short-description.txt`, then creates:

- `preview.html`: live text, four heading banners and five silent autoplaying loops. The description column is 780 logical pixels wide, with Steam's dark blue background, ordinary sans-serif description text and 16px narrow-screen gutters. The short description appears separately above the article as a review aid; Steam places it elsewhere on the actual store page.
- `description.bbcode.template.txt`: the complete About This Game text and nine media placeholders. Banner placeholders take the actual uploaded asset reference. Animation placeholders take the complete embed markup observed in Steamworks.
- `upload-plan.json`: app 4530510, English copy, eight gallery entries in order, four banner and five animation uploads, exact alt text, section ordering and file hashes.

Regenerate after any copy, banner or media-manifest change:

```sh
python3 marketing/steam-store/2026-09-05/generate-preview.py
python3 -m http.server 9874 --bind 127.0.0.1 --directory marketing/steam-store/2026-09-05
```

Open `http://127.0.0.1:9874/preview.html`. Relative media paths allow this folder to move as a complete bundle. Generation checks source hashes, expected asset counts, loop references and the short-description length. There is no arbitrary aggregate file-size budget. The revised short description has 217 characters.

The September 6 revision replaces scenario narration with broad explanations of positioning, equipment-based decks, relic interactions, elemental intensity, darkness and run decisions. The campfire section now includes its own real gameplay loop. The custom heading frames and Crumble type are retained; only their left-hand illustrations were refined with dimensional shading and softer light.

The gallery is copied from genuine 4K renderer frames with explicit sRGB metadata. Animations are encoded directly from separate native 1080p lossless captures, preserving the production animation timing. See `README.md` and `media-manifest.json` for color, capture and encode provenance.

Final browser proof must inspect the refreshed local preview at desktop and phone widths, confirm every animation loads and plays silently, and verify the saved Steam beta preview. The actual Steam preview is the authority for hosted playback and layout. Evidence belongs under `build/refresh-steam-store-page-with-tactical-media-and-copy/proof/store-revision-2/`.

## September 6 saved draft

The 217-character short description and complete main description were saved and verified after a full Steamworks reload. All four refined banners and five v2 loops have successful observed upload references and matching source hashes. Steam beta displays the new copy, all banners and the campfire section; all five processed loops report ready playback, muted audio and no media errors. Steam serves these description loops at 1170×658 after its own conversion. The uploaded masters remain 1920×1080.

Desktop Steam review and the earlier 390px local/Steam layout checks passed. A final responsive override was not applied by the browser capability, so it is not counted as a fresh phone check. The trailer and gallery replacement remain the documented manual legacy-uploader handoff. No public revision was published.
