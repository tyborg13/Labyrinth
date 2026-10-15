# art-07 — round 2 (director: TODO_DESIGN_EMPTY_BODY_OVERRIDE)

Protected shares 1.9–7.2% and the bright cores are accepted. Decision for the empty-body case: without
`--allow-protected-share` it fails (as now). With the flag, `process` **skips** the palette match and records the step as
`{"kind": "palette_match", "skipped": "empty body", "protected_share": …}` in the sidecar (replay reproduces the skip; check
verifies it); never a silent no-op. Test both paths. Do not commit.
