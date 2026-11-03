#!/bin/sh
# Prints what's open and exits 0 if the owner may be playing, exits 1 if not. Matching on full command lines gives false
# positives from any shell whose text mentions the game, so this matches executables, and only real godot processes.
A=$(ps -axo comm | grep -F "Escape the Umbra")
B=$(ps -axo command | grep -E '^(/[^ ]*/)?[Gg]odot[^ ]* .*--log-file' | grep -v -- '--headless' | grep -v -E 'labyrinth-godot-home/(pol-|rr-|mq-|perf-|meas-|qa-|gate-|evt-|clip-|peer-|event-gallery|fb18)')
[ -n "$A$B" ] && { printf '%s\n%s\n' "$A" "$B" | cut -c1-120; exit 0; }
exit 1
