#!/bin/sh
# Publish the release line to master as ONE commit (owner 2026-11-03): tree = the tested release commit,
# parent = current origin/master. Day-by-day history stays on codex/release and codex/peer-benchmark.
# usage: release_squash_push.sh [--skip-export-smoke] <tested-release-commit> <message-file>
# Owner approval and full suites first. The export gate checks exactly TESTED.
set -eu
SKIP_EXPORT_SMOKE=0
TESTED=; MSG=
for ARG in "$@"; do
    case "$ARG" in
        --skip-export-smoke) SKIP_EXPORT_SMOKE=1 ;;
        --*) echo "Unknown option: $ARG" >&2; exit 2 ;;
        *)
            if [ -z "$TESTED" ]; then TESTED=$ARG
            elif [ -z "$MSG" ]; then MSG=$ARG
            else echo "Usage: $0 [--skip-export-smoke] <tested-release-commit> <message-file>" >&2; exit 2
            fi ;;
    esac
done
[ -n "$TESTED" ] && [ -n "$MSG" ] || { echo "Usage: $0 [--skip-export-smoke] <tested-release-commit> <message-file>" >&2; exit 2; }
SMOKE_TOOL="$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)/tools/export_smoke.py"
cd /Users/borgerding/workspace/Labyrinth
TESTED=$(git rev-parse --verify "$TESTED^{commit}")
TREE=$(git rev-parse "$TESTED^{tree}")
[ -z "$(git ls-tree -r --name-only "$TESTED" -- output/ | head -1)" ] || { echo "REFUSED: output/ is tracked in $TESTED"; exit 2; }
if [ "$SKIP_EXPORT_SMOKE" -eq 1 ]; then
    echo "WARNING: --skip-export-smoke: release-template validation skipped for $TESTED" >&2
else
    SNAPSHOT=$(mktemp -d "${TMPDIR:-/tmp}/labyrinth-release-smoke.XXXXXX")
    trap 'rm -rf "$SNAPSHOT"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    # Export the immutable tested tree, never whichever checkout happens to be
    # current (or its uncommitted files). No additional worktree or Git writes.
    git archive --format=tar --output="$SNAPSHOT/source.tar" "$TESTED"
    mkdir "$SNAPSHOT/project"
    tar -xf "$SNAPSHOT/source.tar" -C "$SNAPSHOT/project"
    rm "$SNAPSHOT/source.tar"
    echo "Checking release-template export of $TESTED before master push"
    if ! python3 "$SMOKE_TOOL" --preset "Steam macOS" --project "$SNAPSHOT/project"; then
        echo "REFUSED: export smoke failed for $TESTED; master was not pushed." >&2
        exit 4
    fi
    rm -rf "$SNAPSHOT"
    trap - EXIT INT TERM
fi
git fetch -q origin master
PARENT=$(git rev-parse origin/master)
C=$(git commit-tree "$TREE" -p "$PARENT" -F "$MSG")
SIZE=$(git rev-list --objects "$PARENT..$C" | cut -d' ' -f1 | git cat-file --batch-check='%(objectsize:disk)' | awk '{s+=$1} END {print int(s/1048576)}')
echo "release commit $C (tree of $TESTED), upload ~${SIZE} MB"
[ "$SIZE" -lt 1800 ] || { echo "REFUSED: over GitHub's ~2 GB push limit; find what grew"; exit 3; }
git push origin "$C:refs/heads/master"
git ls-remote origin refs/heads/master
