#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tool_dir/../.."

replay=""
headless=""
checkpoint=""
start_action=1
only_action=0
dry_run=0
timeout=2400
launch_args=()
while (( $# )); do
    case "$1" in
        --dry-run) dry_run=1; shift ;;
        --replay) replay="${2:?missing replay path}"; launch_args+=("$1" "$2"); shift 2 ;;
        --headless) headless="${2:?missing headless evidence path}"; launch_args+=("$1" "$2"); shift 2 ;;
        --only-action) only_action="${2:?missing action number}"; launch_args+=("$1" "$2"); shift 2 ;;
        --checkpoint) checkpoint="${2:?missing checkpoint path}"; launch_args+=("$1" "$2"); shift 2 ;;
        --start-action) start_action="${2:?missing start action}"; launch_args+=("$1" "$2"); shift 2 ;;
        *) printf 'Usage: %s [--dry-run] [--replay PATH --headless PATH] [--only-action N] [--checkpoint PATH --start-action N]\n' "$0" >&2; exit 2 ;;
    esac
done
[[ "$only_action" =~ ^[0-9]+$ && "$start_action" =~ ^[1-9][0-9]*$ ]]
if [[ -n "$checkpoint" ]] && (( only_action < start_action )); then
    printf '%s\n' 'Checkpoint replay needs an --only-action at or after --start-action.' >&2
    exit 2
fi
if [[ -z "$checkpoint" ]] && (( start_action != 1 )); then
    printf '%s\n' '--start-action requires a checkpoint.' >&2
    exit 2
fi

export FEL20_ONLY_ACTION="$only_action" FEL20_START_ACTION="$start_action" FEL20_CHECKPOINT="$checkpoint"
export LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1
command -v ffmpeg >/dev/null

labels=(descent)
replays=("${replay:-$tool_dir/replay.jsonl}")
headless_files=("${headless:-$tool_dir/headless-evidence.jsonl}")
if [[ -z "$replay" && -z "$headless" ]] && (( only_action == 0 )); then
    labels+=(defeats)
    replays+=("$tool_dir/replay-defeats.jsonl")
    headless_files+=("$tool_dir/headless-defeats.jsonl")
elif [[ "$replay" == *replay-defeats.jsonl ]]; then
    labels=(defeats)
fi

windowed=(
    python3 tools/visual_probe_runner.py --task-id fel-20 --no-headless
    --display-driver macos --timeout "$timeout" --expect-size 1920x1080
    --proof-contract tools/fel20/proof_contract.json
)
if (( ! dry_run )); then
    capture_root="$tool_dir/captures"
    mkdir -p "$capture_root"
    touch "$capture_root/.gdignore"
    run_dir="$(mktemp -d "$capture_root/native.XXXXXX")"
    printf 'FEL20 NATIVE OUTPUT %s\n' "$run_dir"
fi

reports=()
for index in "${!labels[@]}"; do
    export FEL20_RUN_LABEL="${labels[index]}"
    export FEL20_REPLAY="${replays[index]}"
    evidence="${headless_files[index]}"
    python3 tools/fel20/report.py check "$FEL20_REPLAY" "$evidence" --only-action "$only_action"
    if (( dry_run )); then continue; fi

    FEL20_OUTPUT="$run_dir/$FEL20_RUN_LABEL"
    export FEL20_OUTPUT
    mkdir "$FEL20_OUTPUT"
    python3 -u tools/fel20/report.py capture-worker "$FEL20_OUTPUT" > >(tee "$FEL20_OUTPUT/capture.log") 2>&1 &
    worker=$!
    trap 'touch "$FEL20_OUTPUT/capture-finished"; wait "$worker" || true' EXIT
    "${windowed[@]}" --result-manifest "$FEL20_OUTPUT/visual-proof.json" tools/fel20/census.gd \
        2>&1 | tee "$FEL20_OUTPUT/runner.log"
    touch "$FEL20_OUTPUT/capture-finished"
    wait "$worker"
    trap - EXIT
    python3 tools/fel20/report.py check "$FEL20_REPLAY" "$evidence" --only-action "$only_action" \
        --capture "$FEL20_OUTPUT/native.jsonl"
    reports+=(--headless "$evidence" --native "$FEL20_OUTPUT/native.jsonl")
done
if (( dry_run )); then
    printf 'FEL20 WINDOWED COMMAND cd %q && bash tools/fel20/native.sh' "$PWD"
    if (( ${#launch_args[@]} )); then printf ' %q' "${launch_args[@]}"; fi
    printf '\n'
    exit 0
fi

python3 tools/fel20/report.py report "${reports[@]}" --output "$run_dir/census.md"
if [[ -z "$replay" && -z "$headless" ]] && (( only_action == 0 )); then
    cp "$run_dir/census.md" "$tool_dir/census.md"
fi
printf 'FEL20 NATIVE REPORT %s/census.md\n' "$run_dir"
