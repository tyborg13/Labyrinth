# Steamworks upload manifest

App: **Escape the Umbra** (`4530510`)

Status: **inspection-ready, not uploaded or published**. The store page is already in Valve review, so this bundle must not replace its assets until the committed refresh is approved for publication.

All paths below are relative to this directory. The filenames intentionally match their Steamworks fields.

## Store graphical assets

| Steamworks field | File | Dimensions |
| --- | --- | --- |
| Header capsule | `store/header_capsule.jpg` | 920 × 430 |
| Small capsule | `store/small_capsule.jpg` | 462 × 174 |
| Main capsule | `store/main_capsule.jpg` | 1232 × 706 |
| Vertical capsule | `store/vertical_capsule.jpg` | 748 × 896 |
| Page background | `store/page_background.jpg` | 1438 × 810 |

## Screenshots

Upload the PNGs in filename order so the first four tell the combat-to-progression story above the fold:

1. `screenshots/01-combat-threshold.png`
2. `screenshots/02-character-loadout.png`
3. `screenshots/03-lantern-shot.png`
4. `screenshots/04-wildfire-halo.png`
5. `screenshots/05-route-map.png`
6. `screenshots/06-arcanist-merchant.png`
7. `screenshots/07-cleaver-hook.png`
8. `screenshots/08-relic-choice.png`

Every screenshot is a cursor-free, current-build 1920 × 1080 capture with the gameplay composition preserved and the UI safely inset for Steam cropping.

## Library assets

| Steamworks field | File | Dimensions |
| --- | --- | --- |
| Library capsule | `library/library_capsule.jpg` | 600 × 900 |
| Library header | `library/library_header.jpg` | 920 × 430 |
| Library hero | `library/library_hero.jpg` | 3840 × 1240 |
| Library logo | `library/library_logo.png` | 1280 × 720, transparent |

## Client assets

| Steamworks field | File | Dimensions |
| --- | --- | --- |
| Shortcut icon | `client/shortcut_icon.png` | 512 × 512 |
| Client/app icon | `client/app_icon.jpg` | 184 × 184 |

## Trailer

| Steamworks field | File | Specification |
| --- | --- | --- |
| Trailer video | `trailer/escape-the-umbra-gameplay.mp4` | 1920 × 1080, 30 fps, H.264 + AAC |
| Trailer poster | `trailer/poster.jpg` | 1920 × 1080, text-free gameplay frame |

The trailer is 57.47 seconds. It preserves the existing composition, pacing, music, and crumble treatment while using the current display font and footage recaptured from the current production build.

## QA before upload

- `../qa/store-assets-contact-sheet.jpg` shows every still asset together.
- `../qa/screenshots-contact-sheet.jpg` shows screenshot order and crop safety.
- `../qa/trailer-audit/audit-manifest.json` records the final trailer stream metadata and SHA-256.
- `../qa/trailer-audit/master-sheet.png` covers the full edit at one frame per second.
- `../qa/trailer-audit/focus-final-crumble-1596-1715.png` proves the filled-title arrival and crumble reveal.

Run `python3 steam/scripts/validate_store_assets.py` from the repository root immediately before uploading. Upload files one Steamworks field at a time, save each section without publishing, then re-check Steam's generated previews before publishing the store changes.
