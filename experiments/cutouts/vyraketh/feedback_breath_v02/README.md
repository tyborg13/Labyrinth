# Vyraketh feedback motion revision

This case forks the accepted `../v01` art and uses the current production motion
as its baseline. The original paintings, ownership, rig layout and hidden
surfaces are retained. `kindle` now commands Meteorfall by lifting the crown and
wings; `cinderfall` is a low mouth breath with chest support, neck preparation,
jaw opening, extension and recovery. The shared runtime profile maps semantic
intent/action IDs to these clips and retains the committed action direction.

Area clips last 1.1 seconds. Breath release maps to authored phase 0.55 at 0.30
of the action and phase 0.65 at impact 0.52; other casts reach phase 0.55 at
0.52. Physical Maw keeps its 0.42 contact. Case timelines match these runtime
curves. The production sampler is `scripts/vyraketh_cutout/motion.gd`.

Run the maintained `cutout_workflow.py validate`, `render` and `verify-render`
commands against this case. Native production integration, acceptance paths,
and remaining limitations are recorded in
`playtest/dragon_presentation_feedback_notes.md`.
