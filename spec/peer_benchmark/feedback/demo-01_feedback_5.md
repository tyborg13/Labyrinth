# demo-01 — round 5 (simplify the lag rule)

My monotonic rule was over-specified. New rule: payloads, order and states identical (unchanged), and every paired
item's offset (native − headless) within [0, 2] frames. Drop the non-decreasing requirement and its tests (replace them
with: a +1,0,0,+1 profile passes; any offset outside [0, 2] fails; any payload/order/state difference fails). Keep the
offset profile in reports. Focused demo tests only; do not commit. Quick round, please.
