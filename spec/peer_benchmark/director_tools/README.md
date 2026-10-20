# Director helper scripts (backup)

Working copies live in the session scratchpad, which macOS temp cleanup can delete. These are the durable copies:
merge and post-merge with full suites (merge_unit.sh, post_merge*.sh), the Codex review runner (codex_review.sh with
the rr13_review.txt header), windowed proof chains (unit_proofs.sh), the watchdog loop (watch_loop2.sh), JSON 3-way
merge (json3.py), conflict-hunk replacement (resolve_hunks.py), and the shadow-cache prefix refresh
(shadow_refresh_prefix.gd.txt; rename to .gd to run it). Paths inside the scripts point at the scratchpad.
