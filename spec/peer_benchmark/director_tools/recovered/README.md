# Recovered capture probes (2026-11-03)

The fx-01 and brs-03 native capture probes were never committed and were lost when their worktrees were removed. They were rebuilt from the Codex session logs:
- `replay_patches.py` replays `apply_patch` calls (fx-01);
- `heredocs.py` reads `cat > file <<'EOF'` blocks (brs-03).

The brs-03 contracts were never logged, so they are minimal size and content checks written by the director.

To use one, copy the files into a worktree at the same `tests/` paths, and rename `*.gd.txt` back to `*.gd`.
