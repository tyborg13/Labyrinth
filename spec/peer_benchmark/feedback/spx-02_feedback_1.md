# spx-02 feedback 1 (director: windowed proof and your open items)

1. **High: the windowed proof writes nothing.**
   - The director ran your exact command. Every capture failed `Capture writes at 1920x1080`, the output folder is
     empty, and "Pointer hover exposes approved title and rules line" failed too. Log:
     `/private/tmp/labyrinth-godot-home/spx-02-1792557154209258000-41032-special_encounter_probe-1/godot.log`.
   - Cause: `_capture` reads `root.get_texture()`, which on the macOS window isn't exactly 1920×1080.
   - Capture through the project's fixed-size capture viewport, the way the existing native probes do (for example
     `CaptureViewport.create(root)` in `tests/rr29/production_probe.gd` and its helpers), so every image is exactly
     1920×1080 at 100% UI scale.
   - Then make the hover check pass for real: a pointer hover on a Warband node shows "Warband · <captain title>",
     the type's line and the state line.
   - Prove as much as you can headless. The director reruns the windowed command.
2. **TODO_DESIGN_SPECIAL_FOURTH_CHOICE_ELEMENT_FILTER, decided:**
   - In an elemental room, the fourth choice comes from the room's element, so the room offers 3 element cards and 1
     general.
   - In a neutral room, all four are general.
   - The rarity floor re-rolls the last element slot at Rare or better, or the last slot in a neutral room.
3. **Door-hover label:** you may edit `run_scene.gd::_room_hover_hint`, and only that function, so the label above a
   physical door uses the library's name, the same as the map.
4. **Staged emblem sidecars:** commit the `.png.import` files Godot generates for
   `spec/peer_benchmark/staged/spx/emblems/*.png`, so the tracked-import check passes. Don't change the PNGs.
5. The defensive `TODO_DESIGN_SPECIAL_NAME`, `TODO_DESIGN_CAPTAIN_TITLE` and `TODO_DESIGN_SPECIAL_TOOLTIP` guards are
   fine as error paths: the data always supplies these fields. Rename them to plain errors so they don't read as open
   design questions.
6. Focused tests only.
