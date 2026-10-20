#!/bin/sh
# usage: post_merge_if_head.sh UNIT SHA — run post_merge.sh only when integration is clean and still at SHA.
S=/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad
cd /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark || exit 9
H=$(git rev-parse --short=9 HEAD)
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "SKIP: integration dirty"; exit 8; }
case "$H" in $2*) ;; *) echo "SKIP: HEAD moved to $H (later merge suites cover $1)"; exit 0;; esac
exec sh $S/post_merge.sh $1
