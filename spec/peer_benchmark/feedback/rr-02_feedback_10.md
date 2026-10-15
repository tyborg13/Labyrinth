# rr-02 — round 10 (Codex delta review of 4fe2e1fe6: one medium finding; everything else fixed)

Work on top of 4fe2e1fe6. Do not commit. Full review: /private/tmp/labyrinth_codex/review/rr-02-4fe2e1fe6.md.

**Medium — categorical-mask validation remains incomplete.** [motion_gates.py:494](/private/tmp/labyrinth_codex/review/rr-02-4fe2e1fe6/experiments/cutouts/chainbound_gaoler/mq3/probes/motion_gates.py:494) does not check mask dimensions, and [line 499](/private/tmp/labyrinth_codex/review/rr-02-4fe2e1fe6/experiments/cutouts/chainbound_gaoler/mq3/probes/motion_gates.py:499) excludes ID zero from validation.

Two independent mutations of a local v09 capture copy **survived** after refreshing the affected output checksum:

- Replace `data/rear_strike/arm_0000.png` with a transparent **1×1** PNG, removing **1,718** arm pixels. NumPy broadcasting silently disables that frame’s containment check.
- In `data/front_idle/owners_0006.png`, change owner **80 → 0** on **eight opaque hidden-thigh pixels**, preserving alpha. Those pixels disappear from hidden-owner measurements.

Both returned **PASS: 458 frames, all seven totals zero, zero value failures**.

**Fix:** require every surface to have the expected 512×512 dimensions, reject zero/unknown owner IDs wherever alpha is opaque, and add both mutations as `native_gates` regressions. Screenshot separation and configurable timeout work, but prior finding 2 is not fully resolved.

Fix: validate every categorical mask's dimensions against its paired frame (fail on mismatch, no broadcasting), and treat owner ID 0 under an opaque pixel as an error (0 is valid only where alpha is 0). Both mutants must fail. Proof: focused tests, saved-v09 native-gate replay; no new windowed run needed unless capture code changes.
