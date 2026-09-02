# Maker's Seal startup

The user selected **The Maker's Seal** and requested the artwork **as is**.
The shipping PNG remains byte-for-byte identical to that approved ImageGen output,
including the embossed Godot face and "Made with Godot" credit. Do not regenerate,
crop, retouch, or replace its typography without a new request.

- Asset: `assets/art/ui/boot_splash_makers_seal.png`
- Dimensions: 1672 × 941, centered with its aspect ratio preserved.
- SHA-256: `a2fea0706c12f6e9e066e5b3f54d2660423d42d733975a110f0ffe45b79f211c`

## Startup sequence

After inspection, the user requested a two-second minimum and then smooth fades.
The native Godot splash is static, so the visible sequence now belongs to
`scenes/startup.tscn` and `scripts/startup.gd`:

1. Native boot and the first scene frame are solid black.
2. Fade the unchanged seal in over 0.4 seconds with a sine ease.
3. Keep it fully opaque for **at least two seconds**, measured by a monotonic clock.
4. Once the menu resource has loaded, fade the seal to black over 0.35 seconds.
5. Instantiate the existing menu behind black, then reveal it over 0.4 seconds.
6. Restore input and the cursor, and free the startup scene.

The scene requests the menu resource in a background thread while showing the
seal; slow loads extend the opaque hold, not an empty black loading screen.
The existing menu remains `scenes/main_menu.tscn`, so returning to it does not
replay the intro. The native `minimum_display_time` is now zero and `show_image`
is false: keeping the old native two-second hold would duplicate the sequence
and show the image before its fade-in. The hidden native splash does not name the
PNG, because Godot resolves that project setting before startup code can recover
from a missing local import cache. Instead, the seal and generated menu rasters
use Godot's `Keep File (exported as is)` import mode, and `startup.gd` loads the
raw approved PNG through `AssetLoader`.

`SettingsStore.motion_duration` disables the fades for reduced-motion users while
preserving the two-second opaque hold. Viewport input is disabled until the menu
is fully visible. The prior input/cursor state is restored on completion or early
scene teardown, preventing activation of hidden menu controls or a stranded lock.
No gameplay, save schema, menu controls, input mappings, or menu music are changed.

Godot references: [native splash settings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-application-boot-splash-show-image),
[background resource loading](https://docs.godotengine.org/en/4.6/classes/class_resourceloader.html#class-resourceloader-method-load-threaded-request).

## Attribution and distribution

`GODOT_SPLASH_LICENSE.txt` credits the original logo author, links CC BY 4.0 and
the original logo, identifies the adaptation, and links the engine's MIT license.
The Steam export workflow copies that notice beside each platform's executable,
outside the PCK. Direct Godot-editor exports must distribute the notice alongside
the app as well. This is not an audit of the game's other third-party components.

Keep the PNG import sidecar tied to its canonical asset path. Broad repository
imports can follow the trailer's `game-assets` symlink and rewrite the sidecar to
a marketing alias; the focused Python check detects that metadata drift.

## UI design statement

- **Surface:** application startup, before any player decision.
- **Player question:** is the game starting, and which engine made it?
- **Primary action:** none; the sequence advances automatically to the menu.
- **Hierarchy:** central brass seal, then its three-word credit; stone, ember and
  violet shadow preserve the game's existing material palette.
- **Interaction:** no splash buttons. Pointer, keyboard and controller activation
  are blocked only during the intro, then existing menu paths are restored.
- **Components:** unchanged art and menu; native Control/TextureRect and Tween;
  existing SettingsStore for display, audio and reduced-motion preferences.
- **Proof matrix:** black start, intermediate seal fades, opaque hold, intermediate
  menu reveal, ready menu, and reduced-motion seal/menu at 1920 × 1080, 100% scale.

## Verification

- `tests/test_boot_splash.py`: approved bytes, native settings, canonical import
  mapping, clean-cache-safe runtime ownership, keep-file export policy, attribution
  and real desktop staging with temporary fake outputs.
- `tests/main_menu_input_test.gd`: actual startup in both motion modes, full hold
  timing, fade timing, blocked pointer/keyboard/controller actions, restored first
  clicks and key/controller activation, no replay on return, and teardown cleanup.
- `tests/main_menu_resume_test.gd`: existing saved-run/menu behavior.
- `tests/boot_splash_probe.gd`: the actual production startup scene, not a recreated
  splash. Seven illustrated PNG states use the normal visual proof contract.
  The intentional black frame is checked byte-for-byte as RGB zero, then saved
  as JPEG because the generic PNG quality gate correctly rejects blank images.
- A separate recording pass avoids PNG-compression stalls in the motion preview.
  Its captured JPEG frames carry actual elapsed timestamps for video encoding.
- `tests/boot_splash_export_test.gd`: exported raw PNG checked from an empty project,
  with no filesystem fallback. The startup/menu input test also runs using the
  fresh PCK as the main pack, with only host-native extension libraries staged
  beside it; game scenes, scripts and art load from the pack.

The focused runs can report known shutdown-resource warnings, and sandboxed
headless runs report the host's system-CA retrieval error. Do not suppress them.
Native Windows execution, the full gameplay suite and Steam upload remain outside
this task's proof; a Windows-preset PCK export is not Windows runtime coverage.

## Inspection

A saved-run/Continue fixture is not applicable: inspect application launch through
the task-local Godot runner. The startup scene has no saved-run dependency.

## UI rubric

| Gate | Result |
| --- | --- |
| Immediate comprehension | Pass: familiar engine mark and unchanged credit. |
| Visual hierarchy | Pass: one seal with subordinate attribution. |
| Gameplay visibility | Exception: startup precedes gameplay. |
| Compact, precise copy | Pass: approved three-word credit is unchanged. |
| State and consequence | Exception: intro has no selectable state. |
| Interaction completeness | Pass: input restored after reveal and on interruption. |
| Visual cohesion | Pass: approved brass/stone/ember/violet artwork. |
| Accessibility | Pass: reduced motion skips fades; hold and readable credit remain. |
| Layout resilience | Pass: fresh 1920 × 1080 captures preserve the whole image and menu. |
| Visual proof | Pass: seven validated illustrated states, asserted black frame, and recorded real sequence. |
