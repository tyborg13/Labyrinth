# Natural-Unit Lethality and Run-Pacing Playtest

Date: 2026-07-27

Harness: `tools/headless_playtest.gd`

Seeds: `7272601`, `7272602`, `7272603`

## What was exercised

- Natural-unit player and enemy health, damage, block, healing, traps, and fatigue.
- Early-depth lethality, kill-refund chains, movement pressure, and room-layout variance.
- Scarcer recovery: 2 HP Patch Up, 3 HP post-combat recovery, and 2 HP room vial.
- The depth-1 outward route and the three-room anti-farming fallback.

## Results

| Seed | Observed segment | Turns | Net HP | Read |
| --- | --- | ---: | ---: | --- |
| 7272601 | First depth-1 normal | 6 | -14 after Patch Up | A credible early failure trajectory. One-hit kills were available, but bleed costs, a clock mistake, and an enemy hit made poor sequencing expensive. |
| 7272601 | Second depth-1 normal | 4 | +2 from Patch Up | Trap use and one-hit finishers produced a fast, clean room. A native outward move to depth 2 appeared after only two depth-1 rooms. |
| 7272602 | First depth-1 normal, partial | 6 before harness timeout | -3 after Patch Up | A very separated layout made movement and a defensive enemy consume extra turns. Player damage still removed the first two enemies quickly; the final Warden had 11 HP after the sixth-turn opening action. |
| 7272603 | First depth-1 normal | 3 | 0 | Three enemies died to two or fewer damage cards each. A trap and kill-refund chain accelerated the finish without removing positioning decisions. |

The three completed rooms span three, four, and six turns. Incoming pressure spans a flawless clear through a 58% max-health loss, which is the intended high-variance early-run shape: decisive play can preserve the clock, while inefficient play can put the run on a short failure path.

## Balance read

- Keep the current damage values. The slow seed was dominated by room separation and setup choices, not low damage.
- Keep recovery at its reduced values. The 3 HP reward could not erase the 14 HP loss, while Patch Up remained worth playing in both damaged runs.
- Keep the outward-route fallback at three visited rooms on a depth. The sampled run offered a natural deeper route even earlier, and the fallback prevents a hostile map roll from enabling indefinite same-depth routing.
- The harness does not model wall-clock animation/reading time faithfully and this round did not attempt a complete multi-hour run. The automated pacing targets and analytics fields should therefore be used to evaluate 10–120 minute run distribution as live run telemetry accumulates.

Raw notes and analytics are in `playtest/balance_round_20260727_01`, `_02`, and `_03`.
