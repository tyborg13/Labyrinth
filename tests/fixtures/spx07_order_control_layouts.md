# Frozen ordinary order controls

`spx07_order_control_layouts.bin` contains only generated room layouts from base
`3fad2e65b1685996f7eed3fd407513cd54012129`, before spx-07 placement changes.
It is test data, not an authored encounter catalog or a player save.

Generation used the base's `RoomGenerator.generate_room(83,
WarbandInspection.room_spec(biome, 3), Vector2i.UP)` for, in insertion order,
`earth`, `fire`, `air`, `ice`, `lightning`, `shadow`. The dictionary was written
with `FileAccess.store_var`, without objects. Read with `get_var`.

`WarbandOrdersSuite.battle(..., true)` removes the Warband objective and leader
flags, then applies its existing ordinary-mechanic arena. Freezing the generator
input keeps the existing `spx04_legacy_golden.json` hashes meaningful when the
unrelated Warband formation search changes. The golden assertions are unchanged.
The binary format preserves dictionary insertion order, which those full-Variant
hashes include; converting through `var_to_str` sorts keys and changes the hashes.
Regeneration must use the recorded base, not the current Warband generator.
