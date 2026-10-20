#!/bin/sh
# Delete a worktree's untracked .import/.uid files that integration (codex/peer-benchmark) now tracks.
# They are regenerated copies with local random UIDs; merging integration brings the canonical ones.
set -eu
WT=$1
T=$(mktemp -d)
git -C "$WT" ls-tree -r --name-only codex/peer-benchmark | grep -E '\.(import|uid)$' | sort > "$T/tracked"
git -C "$WT" ls-files --others --exclude-standard | grep -E '\.(import|uid)$' | sort > "$T/untracked" || true
comm -12 "$T/tracked" "$T/untracked" > "$T/drop"
n=$(wc -l < "$T/drop" | tr -d ' ')
( cd "$WT" && tr '\n' '\0' < "$T/drop" | xargs -0 rm -f )
echo "dropped $n shadow sidecars in $WT"
rm -rf "$T"
