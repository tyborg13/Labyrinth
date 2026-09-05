# Description preview and upload plan

`copy.json` owns the English short description, introduction, sections and their actual local media paths. `generate-preview.py` synchronizes `description.md` and `short-description.txt`, then creates:

- `preview.html`: live text, the four heading banners and four silent autoplaying loops. The description column is 780 logical pixels wide, with Steam's dark blue background, ordinary sans-serif description text and 16px narrow-screen gutters. The short description is shown above the article as a separate review aid; Steam places it elsewhere on the actual store page.
- `description.bbcode.template.txt`: the complete About This Game text and eight clearly marked media placeholders. Image placeholders take the uploaded image URL. Video placeholders take the full embed markup produced by Steamworks, avoiding guessed video BBCode.
- `upload-plan.json`: app 4530510, English copy, eight gallery entries in order, four banner and four animation uploads, exact alt text, section ordering, hashes and placeholder substitutions.

Regenerate after any copy, banner or media-manifest change:

```sh
python3 marketing/steam-store/2026-09-05/generate-preview.py
python3 -m http.server 9874 --bind 127.0.0.1 --directory marketing/steam-store/2026-09-05
```

Open `http://127.0.0.1:9874/preview.html`. Local relative media paths also allow this folder to be moved as a complete bundle. The generated plan checks source hashes, expected asset counts, existing loop references, the short-description length, and a combined banner/loop budget below 15MB. Current description media totals 4,113,326 bytes; the short description has 222 characters.

Browser inspection completed at 1000×900 (measured 780px content column) and 390×844 (measured 358px content plus 16px gutters). All banners loaded at their native 1170px source width, all loops reached readyState 4 without errors and played muted as they became visible. All four section headings and live text remain legible on phone with no horizontal overflow. Offscreen loops pause under the in-app browser's ordinary visibility behavior. Desktop and phone opening/equipment/Umbra/descent views were inspected; the actual Steam preview remains the authority for its transcoding and final layout.

The final gallery 07 reference uses source frame 124, after the detached damage number has cleared. All other media outputs retain their independently reviewed hashes. The shared elemental risk sentence is supported by elemental enemy actions and `scripts/elemental_intensity_rules.gd`; this revision changes no game mechanics.
