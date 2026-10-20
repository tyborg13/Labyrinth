#!/bin/sh
# Codex peer review in a detached scratch worktree (never touches the unit worktree).
# usage: codex_review.sh UNIT REF PROMPT_FILE
set -e
UNIT=$1; REF=$2; PROMPT=$3
MAIN=/Users/borgerding/workspace/Labyrinth
ROOT=/private/tmp/labyrinth_codex/review
DIR=$ROOT/$UNIT-$(echo $REF | cut -c1-9)
OUT=$ROOT/$UNIT-$(echo $REF | cut -c1-9).md
LOG=$ROOT/$UNIT-$(echo $REF | cut -c1-9).log
mkdir -p $ROOT
[ -d "$DIR" ] || git -C $MAIN worktree add --detach "$DIR" "$REF" >/dev/null 2>&1
C=/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex
MODEL=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/skills/orchestrate-codex/projects/Labyrinth.json'))).get('model') or '')")
set --
[ -n "$MODEL" ] && set -- -c "model=\"$MODEL\""
$C exec -C "$DIR" -s workspace-write "$@" \
  -c 'sandbox_workspace_write.writable_roots=["/private/tmp/labyrinth_codex","/private/tmp/labyrinth-godot-home","/private/tmp/labyrinth-inspection-manifests"]' \
  --add-dir /private/tmp/labyrinth_codex --add-dir /private/tmp/labyrinth-godot-home \
  -o "$OUT" "$(cat "$PROMPT")" < /dev/null > "$LOG" 2>&1 || true
git -C $MAIN worktree remove --force "$DIR" >/dev/null 2>&1 || rm -rf "$DIR"  # owner 2026-10-16: review copies filled the disk
echo "REVIEW DONE $UNIT $REF -> $OUT"
tail -3 "$OUT" 2>/dev/null
