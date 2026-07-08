# Steam Build/Upload Workflow

This repository now includes a Mac-run Steam pipeline at:

```bash
./scripts/build_and_upload_steam.sh
```

It exports **macOS**, **Windows**, and **Linux** desktop builds from this Godot project, then uploads them to SteamPipe for either your **main game app**, your **Steam Playtest app**, or both.

## Steam terms in plain English

- **App**: an installable product on Steam. Your main game and your Steam Playtest are two separate App IDs.
- **Depot**: a bucket of files attached to one app. The normal setup here is one depot per platform:
  - macOS
  - Windows
  - Linux / Steam Deck
- **Branch**: a build lane inside one app.
  - `default` is the normal/default branch.
  - named beta branches like `internal` or `qa` are separate lanes you can opt into from the Steam client.

## Important Steam limitation

SteamCMD can **automatically set a named beta branch live**, but it **cannot set the `default` branch live automatically**. That is a Valve limitation, not a script limitation.

That means the workflow is:

- If `STEAM_MAIN_BRANCH="default"` or `STEAM_PLAYTEST_BRANCH="default"`:
  - the script uploads the build
  - then Steam shows you the App Admin builds URL where you click **Set live** for the default branch
- If you use a named beta branch like `internal`:
  - the script uploads the build
  - SteamCMD can mark that beta branch live automatically

## Recommended setup

If you want the smoothest repeatable workflow:

- Use your **Playtest app** for shared external testing.
- Use a **named beta branch** like `internal` on the main app for your own private testing.

If you still want the **default branch** for your personal build, the script supports that too, but Steam requires the final “set live” click in App Admin.

## One-time Steamworks setup

1. Confirm [steam_build_config.env](steam_build_config.env) matches the Steamworks App IDs and Depot IDs you are repurposing for Escape the Umbra.
2. Create or confirm desktop depots for each app:
   - macOS
   - Windows
   - Linux
   - this script expects those to be three different Depot IDs, not one shared "All OSes" depot
3. Add those depots to the package your test account installs from.
4. Configure launch options in Steamworks once per app:
   - macOS launch target: `Escape the Umbra.app`
   - Windows launch target: `Escape the Umbra.exe`
   - Linux launch target: `Escape the Umbra.x86_64`

If Mac or Linux installs appear empty in Steam, double-check that those depots were added to the package for the app.

## Current repurposed app IDs

- Main app: `4530510`
- Playtest app: `4531660`

Steamworks should use these application names:

- Main app: `Escape the Umbra`
- Playtest app: `Escape the Umbra Playtest`

Steamworks General Installation should use these install folders and launch targets:

- Main install folder: `Escape the Umbra`
- Playtest install folder: `Escape the Umbra Playtest`
- Windows launch target: `Escape the Umbra.exe`
- macOS launch target: `Escape the Umbra.app`
- Linux launch target: `Escape the Umbra.x86_64`

In Steamworks General Application Settings, enable Windows 64-bit, macOS 64-bit, macOS Apple Silicon, and Linux support for the app. Leave Android off. Leave macOS notarized off unless the exported app has been separately notarized.

## Steam Deck troubleshooting

If Steam Deck shows `Compatibility tool failed` immediately on launch, the most common causes are:

- Steam is being forced to use Proton for this app even though the Deck should be using the native Linux depot here.
  - On Deck: `Properties > Compatibility`
  - Make sure `Force the use of a specific Steam Play compatibility tool` is turned off for the Linux build.
- Steamworks is pointing the Linux launch option at the wrong target.
  - The Linux launch target for this repo is `Escape the Umbra.x86_64`.
- The Linux depot was not added to the package the Deck account installs from.
- The uploaded Linux executable is missing its execute bit.
  - The export/upload script now runs `chmod +x` on the Linux client binary after export and after copying into the Steam content folder.

## First run

On first use the script will automatically download:

- SteamCMD for macOS into `.steam/`
- export templates for the installed Godot version if they are not already installed
- Rosetta 2 on Apple Silicon Macs, because Valve's current macOS SteamCMD binary is Intel-only

## Common commands

Export only:

```bash
./scripts/build_and_upload_steam.sh --export-only
```

Upload only using already-exported content:

```bash
./scripts/build_and_upload_steam.sh --upload-only
```

Upload just the playtest app:

```bash
./scripts/build_and_upload_steam.sh --targets playtest
```

Upload both the main app and playtest app:

```bash
./scripts/build_and_upload_steam.sh --targets main,playtest
```

Upload to a named internal beta branch for your main app:

```bash
./scripts/build_and_upload_steam.sh --targets main --main-branch internal
```

Generate a Steam preview build instead of uploading content:

```bash
./scripts/build_and_upload_steam.sh --preview --targets playtest
```

## Notes

- The script uses the repo’s committed Godot export presets:
  - `Steam macOS`
  - `Steam Windows`
  - `Steam Linux`
- Before exporting, the script copies a sanitized project into `.steam/export_project/` and omits development-only folders such as `.codex/`, `output/`, `playtest/`, `spec/`, `tests/`, `tmp/`, and `tools/`.
- After exporting, the script inspects each generated `.pck` and fails before upload if those development-only `res://` paths are present.
- The current Labyrinth client does not require GodotSteam binaries for upload/testing; this workflow packages ordinary Godot desktop exports for Steam launch.
- `steam_appid.txt` is intentionally **not** included in uploaded depots. Add one next to a local export only if future Steam API integration requires local non-Steam launches to initialize Steam.
