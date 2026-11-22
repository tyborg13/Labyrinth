# Terminal profile-write failure probe

Run from the gfix-28 worktree. Each phase starts a separate Godot process and
uses the same profile, run checkpoint and JSONL directory for its case. Use a
fresh output directory for each pass.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-28
mkdir -p output/gfix-28
python3 tools/output_gdignore.py
proof_dir=$(mktemp -d "$PWD/output/gfix-28/relaunch.XXXXXX")
for outcome in victory defeat; do
  for choice in choose choose-retry; do
    for phase in fail "$choice" recover verify; do
      LABYRINTH_DEMO=0 python3 tools/godot_task_runner.py --task-id gfix-28 --stream -- \
        godot --headless --path . --script tools/gfix28/terminal_relaunch.gd -- \
        "$proof_dir/$outcome-$choice" "$outcome" "$phase" \
        > "$proof_dir/$outcome-$choice-$phase.log" 2>&1 || exit 1
    done
  done
done
```

`fail` blocks the terminal profile write and exits through the game's desktop
quit handler. The next process continues from disk and leaves an heirloom with
the profile still blocked. `choose` keeps the block through quit. `choose-retry`
restores writes before quit. `recover` continues and confirms the saved choice.
`verify` reads the final disk state and counts the actual JSONL rows.
