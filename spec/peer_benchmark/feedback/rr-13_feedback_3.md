# rr-13 feedback 3 — close the 12 seam pinholes (final round)

The director inspected the 12 new flags from your stricter hole gate. Evidence:
`spec/peer_benchmark/feedback/rr-13_f3/new_holes_sheet.png` on integration (hole marked magenta; 512 proof canvas).

**They're real seam pinholes**, enclosed inside the body at a joint, not negative space beside it. Close them with
hidden continuations. Don't add exceptions and don't relax the gate.

| Frames | Where (512 canvas) | Seam | Fix |
|---|---|---|---|
| front `mark` 18, 22, 48, 49 | ~(226–231, 267–269) | torso / `upper_far` (staff shoulder, arm raised) | extend the torso's hidden continuation under the far shoulder and upper sleeve, or deepen the `upper_far` tuck into the torso |
| rear `mark` 20, 21, 22 | ~(207, 254) | torso / `upper_near` (armpit) | the same at the rear near armpit |
| front `death` 27–30 | ~(244, 272–273) | robe / torso (waist side) | extend the robe top's hidden continuation up under the torso there |
| front `death` 68 | ~(282, 232) | head / torso / `upper_near` (top edge) | extend the torso's (or collar's) continuation under the head and near shoulder at that edge |

Rules (unchanged from the brief):
- Fills read as the adjoining cloth (dark-slab gate) and stay hidden at rest: rest identity 0 px in both views.
- No motion, painting, exception-list or runtime changes.
- Keep your feedback-2 gate and test changes as they are. The two historical captured-body tests that now return `[2]`
  must pass because the openings are closed: regenerate their committed fixtures only from the fixed fills, and never
  weaken an assertion.

Proof (headless; the GPU captures are stale until the director recaptures):
1. Run the same posed-owner and joint-hole logic over CPU-posed layers, with the new fills, for every clip and frame
   in both views. Report zero new joint holes beyond the director-approved exceptions, and list any you can't close.
2. Run the focused tests (rr10 Python, `test_rr07_production`, `test_maquette_rear_turn`, the headless rr10/rr07
   runtime checks).
3. Stop, and give the exact windowed `native`, `sheets` and `review` commands; the director runs them.
4. Put scratch logs and crops under `/private/tmp/labyrinth_codex/rr-13/`, not elsewhere in `/private/tmp`.

This is rr-13's last fix round. Anything you can't close goes in the result for the director to decide.
