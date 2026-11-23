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

Settings ends with **CONTROLS** after Accessibility (`_build_controls_section` in
`scripts/settings_panel.gd`). It lists what each key and button does. The six editable keyboard
actions are Pass (P), Hurry (Space), Empower (E), Undo a walk (Z), Show enemy intents (I), and Map (M).
Controller mappings stay with Steam Input.

`key_bindings` in `user://settings.json` maps action IDs to Godot physical keycodes. Zero unbinds an
action. Missing and invalid entries use the default key. The default letter positions are resolved
from the system layout at launch when available. Custom bindings retain their physical positions
across launches, and their labels reflect the active layout. Loading an unreadable settings file
uses defaults and does not write the file. Binding changes are ordinary preferences, stored
independently of run saves and the profile.

### Data: `data/controls.json`

The rows are data, in display order, so later units add or change a row without code. The file is an array of rows:

```json
{"id": "pass", "label": "Pass the turn", "pointer": ["Pass button", {"key": "P", "rebind": "pass"}], "controller": ["controller_pass"]}
```

- `label`: the action, in the settings row label style.
- `pointer`: keyboard and mouse tokens, in order. A `key` token draws a keycap. Add `rebind` with
  its action ID to draw an editable keycap using the current binding. A plain string draws as
  caption text (`Left click`, `Mouse`, `Pass button`). An empty list shows `—`.
- `controller`: InputRouter action names (`controller_accept`, `combat_undo_move`, `controller_dpad`, …), drawn as
  `InputGlyph` badges at `InputGlyph.preferred_size`. An empty list shows `—`.

**Every row must be true.** List only bindings that exist in code for that action, and audit them before adding a
row. The rows that were left out in ux-17:
- Zoom the map. The current section map has no zoom; there, the wheel scrolls (`section_map_panel.gd`). Zoom exists
  only on the legacy map, for old saves.
- Pin a tooltip. Shift pins only over the Scavenger's wares, so the row would claim too much.
- Controller bindings for "Pick a card" and "Show enemy intents". They have none.

`scripts/key_bindings.gd` resolves the six editable actions and supplies their layout-aware labels.
The fixed hand shortcuts 1–9 continue to use `combat_keyboard_shortcuts.gd`. Ctrl/Cmd+Z remains a
separate undo shortcut on the key that types z.

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
- The D-pad, arrow keys and Tab navigate the section. Read-only rows take focus for scrolling.
  The editable keycap takes focus in each rebindable row. Click, Enter, or controller A starts
  listening. The cap shows `Press a key` in the selection style and widens within the existing row.
- Esc, a mouse click, or controller B cancels listening. Backspace and Delete clear the binding and
  the keycap displays `—`. Digits 1–9 on either number bank, Enter, Tab, Shift, Ctrl, Alt, Cmd/Meta
  and Caps Lock leave the cap listening. A conflict swaps the two bindings with a single selection
  pulse on each cap. If the edited action was unbound, the other action becomes unbound.
- **Restore default keys** uses the shared confirmation. The button is disabled when all six
  bindings are at their defaults. Confirming restores those keys and keeps the other preferences.

Proof runs through `tools/ux19/native.sh`. The `--dry-run` mode exercises Settings, gameplay
handlers, and a second Godot process for persistence. The `--windowed` mode creates exact-size
SubViewport captures with cel look active and validates them against `tools/ux19/proof_contract.json`.
