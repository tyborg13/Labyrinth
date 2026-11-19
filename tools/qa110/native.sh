#!/bin/sh
# Run one explicit proof to keep capture receipts attributable.
set -eu
kind=${1:?Provide case or run}
out=${2:?Provide a fresh output directory}
shift 2
mkdir -p "$out"
out=$(cd "$out" && pwd)
case "$kind" in
	case)
		script=interruptions.gd
		limit=90
		label=${1:?Provide a path from REPORT.md}
		shift
		for arg in "$@"; do
			if [ "$arg" = --native-focus-loss ]; then
				printf 'When the proof holds a card, switch away from the game window and return.
'
			fi
		done
		set -- "--case=$label" "$@"
		;;
	run)
		script=native_replay.gd
		limit=1800
		seed=${1:?Provide a seed}
		decision=${2:?Provide a decision}
		shift 2
		set -- "--seed=$seed" "--decision=$decision" "$@"
		;;
	*) printf 'Unknown proof kind %s\n' "$kind" >&2; exit 2 ;;
esac
LABYRINTH_CEL_LOOK=off LABYRINTH_GROUND_FX= LABYRINTH_DEMO= \
exec python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy \
	--task-id qa-110 --attempts 1 --timeout "$limit" --expect-size 1920x1080 \
	--proof-contract tools/qa110/visual_contract.json --result-manifest "$out/result.json" \
	"tools/qa110/$script" -- "--out=$out" "$@"
