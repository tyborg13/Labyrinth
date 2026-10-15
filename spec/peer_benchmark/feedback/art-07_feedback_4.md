# art-07 — round 4 (Codex delta review of 90f0e99d3: one medium finding)

Work on top of 90f0e99d3. Do not commit.

One **Medium** finding remains in [tools/art_identity_gate.py:1061](/private/tmp/labyrinth_codex/review/art-07-90f0e99d3/tools/art_identity_gate.py:1061): opacity validation depends on the recorded skip reason, allowing inconsistent records through when raw inputs are unavailable.

Reproduced using the fully masked fixture:

- Change `skipped` to `"empty body"` and both share fields to `{"front": 1.0, "rear": 0.0}`.
- Update the registry’s matching `post_steps`, then remove `refs/raw.png`.
- `check_registry` reports **PASS: 0 failures, 1 skipped replay**.
- Removing all four skip fields also passes. Both cases fail when raw inputs remain available.

**Fix:** derive the required skip reason from the bound reference’s opacity. A fully transparent reference must require `"empty reference"`, the override, and both explicit null shares regardless of the supplied reason. Add both cases to [the regression test](/private/tmp/labyrinth_codex/review/art-07-90f0e99d3/tests/test_art_identity_gate.py:1400).

Verification completed:

Proof: gate tests incl. both tampering cases, registry check, raw_steps replay byte-identical.
