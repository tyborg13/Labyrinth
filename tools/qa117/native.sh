#!/usr/bin/env bash
# Run from the task worktree. The final two arguments apply to natural routes.
set -euo pipefail

matrix=${1:?Use tour, events, reveal-events, rules or route}
capture=${2:?Supply a QA117 checkpoint label}
seed=${3:-7}
returning=${4:-0}
viewport=${QA117_VIEWPORT:-1280x800}
case "$viewport" in
	1280x800) contract=tools/qa117/visual_contract.json; default_scale=115 ;;
	1920x1080) contract=tools/qa117/visual_contract_desktop.json; default_scale=100 ;;
	*) printf 'Unsupported proof viewport: %s\n' "$viewport" >&2; exit 2 ;;
esac
scale=${QA117_SCALE:-$default_scale}
if [[ "$matrix" == route ]]; then
	matrix=""
fi

output="$PWD/tools/qa117/.local/native-${viewport}-${scale}-seed-${seed}-${capture//\//-}"
if [[ -n "${QA117_CAPTURE_ROOM:-}" ]]; then
	room=${QA117_CAPTURE_ROOM//[^0-9,-]/}
	output="$output-room-$room"
fi
mkdir -p "$output"
output=$(mktemp -d "$output/run.XXXXXX")
printf 'QA117 native output: %s\n' "$output"
SteamDeck=1 LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1 \
	QA117_MATRIX="$matrix" QA117_CAPTURE="$capture" QA117_SEED="$seed" \
	QA117_RETURNING="$returning" QA117_SCALE="$scale" QA117_VIEWPORT="$viewport" QA117_OUTPUT="$output" \
	python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy \
	--task-id gfix-17 --timeout 600 --expect-size "$viewport" \
	--proof-contract "$contract" \
	--result-manifest "$output/manifest.json" tools/qa117/hunt.gd
