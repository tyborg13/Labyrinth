#!/bin/sh
# Director quick look: compile both designs, then run only the native capture (no determinism/proof jobs).
# usage: quick_capture.sh RUN_ID FIGURE...
set -e
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-11
RUN=$1; shift
python3 -B -c "from spec.art_identity.maquettes.hollow_mimic.owner_review.workflow import prepare; prepare('$RUN')"
for F in "$@"; do
  O=tests/mq11_proof/$RUN/$F
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --disable-autoexec --python-exit-code 2 -P spec/art_identity/maquettes/blender/build.py -- $PWD/$O/spec_native.json $PWD/$O/capture > $O/quick_capture.log 2>&1 && echo "$F capture ok" || echo "$F capture FAILED"
done
