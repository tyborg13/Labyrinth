# art-07 — round 3 (Codex peer review of ac2d62eaf: one medium finding)

Work on top of ac2d62eaf. Do not commit.
A fully masked reference (a valid derived mask covering the entire front) raises "non-accent measurement needs opaque
pixels" at `tools/art_identity_gate.py:319` before the empty-body guard, with or without `--allow-protected-share`.
Handle zero opaque samples before the mask/percentile calculation: without the flag fail with the same clear empty-body
message; with it, take the explicit skip path (`skipped: "empty reference"` or the existing reason extended to name
which image), and update the skip validation (~:1011). Add process, replay and check coverage for a fully masked
reference. Proof: gate tests, registry check, replay of all raw_steps kits byte-identical.
