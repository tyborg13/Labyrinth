# Escape the Umbra Player-facing UI Rubric

## Status and scope

This is the required acceptance rubric for creating, changing, or reviewing player-facing UI. It covers layout, copy, HUD state, cards, menus, tooltips, tutorials, input feedback, motion, accessibility, and visual effects used to communicate game state.

The rubric is not a mandate to replace clear text with obscure icons. Escape the Umbra is a tactical card game: exact rules text is often gameplay-critical. Keep that text precise, then use hierarchy and progressive disclosure so it does not compete with the immediate decision.

## Product anchors

- The board, actors, cards, turn clock, and current decision are the visual center. Framing should clarify them, not cover or outshout them.
- Reuse the established dark wood/parchment, inset metal, brass, ember, and distressed-fantasy vocabulary. Start with `UiSkin`, `UiTypography`, `UiTooltipPanel`, `CardWidget`, existing icon libraries, and `spec/ui_button_system.md` before creating a new component or visual language.
- The authored canvas is `1920x1080`. Current proof surfaces also exercise `1280x720` and handheld-shaped `1280x800`; the window system can reach `960x540`. Player UI scale supports `90%`, `100%`, `115%`, and `125%`, and motion can be reduced.
- Input support is a capability of the current branch/build, not a permanent assumption. Preserve every input path the changed surface already supports. When controller or Steam Deck support is present, navigation, focus recovery, activation, back/cancel, and active-input cues are first-class requirements. Do not fabricate device glyphs or claim a path the complete surface does not support.

## Required design statement

Before implementation, write a compact design statement in the task notes or commentary:

1. **Surface:** combat HUD, card/inspection, reward, merchant, loadout, map/room choice, dialogue/tutorial, settings, confirmation, or another named surface.
2. **Player question:** the one question the UI must answer now.
3. **Primary action:** the action that advances the current decision.
4. **Hierarchy:** what is persistent, contextual, available on focus/selection, and optional detail.
5. **Interaction paths:** every path the current surface supports, including pointer, keyboard, controller, and Steam Deck behavior as applicable.
6. **Proof matrix:** changed states, target sizes, UI scales, and the focused probe that will render them.

If these cannot be stated clearly, the screen is not ready to implement.

## Acceptance rubric

Rate every row **Pass**, **Exception**, or **Fail**. A change is ready only when it has no Fail rows. An Exception must name the exact deviation and why it improves comprehension, precision, accessibility, or the requested experience.

| Gate | Pass condition | Common failure |
| --- | --- | --- |
| Immediate comprehension | A static frame makes the current state, current selection, and next meaningful action identifiable without reading a paragraph. | The UI explains the whole system before showing what can be acted on. |
| Visual hierarchy | One action or decision is visually primary; critical state outranks secondary facts and decoration. | Several panels, banners, or buttons compete at the same weight. |
| Gameplay visibility | The board, cards, targets, and consequences needed for the decision remain visible and legible. | A modal or persistent panel covers the evidence needed to choose. |
| Compact, precise copy | Copy follows the budgets below; exact rules text is progressively disclosed where needed. | Instructional paragraphs, redundant labels, or flavor text precede mechanics. |
| State and consequence | Available, selected, focused, disabled, dangerous, unaffordable, and resolved states are distinguishable; disabled choices expose the reason when useful. | Color-only state, ambiguous selection, or an action with no visible result. |
| Interaction completeness | All required information and actions are reachable without hover; every supported input path remains complete, with visible focus wherever navigation uses it. | Hover-only mechanics, invisible focus, tiny targets, mouse-only dismissal, or a stranded keyboard/controller path. |
| Visual cohesion | Existing typography, spacing, panels, buttons, icons, cards, and tooltips are reused or deliberately extended. | A one-off skin, generic dashboard pattern, or duplicate component vocabulary. |
| Accessibility | Meaning is not carried by color, motion, or audio alone; type remains readable; UI scale and reduced motion are respected. | Clipping at larger scale, low contrast over gameplay, or essential animation with no static end state. |
| Layout resilience | The changed surface remains operable without clipping, overlap, or unreachable controls at its required sizes and scales. | The default view works, but a smaller window, long copy, or `125%` UI scale breaks it. |
| Visual proof | Fresh screenshots show the real changed surface and relevant interaction states; the implementer inspects the pixels, not only file existence. | Code-only proof, stale images, a synthetic mockup, or one happy-path resolution. |

## Copy and disclosure budgets

These are defaults and review tripwires, not reasons to prefer ambiguity.

- **HUD and board state:** use icons, meters, counters, short state labels, target previews, and spatial cues. Do not place instructional paragraphs in the persistent combat view.
- **Actions:** prefer a clear verb or destination, usually one to three words. A longer label is acceptable when it prevents ambiguity; a sentence explaining how to press the button is not.
- **Context prompts:** show the established shortcut or active-input cue plus the action when the input is known. Use the current device/glyph system when one exists; never fabricate a device glyph or hard-code a cue that becomes false after input handoff.
- **Hover tooltips:** show a title and compact facts, usually followed by no more than one short mechanic explanation. Put tactical teaching in a contextual tutorial, Grimoire, or pinned detail view.
- **Cards, relics, and equipment:** preserve exact mechanic text. Lead with the effect and costs, use the shared icon vocabulary for recurring actions/statuses, keep flavor subordinate, and reserve expanded detail for selection, pinning, or inspection.
- **Modals:** prefer a title, the consequence, one primary action, and back/cancel. Keep gameplay instruction to two short sentences or fewer unless the surface is an explicit detail, narrative, settings, or accessibility view.
- **Tutorials:** teach one decision at a time, next to the relevant object or action; show the state, let the player act, then confirm the result. Do not make the first-time path depend on a wall-of-text help panel.
- **Dialogue and lore:** longer prose is allowed because reading is the activity. Menu instructions around it remain concise.

Revise copy that repeats a visible label, narrates navigation, starts with flavor before the mechanic, or describes a state that could be shown directly. Keep text when an unfamiliar icon would be slower or less accessible.

## Screen rules

### Combat HUD and board

- Keep moment-to-moment state at stable edges and immediate target/consequence feedback near the board.
- Use at least two distinguishable cues for critical alerts: icon or shape plus color, label plus color, or a visual cue plus sound.
- Animate to show cause, transition, urgency, or result. Do not keep decorative motion competing with turn, target, damage, or Umbra cues.
- Keep actors and interactable objects crisp above atmosphere and effects; do not let Umbra, particles, glows, or overlays erase silhouettes or actionable tiles.

### Cards and detailed inspection

- Use the card face for scan-level identity, cost, recurring action icons, and concise rules. Put comparisons, expanded definitions, and flavor in the selected/pinned detail layer.
- Keep action icons consistent with `ActionIconLibrary`; unfamiliar or rare symbols need a label or accessible explanation until learned.
- Do not shrink rules text to make an overfilled card fit. Edit copy, reduce decoration, or move secondary detail instead.

### Rewards, merchants, loadouts, and progression

- Make the offered object, cost, affordability, ownership/equipped state, and stat or deck consequence visible before confirmation.
- Keep mechanics above flavor. Show unavailable or unaffordable state with more than a color shift and expose the missing requirement.
- Prefer selection objects and focused detail over a default wall of rows or prose. Keep one clear commit action and one back/cancel path.
- Show recurring learned abilities as semantic icon-led selection objects with one focused detail region. Do not turn a compact ability set into a dropdown or a stacked list of repeated rules paragraphs.
- A skill tree or dependency graph must preserve its complete topology and focused-node rules in one frame through fit-to-view or responsive reflow. Do not put horizontal or vertical scrollbars anywhere on the skill-tree surface.

### Map, room choice, and dialogue

- Show destination, risk/reward cue, and availability at the point of choice.
- Keep choices short and visually separate from narrative text.
- Do not let dialogue, location copy, or decorative framing hide the route or action being selected.

### Settings and destructive confirmations

- Settings may be text-heavier; group them by player effect and use the existing controls, typography, UI-scale, and reduced-motion behavior.
- Describe what a setting changes for the player, not how it is implemented.
- A destructive confirmation names the action and consequence. The dangerous action is visually distinct and is not the default focused choice.

## Visual and interaction language

- Use `UiSkin` variants and native sizes for action buttons. Do not introduce a stretched bitmap, bespoke button family, or web-style pill control for a surface already covered by the shared system.
- Use `UiTypography` roles, floors, spacing, and responsive helpers instead of ad hoc font sizes or squeezing text until it fits.
- Use `UiTooltipPanel` and established pin/focus behavior for normal player tooltips. Do not put required mechanics behind hover alone.
- Icons must remain distinguishable by silhouette and not by hue alone. Use icon plus short label when the symbol is new, uncommon, or ambiguous.
- Follow `spec/icon_identity_policy.md`: every distinct ability, relic, equipment item, keyword, status, resource, or other icon-bearing identity owns a purpose-built icon. Shared paths, byte-identical copies, recolors, and generic category stand-ins do not count as unique icons.
- Preserve distinct normal, hover, pressed, selected, focused, and disabled states where those states exist. Interaction feedback must be visible against the actual game background.
- Avoid generic web/app defaults: dashboard grids, repeated flat cards for unrelated settings, pill-badge overload, form labels that narrate obvious controls, and ornamental whitespace that pushes the decision off-screen.
- Never solve density by hiding the current decision, reducing type below the shared readability floor, or relying on scrolling for a small set of primary actions.
- Horizontal scrollbars are prohibited in player-facing gameplay and progression UI. A content-native timeline or carousel requires a documented Exception and must use deliberate paging or direct manipulation rather than a desktop scrollbar.

## Resolution, scale, and state proof

Use the repository's task-safe probe workflow. A visually changed surface needs a focused probe; extend an existing one when it already owns the surface.

1. Render at the screen's normal `1920x1080` presentation and at least one constrained presentation, normally `1280x720`. Use `1280x800` for every Steam Deck/controller surface and any handheld-sensitive layout. If the surface is reachable at the `960x540` minimum window size, verify operability there or document the known pre-existing constraint.
2. Exercise `100%` and `125%` UI scale for scalable/dense surfaces. Include the constrained size at the largest relevant scale when practical.
3. Capture every changed state that can materially alter comprehension or geometry: normal, hover/focus, selected, disabled/unaffordable, warning/error, expanded detail, and before/after result as applicable.
4. Use fresh versioned screenshot filenames. Inspect every delivered image at the exact review resolution and check clipping, overlap, legibility, hierarchy, background contrast, and gameplay occlusion.
5. Exercise every input path the changed surface currently supports. Verify pointer behavior, keyboard focus/order, and controller/Steam Deck focus traversal, activation, back/cancel, and focus recovery as applicable. Verify input-device handoff and displayed cues when an active-input system exists. Also verify reduced-motion behavior for new motion.
6. Run focused logic/tests in addition to visual proof when actions, persistence, or state transitions change. A screenshot cannot prove behavior; a test cannot prove presentation.

Relevant starting points include `tests/ui_probe.gd`, `tests/button_system_probe.gd`, `tests/settings_probe.gd`, `tests/tooltip_consistency_probe.gd`, and screen-specific probes under `tests/`. Run them through `tools/visual_probe_runner.py` in isolated tasks.

## Automatic rejection tripwires

Revise before handoff when any of these is true without a documented Exception:

- A gameplay surface adds a paragraph of instruction instead of revealing state and action contextually.
- A compact set of recurring abilities is presented as a dropdown or repeated paragraph rows when semantic icons plus one selected/focused detail region can expose the same information.
- Two distinct player-facing concepts reuse an icon path, copied asset, recolor, or generic category symbol instead of owning distinguishable purpose-built icon identities.
- A player-facing gameplay or progression surface exposes a horizontal scrollbar, or any part of a skill tree/dependency graph exposes horizontal or vertical scrolling.
- Essential state or instruction exists only as text, color, hover, animation, or sound when a second practical cue is available.
- The primary action, selection, disabled state, or dangerous action is visually ambiguous.
- A panel hides the board, card, target, price, comparison, or consequence needed to decide.
- Text is shrunk below shared typography roles, controls clip, or required actions become unreachable at a required proof configuration.
- A new component or visual vocabulary duplicates an existing shared pattern without a concrete need.
- A changed surface drops or strands a previously supported pointer, keyboard, controller, or Steam Deck path.
- Input glyphs imply support that the complete screen and active-device system do not provide.
- Visual work is handed off without fresh, inspected, real-renderer proof.

## Handoff record

Report:

- the surface, player question, and primary action;
- the hierarchy and any copy/icon conversions;
- reused or extended shared components;
- interaction and accessibility states checked;
- probe commands plus screenshot paths, resolutions, and UI scales;
- each rubric row as Pass or Exception, with reasons for every Exception;
- remaining risks or pre-existing constraints.
