# Maker's Seal boot splash

The user selected concept 5, **The Maker's Seal**, on 2026-08-27 and explicitly
requested it **as is**. The shipping PNG is an unchanged copy of the approved
ImageGen output, including the embossed Godot face and "Made with Godot" text.
Do not regenerate, crop, retouch, or replace its typography without a new request.

- Asset: `assets/art/ui/boot_splash_makers_seal.png`
- Native dimensions: 1672 × 941
- SHA-256: `a2fea0706c12f6e9e066e5b3f54d2660423d42d733975a110f0ffe45b79f211c`
- Native Godot 4.6 boot settings: black background, KEEP aspect-ratio stretch,
  linear filtering, image enabled, minimum display time 2000 milliseconds.
- Main scene remains `scenes/main_menu.tscn`; there is no new loading scene,
  input gate, or change to gameplay/saves.

After inspecting the first implementation, the user requested a couple of seconds
to see the seal even on fast starts. The native two-second minimum replaces the
original zero-wait setting; do not remove it as a startup optimization. This uses
[Godot's minimum display time setting](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-application-boot-splash-minimum-display-time),
not a timer or loading scene in the game.

The image's almost-16:9 aspect ratio is preserved, rather than stretched or
cropped to an exact 16:9 ratio. Black fills any remaining space.

## Attribution and distribution

`GODOT_SPLASH_LICENSE.txt` credits the original logo author, links CC BY 4.0 and
the original logo, identifies the adaptation, and links the engine's MIT license.
The normal Steam export workflow copies that notice beside each platform's
app/executable, outside the PCK, so the player can read it without an extractor.
For exports made directly through the Godot editor, distribute this notice
alongside the app/executable as well. This change is not an audit of other
third-party components already used by the game.

## UI design statement

- **Surface:** native engine boot splash, before scene UI exists.
- **Player question:** is the game starting, and which engine made it?
- **Primary action:** none; after the native minimum, startup advances automatically
  to the existing menu.
- **Hierarchy:** central brass seal, then its embedded three-word engine credit;
  stone, ember and violet shadow supply the game's established material palette.
- **Interaction paths:** the boot image has no interactive controls. Existing
  pointer, keyboard, and controller paths in the menu are unchanged.
- **Proof matrix:** native splash and main-menu handoff at 1920 × 1080, 100% UI
  scale, through `tests/boot_splash_probe.gd`. The static native image does not
  add motion or depend on scene UI-scale settings.

## Verification

`python3 tests/test_boot_splash.py` guards the approved file hash and PNG size,
project settings, attribution, and the real desktop staging function for all
three platforms using temporary fake export outputs (no Steam upload).
It also guards the import sidecar's canonical source/cache paths. Godot's broad
repository scan can follow the trailer's `game-assets` symlink and rewrite that
sidecar to the marketing alias; do not commit that generated metadata drift.

`tests/boot_splash_export_test.gd` mounts a real exported PCK from an empty
project and verifies the approved raw PNG bytes and dimensions. It rejects an
environment where the source PNG is already available, preventing a false pass
from filesystem fallback.

Run the focused native proof through `tools/visual_probe_runner.py`, with
`tests/boot_splash_probe_contract.json`. The probe reissues Godot's actual
`RenderingServer.set_boot_image_with_stretch` API using the production settings
after sizing its native window. It captures the screen region directly; it does
not recreate the splash with scene UI. Its short capture hold exists only in the
probe. It then loads the unchanged main menu and captures its viewport.
Before adding any probe waits, it records the first main-loop callback time and
checks that the native two-second minimum has elapsed. That timing check covers
the engine startup path, not the later reissued image's capture hold.
The screen-region API supports macOS and Windows; it requires a working native
display and cannot be replaced by a headless renderer.

Verified on 2026-08-27 with Godot 4.6.1:

- Five focused Python checks passed, including staging attribution on all three
  desktop platforms; five icon-identity checks passed; shell syntax and diff
  whitespace checks passed.
- Native Metal/Mobile proof passed at 1920 × 1080 with two inspected screenshots:
  the full seal/credit is visible without clipping, followed by the existing menu.
- A real PCK exported through the Steam Windows preset contains the exact raw
  approved PNG; the empty-project mount test passed.
- The canonical import sidecar also passed fresh import, texture loading, PCK
  export, and empty-project raw-image verification in an isolated project with
  no trailer symlink or preexisting import cache.
- Ordinary main-scene headless startup completed without script/parse failures.
- The native probe and ordinary startup smoke report two resources still in use
  at process exit. Sandboxed headless runs also report the host's system-CA
  retrieval error. These warnings were not suppressed; this task does not change
  runtime scene/resource management or certificate handling.

The PCK check is packaging proof, not a Windows runtime or Steam upload test.

### Two-second timing follow-up

The updated native probe passed with its first callback at 2619 ms, before any
probe timer. Fresh splash and menu captures were inspected at 1920 × 1080 and
100% UI scale. A minimal fast-start control on this macOS host reached its first
callback at 75 ms with the setting disabled and 2075 ms with the production
2000 ms value. These separate headless timing checks isolate the native wait
from ordinary asset loading; the native probe supplies the rendering proof.
The five focused Python checks and five icon checks still pass. The approved PNG,
its import metadata, attribution, and export/staging code are unchanged.

## Inspection

A saved-run/Continue fixture is **not applicable**: the change is visible before
any save or gameplay state loads. Inspect the native startup using the task-local
Godot runner, or repeat the focused native proof for a stable screenshot.

## UI rubric

| Gate | Result |
| --- | --- |
| Immediate comprehension | Pass: familiar engine mark and "Made with Godot". |
| Visual hierarchy | Pass: one central seal and subordinate attribution. |
| Gameplay visibility | Exception: startup precedes gameplay; nothing is obscured. |
| Compact, precise copy | Pass: the approved three-word credit is unchanged. |
| State and consequence | Exception: static boot display has no selectable state. |
| Interaction completeness | Pass: no action required; no input paths changed. |
| Visual cohesion | Pass: approved brass/stone/ember/violet artwork. |
| Accessibility | Pass: no motion or color-only information; readable text and icon. |
| Layout resilience | Pass: native 1920 × 1080 capture preserves the whole image and legible credit. |
| Visual proof | Pass: fresh inspected native splash and main-menu captures, validated by the probe contract. |
