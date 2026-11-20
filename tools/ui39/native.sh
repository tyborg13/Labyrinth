#!/usr/bin/env bash
# Run from the ui-39 worktree in a desktop renderer session.
set -euo pipefail

profile=${1:?Use deck or desktop}
surface=${2:?Use combat, boon or arrival}
case "$profile" in
	deck) size=1280x800 ;;
	desktop) size=1920x1080 ;;
	*) exit 2 ;;
esac
case "$surface" in
	combat|boon|arrival) ;;
	*) exit 2 ;;
esac

output="${UI39_OUTPUT:-$PWD/output/ui-39/$profile/$surface}"
mkdir -p "$output"
SteamDeck=1 LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1 \
	UI39_PROFILE="$profile" UI39_SURFACE="$surface" UI39_OUTPUT="$output" \
	python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy \
	--task-id ui-39 --timeout 180 --expect-size "$size" \
	--proof-contract "tools/ui39/$surface.json" \
	--result-manifest "$output/manifest.json" --overwrite-result-manifest tools/ui39/probe.gd
