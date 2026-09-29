# Move-and-attack approach selection

Selecting a move-then-attack card keeps the existing one-click enemy shortcut.
Entering an attack target from a legal movement endpoint temporarily chooses
that endpoint. The movement arrow, attack origin, damage/force preview and
turn consequences use that exact plan. Clicking or releasing the dragged card
executes it. Re-entering from another legal endpoint changes the preview without
spending the card. Coming from an invalid, unreachable, or out-of-range tile
uses the existing automatic choice. Hovering the player's current tile can
choose the existing movement-skip strike when legal.

This chooses an ending square; pathfinding still chooses the route to that
square. The exact movement and follow-up simulation must permit the attack.
A dangerous but survivable approach is allowed and retains its existing risk
chips. An interrupted or lethal movement cannot promise a strike from the
requested endpoint. Existing visibility rules still filter both route and target.
No card values, costs, action order or balance assumptions change.

The preference belongs to one targeting selection. Moving inside a large
actor's footprint keeps its original entry square; leaving it and re-entering
chooses again. Leaving the board, changing the selected card/action or combat
state, cancellation, hovering a turn-order portrait, or changing input device
clears the preference. Drag-to-click handoff preserves the current selection.
Controller board focus uses the same entry rule, with existing focus and
confirm/cancel controls. Existing movement-only clicks remain available.

`MoveAttackApproach` owns the transient entry and its memoized exact plan.
Default shortcut maps remain unchanged. Its revision joins the turn-preview
cache key so approaching the same enemy from two sides cannot reuse the first
side's consequences. Both presentation and commitment ask `_shortcut_plan_for_tile`.
Analytics retain the endpoint and enemy in `selected_targets`, one
`target_decision_count`, and no hover events (see [analytics](analytics.md)).

## UI design and proof

Surface: selected combat card targeting. Player question: “Where will I stand
when I hit this enemy?” Primary action: enter the enemy from the desired square
and confirm once. The existing board route and attack-origin preview communicate
the choice; the hand, card rules and target highlights retain their hierarchy.
No new text, icons, panels or motion are needed. Pointer click, card drag and
controller focus share the behavior; cancellation and device handoff clear it.

`tests/suites/move_attack_approach_suite.gd` covers legal alternatives, re-entry,
stable same-tile hover, fallback, reset/cache boundaries, adjacent stay-put vs
repositioning, movement hazards, Blink, large footprints and hidden targets.
It runs in the full suite. `tests/move_attack_approach_probe.gd` exercises live
RunScene pointer, drag, controller and reduced-motion paths, checks the arrow
and attack origin before committing, then verifies position, damage, Time,
selection completion and the actual local analytics event. It also checks
cancel/reselect and input handoff. Headless execution runs the same assertions;
real-renderer execution captures native 1920x1080 frames at 100% UI scale.

Task-local commands (run from the task worktree):

```sh
python3 tools/godot_task_runner.py --task-id hover-approach-chooses-move-attack-destination --stream -- godot --headless --path . --script tests/move_attack_approach_probe.gd
python3 tools/godot_task_runner.py --task-id hover-approach-chooses-move-attack-destination --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/move_attack_approach_probe.gd --task-id hover-approach-chooses-move-attack-destination --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080
```

Rubric inspection at 1920x1080 / 100%: immediate comprehension, visual hierarchy,
gameplay visibility, compact precise copy, state/consequence, interaction
completeness, visual cohesion, accessibility, layout resilience and visual proof
all Pass. Existing turquoise movement arrows visibly choose different sides of
the enemy; the orange attack target and predicted HP remain present. Controller
focus and existing device prompts remain visible, and the hand recovers after
confirmation. Reduced motion preserves the same static route. No UI exceptions
or new icon identities. This is an inspection prototype; whether entry-based
selection feels natural during ordinary play still needs player feedback.
