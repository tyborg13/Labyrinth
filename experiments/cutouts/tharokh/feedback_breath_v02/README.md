# Tharokh feedback motion revision

This case forks the accepted `../v01` art and uses the current production motion
as its baseline. It preserves the original paintings, rig and ownership. The
new `breath` clip loads the chest while all four claws stay planted, then extends
the neck and head for Bedrock Breath. Stonewake, Faultline and Claw retain their
distinct brace, stamp and rake gestures. The shared runtime profile handles
committed AoE and utility steps by semantic action instead of generic step type.

Utility clips last 0.8 seconds and area clips 1.1 seconds, with result contact at
0.52. Breath release maps to authored phase 0.55 at 0.30 and phase 0.65 at impact.
Physical Claw preserves its existing piecewise mapping and 0.42 contact. Case
timelines match the runtime; the production sampler is
`scripts/tharokh_cutout/motion.gd`.

Use the maintained `cutout_workflow.py validate`, `render` and `verify-render`
commands. The production scene studies and current acceptance status are in
`playtest/dragon_presentation_feedback_notes.md`.
