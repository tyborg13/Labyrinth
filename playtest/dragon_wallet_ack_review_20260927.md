# Wallet acknowledgment repair — 2026-09-27

Final independent review traced the native Man receipt's two retained analytics
entries to both wallet handlers: reconciliation acknowledged the profile and
active progression, but UI refresh copied the still-pending embedded run back
into active progression. Later saves could restore the pending entries to disk.
Currency, levels and transaction receipts remained correct; JSONL transaction
keys prevented duplicate events. This was an unfinished acknowledgment, not an
intended long-term retry state.

Both handlers now follow the existing reward-claim pattern: retain the
profile-first purchase commit and initial run checkpoint, reconcile analytics,
synchronize the resulting outbox into the embedded run, then save an
acknowledgment checkpoint before refreshing UI. On append/profile failure the
pending entry survives, so recovery still retries safely. Campfire and Man
level-up share the corrected handler. No event schema or currency rule changes.

`tests/dragon_wallet_ack_test.gd` instantiates the actual authored RunScene and
preserves its real UI refresh. Its narrow test subclass blocks only the profile
acknowledgment write, after the purchase save and real JSONL append. Six cases
cover exchange, Man level-up and campfire level-up, each with successful and
failed acknowledgment. Checks compare active/run/profile/saved-run outboxes,
exact purchase values and sequence, one keyed event, subsequent refresh/save,
and actual saved-state load/retry. New typed-array assignments are not used.

- Baseline: `dragon-feedback-wallet-ack-baseline`, session 97598, exit1;
  nine intended assertions fail (active/run/saved-run for the three successful
  purchase cases). The complete test executes 108 checks.
- Corrected: `dragon-feedback-wallet-ack-fixed`, session 43228, exit0;
  all 108 checks pass. Its three “Failed to acknowledge progression analytics
  event batch” diagnostics are the deliberately injected write failures; there
  are no unexpected parser/runtime errors.
- Logs: `/private/tmp/labyrinth-godot-home/<run-id>/godot.log`.
- Full integrated rerun after this runtime change: `dragon-feedback-integrated-after-wallet`,
  session 63950, exit0 with `TEST RESULT: PASS` inside the default 300-second limit.
  The known legacy migration and ObjectDB cleanup warnings remain; no assertion
  or script error occurred. Independent scoped signoff is recorded below.

The preserved native Man receipt is pre-fix evidence and is not rewritten.
The correction's new evidence is the real-handler regression above; it does not
claim another manual native introduction/trade/level-up session.

## Independent scoped review

Reviewed by `/root/boss_fun_review/fresh_final_review` on 2026-09-27. **Scoped
SIGNOFF: the wallet acknowledgment P2 is resolved.** Both purchase handlers now
copy the reconciled outbox into the run and save it before the real UI refresh
can restore stale entries. A failed append or profile acknowledgment leaves the
pending entries intact; the purchase receipt still prevents repeated spending.

I read the complete six-case regression and all three logs above. The test keeps
the actual scene, purchase handlers, UI refresh, storage and JSONL append; its
only override blocks the profile acknowledgment after the purchase commit. The
baseline reports exactly nine stale-outbox assertions across all 108 checks.
The corrected run passes all 108, including retained retry entries, reload
cleanup, unchanged purchase values and one event per transaction. Its three
acknowledgment errors are the deliberate injections. The integrated log ends in
`TEST RESULT: PASS`, with only the two documented warnings. Runner exit codes
are coordinator-recorded; I did not launch Godot.

Reviewed SHA256 bindings:

- `scripts/run_scene.gd`: `b0bc0dfcfddf5a40e749082abbeb7c42cdc9516bde74c58633782b2b7276921c`
- `tests/dragon_wallet_ack_test.gd`: `928bbb542018c9e964deb015884e2daf66f9123652f0f42c94e974e7bb7dec3d`
- Corrected log: `41ea81301b9d2ce0e1d5fc9dce7bf19cfc2248134b130d370aa49d515b38c88d`
- Integrated log: `8b19320c04301c4426c4194fa1b441102a4a00f64b45776178a3496b1d19c344`

No further wallet finding. This acceptance covers those source bytes and the
bounded regression evidence; whole-task signoff still requires the final
committed HEAD, accepted cutout proof and verified inspection fixtures.
