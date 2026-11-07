#!/bin/sh
# Wait while the owner's game (full or demo; macOS truncates both names to
# "Escape the Umbra") is running, so director native jobs never load the Mac
# during play. Prints once when it starts waiting.
# Then run any priority native jobs dropped in native_inserts/ (sorted, once
# each), so owner-facing captures can jump ahead of a long chain at its next step.
said=0
while sh /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/director_tools/owner_game_open.sh >/dev/null 2>&1; do
  [ $said -eq 0 ] && { echo "OWNER PLAYING: holding $(date +%H:%M)"; said=1; }
  sleep 60
done
[ $said -eq 1 ] && echo "OWNER DONE: resuming $(date +%H:%M)"
Q=/private/tmp/labyrinth_codex/native_inserts
for f in "$Q"/*.sh; do
  [ -f "$f" ] || continue
  mv "$f" "$f.running" || continue
  echo "PRIORITY JOB: $(basename "$f") $(date +%H:%M)"
  sh "$f.running" > "${f%.sh}.log" 2>&1
  echo "PRIORITY JOB DONE: $(basename "$f") rc=$? $(date +%H:%M)"
  mv "$f.running" "${f%.sh}.done"
done
exit 0
