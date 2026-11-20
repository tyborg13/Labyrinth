# Settings persistence

`user://settings.json` stores preferences as flat keys. The documented Steam
Auto-Cloud configuration syncs progression and run saves. Settings remain
local to each installation. See the [Steam Cloud setup](../steam/README.md#steam-cloud-setup).

Individual panel edits read the latest settings file and merge the edited
preference into it. The file is replaced atomically. When a preference write
fails, the current preferences stay active in memory. The next successful
settings write persists those preferences.

The `ui_volume`, `mute_in_background` and window geometry keys are additive.
If an older build saves the file, it can drop those keys. Returning to a newer
build then uses 100% Interface volume, Off for Mute in background, and the
centered windowed fallback.

Window memory stores the last normal windowed client size in `window_size`
and its offset from the display origin in `window_position`.
`window_screen_size` identifies same-sized candidates. Their neighboring
display rectangles, stored relative to the saved display in
`window_screen_neighbors`, distinguish candidates across desktop origin and
index changes. The saved index, `window_screen`, breaks ties.

The window restores at its saved size and offset when its decorated bounds
fit the usable area. Otherwise those bounds are clamped on the same display.
When no display matches, the window centers on the primary display. Leaving
normal windowed mode saves any pending normal geometry. Game Mode skips
geometry writes to preserve the Deck Desktop Mode placement.

Linux uses X11 or XWayland by default. Native Wayland is a known limit since
its compositor controls placement and Godot may report the first output for
a window on another display.

## Keys added by later units

| Key | Control | Default | Values |
| --- | --- | --- | --- |
| `controller_vibration` | Accessibility → Controller vibration | On | Boolean, shown as On / Off |

## Controls section

Settings ends with a read-only **CONTROLS** section after Accessibility (`_build_controls_section` in
`scripts/settings_panel.gd`). It lists what each key and button does. Like every section, it uses `_section_shell`;
its tagline ("What each key and button does.") stays hidden like the others. Rebinding is not part of it.

### Data: `data/controls.json`

The rows are data, in display order, so later units add or change a row without code. The file is an array of rows:

```json
{"id": "pass", "label": "Pass the turn", "pointer": ["Pass button", {"key": "P"}], "controller": ["controller_pass"]}
```

- `label`: the action, in the settings row label style.
- `pointer`: keyboard and mouse tokens, in order. `{"key": "P"}` draws a keycap. A plain string is a phrase and draws
  as caption text (`Left click`, `Mouse`, `Pass button`). An empty list shows `—`.
- `controller`: InputRouter action names (`controller_accept`, `combat_undo_move`, `controller_dpad`, …), drawn as
  `InputGlyph` badges at `InputGlyph.preferred_size`. An empty list shows `—`.

**Every row must be true.** List only bindings that exist in code for that action, and audit them before adding a
row. The rows that were left out in ux-17:
- Zoom the map. The current section map has no zoom; there, the wheel scrolls (`section_map_panel.gd`). Zoom exists
  only on the legacy map, for old saves.
- Pin a tooltip. Shift pins only over the Scavenger's wares, so the row would claim too much.
- Controller bindings for "Pick a card" and "Show enemy intents". They have none.

Letter keys follow the player's layout. P and 1–9 use `combat_keyboard_shortcuts.gd`. The undo InputMap event
matches the key that types z (`keycode`, plus Ctrl/Cmd+Z). Each keycap is therefore true on AZERTY.

### Look and input

- Each row uses the same frame and label font, size and colour as the other settings rows. Two right-aligned columns
  follow the label. Their headings, "Keyboard and mouse" and "Controller", sit on the section title line in the
  section caption style. After the section enters the tree, each column takes the width of its widest cell.
- Keycaps (`ControlsKeycap`) are InputGlyph's rounded key in its Xbox (dark) styling, whatever the pad family. The
  label is 17 pt for a single letter and 13 pt for longer keys (Shift, Space, Esc, 1–9). Keys are at least the
  standard 36×27 key, widened to the label plus 12 px a side. No commas: the frames separate tokens. Phrases and `—`
  use the caption style.
- Controller badges use the router's current family, which is Xbox until a pad is seen. They switch live on
  `controller_family_changed`.
- Rows can take focus, so the D-pad, arrow keys and Tab scroll the panel through the section. Accept does nothing.
  Navigation focus draws the skin's standard focus ring. Hover draws nothing, since a lit row would read as a
  button. A click leaves the focus hidden. The wheel still scrolls the panel over a row.

Proof: `tools/ux17/capture.gd`. With `--headless-check`, it runs the binding, layout, keycap, family, navigation and
pointer checks. A windowed run through `tools/visual_probe_runner.py` with `tools/ux17/proof_contract.json` adds
exact-size SubViewport captures at 1920x1080 (100% pointer and controller, 125%, and a forced 150%) and 1280x800
(Deck, 115%, Steam Deck glyphs).
