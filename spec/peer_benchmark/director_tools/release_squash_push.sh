#!/bin/sh
# Publish the release line to master as ONE commit (owner 2026-11-03): tree = the tested release commit,
# parent = current origin/master. Day-by-day history stays on codex/release and codex/peer-benchmark.
# usage: release_squash_push.sh <tested-release-commit> <message-file>   (owner approval and full suites first)
set -eu
TESTED=$1; MSG=$2
cd /Users/borgerding/workspace/Labyrinth
git fetch -q origin master
PARENT=$(git rev-parse origin/master)
TREE=$(git rev-parse "$TESTED^{tree}")
[ -z "$(git ls-tree -r --name-only "$TESTED" -- output/ | head -1)" ] || { echo "REFUSED: output/ is tracked in $TESTED"; exit 2; }
C=$(git commit-tree "$TREE" -p "$PARENT" -F "$MSG")
SIZE=$(git rev-list --objects "$PARENT..$C" | cut -d' ' -f1 | git cat-file --batch-check='%(objectsize:disk)' | awk '{s+=$1} END {print int(s/1048576)}')
echo "release commit $C (tree of $TESTED), upload ~${SIZE} MB"
[ "$SIZE" -lt 1800 ] || { echo "REFUSED: over GitHub's ~2 GB push limit; find what grew"; exit 3; }
git push origin "$C:refs/heads/master"
git ls-remote origin refs/heads/master
