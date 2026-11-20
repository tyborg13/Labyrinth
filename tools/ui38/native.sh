#!/usr/bin/env bash
# Run from the ui-38 worktree on a host with a window server.
set -euo pipefail

profile=${1:?Use deck or desktop}
shift
case "$profile" in
	deck) deck=1; resolution=1280x800; scale=115 ;;
	desktop) deck=0; resolution=1920x1080; scale=100 ;;
	*) printf 'Unknown profile %s\n' "$profile" >&2; exit 2 ;;
esac

if (( $# == 0 )); then
	set -- d01-save d01-recap d02 d03 d04 d05 d06
fi
for check in "$@"; do
	case "$check" in
		d01-save|d01-recap|d02|d03|d04|d05|d06) ;;
		*) printf 'Unknown check %s\n' "$check" >&2; exit 2 ;;
	esac
	output="$PWD/.godot/ui38/native-$profile-$check"
	mkdir -p "$output"
	SteamDeck="$deck" LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1 \
		UI38_CASE="$check" UI38_SCALE="$scale" UI38_OUTPUT="$output" \
		python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy \
		--task-id ui-38 --expect-size "$resolution" --proof-contract "tools/ui38/proof-$profile.json" \
		--result-manifest "$output/manifest.json" --overwrite-result-manifest tools/ui38/controller_proof.gd
done
