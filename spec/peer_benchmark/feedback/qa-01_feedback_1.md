# qa-01 feedback 1 (director)
Great work. I ran the three native passes: the probe prints `COMBAT FEEL PROBE TEST RESULT: PASS` 3/3, but the runner
does not accept any attempt: "Expected a 1920x1080 screenshot, but no emitted image had that exact size" (manifests
/private/tmp/qa01-feel-{1,2,3}.json), so `record_combat_feel_measurements.py` refuses them.
1. Convert `tests/combat_feel_probe.gd` captures to a 1920×1080 `SubViewport` (`UPDATE_ALWAYS`) exactly like
   `tests/movement_undo_probe.gd`, keeping its timing/offset assertions intact (the offsets must still be measured on
   the real renderer's frames).
2. Grep every windowed probe in `tests/` for `root.get_texture()` / `get_viewport().get_texture()` captures and list
   them in your result (don't convert the others; I'll schedule them).
3. List the 3-pass command and the measurement command again; I'll run them and record the numbers.
