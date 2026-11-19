#!/bin/sh
# Native 1920x1080 at 100% UI scale, one semantic before or after per invocation.
set -eu
kind=${1:?Provide tharokh, walk or lob}
phase=${2:?Provide before or after}
case "$phase" in before|after) ;; *) exit 2 ;; esac
case "$kind:$phase" in tharokh:*|walk:*|lob:after) ;; *) exit 2 ;; esac
task=${LABYRINTH_RED04_TASK_ID:-red-04}
contract=tools/qa110/visual_contract.json
parent="$PWD/tools/qa110/out/$task/native/$kind-$phase"
mkdir -p "$parent"
out=$(mktemp -d "$parent/run.XXXXXXXX")
printf '%s capture output: %s\n' "$task" "$out"
case "$kind" in
	tharokh)
		script=tharokh_capture.gd
		set -- "--out=$out" --case=tharokh-mouse-pass_with_loop
		;;
	walk)
		script=walk_capture.gd
		save=${3:?Provide the decision-102 checkpoint directory}
		set -- --save-dir "$save" --tile rest --out "$out/walk.png"
		;;
	lob)
		script=lob_walk_capture.gd
		contract=tools/red04/lob_walk_contract.json
		set -- "--out=$out"
		;;
	*) exit 2 ;;
esac
if [ "$phase" = before ]; then set -- "$@" --before; fi
LABYRINTH_CEL_LOOK=off LABYRINTH_GROUND_FX= LABYRINTH_DEMO= \
exec python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy \
	--task-id "$task" --timeout 90 --expect-size 1920x1080 \
	--proof-contract "$contract" --result-manifest "$out/result.json" \
	"tools/red04/$script" -- "$@"
