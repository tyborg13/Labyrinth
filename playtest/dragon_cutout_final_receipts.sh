#!/usr/bin/env bash
# Invoke only after root grants the final renderer lease and source freeze.
# Thin command batch; no case, production, Git or pipeline mutation.
set -euo pipefail

if [[ $# -ne 2 || ( "$1" != render && "$1" != verify ) ]]; then
  printf 'Usage: bash %s {render|verify} /absolute/fresh-receipt-root\n' "$0" >&2
  exit 2
fi
mode="$1"
receipt_root="$2"
[[ "$receipt_root" == /* ]] || { printf 'Receipt root must be absolute.\n' >&2; exit 2; }
task_id=dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
names=(iskaldra zekarion noctyrax lightning_wisp vaeloryx vyraketh tharokh)
variants=(feedback_v02 feedback_v02 feedback_v02 feedback_v02 feedback_v02 feedback_seams_v03 feedback_seams_v03)
frames=(560 480 608 336 480 656 576)

if [[ "$mode" == render ]]; then
  [[ ! -e "$receipt_root" ]] || { printf 'Choose a fresh receipt root; this one exists: %s\n' "$receipt_root" >&2; exit 2; }
  # Confirm authoring samplers still represent the promoted production motion.
  for i in "${!names[@]}"; do
    cmp "experiments/cutouts/${names[$i]}/${variants[$i]}/motion.gd" "scripts/${names[$i]}_cutout/motion.gd"
  done
  mkdir -p "$receipt_root/logs"
  python3 tools/cutout_workflow.py doctor | tee "$receipt_root/logs/doctor.json"
  cat > "$receipt_root/index.md" <<'INDEX'
# Final dragon cutout receipts

Automated capture/verification in progress. Visual inspection remains pending.
Each case's proof directory is immutable; reports and this index are outside it.

| Case | Variant | Expected timed board frames | Timed reel | Render report |
| --- | --- | ---: | --- | --- |
INDEX
  for i in "${!names[@]}"; do
    name="${names[$i]}"
    variant="${variants[$i]}"
    python3 tools/cutout_workflow.py render "experiments/cutouts/$name/$variant" \
      --output "$receipt_root/$name" --task-id "$task_id" --backend metal \
      | tee "$receipt_root/logs/$name-render.json"
    printf '| %s | %s | %s | [%s reel](%s/videos/cutout_review.mp4) | [report](logs/%s-render.json) |\n' \
      "$name" "$variant" "${frames[$i]}" "$name" "$name" "$name" >> "$receipt_root/index.md"
  done
else
  [[ -d "$receipt_root/logs" ]] || { printf 'Missing existing receipt root: %s\n' "$receipt_root" >&2; exit 2; }
fi

# Recheck every earlier capture after the last one. This rejects any intervening
# source change, including changes unrelated to the character being rendered.
for i in "${!names[@]}"; do
  name="${names[$i]}"
  python3 tools/cutout_workflow.py verify-render "experiments/cutouts/$name/${variants[$i]}" \
    --output "$receipt_root/$name" | tee "$receipt_root/logs/$name-verify-final.json"
done

if [[ "$mode" == render ]]; then
  cat >> "$receipt_root/index.md" <<'INDEX'

All seven final automated verifications passed after the final capture.
This does not mark visual inspection complete. Inspect full front/rear cycles,
maximum-motion seams, board-scale poses and both editable-scene roundtrips before
recording acceptance in the owning notes. Final verifier reports are under logs/.
INDEX
fi
printf 'Seven current-source receipts verified: %s/index.md\n' "$receipt_root"
