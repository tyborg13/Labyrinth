#!/bin/sh
# One approved polish item: merge its branch, update the ledger, delete the branch only once it's in. usage: pol_approved.sh pol-NN "merge message"
S=/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad
WT=/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark
CU=$HOME/.claude/skills/orchestrate-codex/scripts/codex_unit.py
python3 $CU locked -- sh $WT/spec/peer_benchmark/director_tools/merge_pol.sh "$1" "$2" 2>&1 | tail -6 | cut -c1-120
git -C $WT merge-base --is-ancestor codex/$1 HEAD || { echo "NOT MERGED $1"; exit 1; }
python3 - "$1" <<'P'
import re,sys
p='/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/polish/LEDGER.md'
s=open(p).read()
s=re.sub(r"(\| %s \|[^\n]*?\|) posted, awaiting owner; branch `codex/%s` \w+ \|"%(sys.argv[1],sys.argv[1]),r"\1 **approved, merged** |",s,count=1)
open(p,'w').write(s)
P
git -C $WT add spec/peer_benchmark/polish/LEDGER.md
python3 $CU locked -- git -C $WT commit -q -m "Polish ledger: $1 approved and merged

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" 2>&1 | tail -1 | cut -c1-60
git -C /Users/borgerding/workspace/Labyrinth branch -D codex/$1 2>&1 | cut -c1-60
