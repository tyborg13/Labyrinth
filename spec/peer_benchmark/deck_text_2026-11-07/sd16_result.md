# sd-16 result

**Audit complete; native/hardware verification remains open. No product changes.** Release HEAD `a8bc165f269fef35201d2fdb2b417119f03e6625`, branch `codex/sd-16`; repository clean, no commits/Git writes/review/publication. Only task-local tools, reports and evidence were created under this directory.

| Brief / criterion | Result | Evidence / fix or TODO |
|---|---|---|
| 1. [Controller support](https://partner.steamgames.com/doc/steamhardware/compat#Requirements_for_Steam_Deck_and_Steam_Machine): launch → demo end → title | Headless route PASS | [route receipt](route/route.json): 12/12 milestones, 14/14 tutorial steps, 976 buttons + 256 stick samples; zero pointer/keyboard events. Inherited ux-09 pre-fight refills are receipted; this proves controls, not balance. |
| 1. [Controller access](https://partner.steamgames.com/doc/steamhardware/compat#Requirements_for_Steam_Deck_and_Steam_Machine): all screens | 348/348 controls reached across 36 screens; shared sweep FAIL | [sweep](final-sweep/sweep_after.json): four existing mixed-pointer settings/setup assertions; reproduced with original scripts/tests in [unmodified desktop baseline](unmodified-menu/sweep_menu.json). Pure Deck Settings A→B separately PASS. No assertions rewritten. |
| 1. [Text input](https://partner.steamgames.com/doc/steamhardware/compat#Requirements_for_Steam_Deck_and_Steam_Machine) | Existing wiring PASS with mock Steam | [keyboard.log](keyboard.log): only field is Grimoire Search. Existing helper opens the floating keyboard on controller focus/A, preserves window-pixel coordinates, accepts OS keystrokes/live search, enforces 64 characters and dismisses on focus loss. [Valve API](https://partner.steamgames.com/doc/api/ISteamUtils#ShowFloatingGamepadTextInput) sends keys directly. No fix needed. Real overlay pending Deck. |
| 2. [Controller glyphs](https://partner.steamgames.com/doc/steamhardware/compat#Requirements_for_Steam_Deck_and_Steam_Machine) | No mismatches found | 2,429 glyph observations, zero active-family mismatches; whole route uses `steam_deck`, with zero click/mouse copy cues. Title/settings/end covered. ui-28 remains out of scope: it attaches glyph badges to controls and replaces shared/contextual prompt presentations; none of that branch was applied. |
| 3. [Resolution support](https://partner.steamgames.com/doc/steamhardware/compat#Steam_Deck_Specific_Requirements) | Configuration/geometry PASS; pixels pending | Fullscreen, `canvas_items`/`expand`; route logs 1280×800, 115%, logical 1669.565×1043.478 (16:10). Final sweep uses rounded 1670×1043, correcting the legacy 1503×939 proof fixture. Actual default Deck mode and letterboxing require native inspection. |
| 3. [Text legibility](https://partner.steamgames.com/doc/steamhardware/compat#Steam_Deck_Specific_Requirements) | TODO_DESIGN_DECK_TEXT_LEGIBILITY | Valve's minimum is **9 physical pixels**, with 12 recommended. [Complete candidate list](text-below-9px.csv): 2,116 candidate observations from 6,853 text samples, each with screen, node, text, font size, x-height-equivalent and smallest letter/digit height. Native confirmation required. No font/layout values changed. |
| 4. [Launchers / compatibility warnings](https://partner.steamgames.com/doc/steamhardware/compat#Requirements_for_Steam_Deck_and_Steam_Machine) | Source/route PASS | Direct startup → title, no launcher or keyboard-required first-launch prompt; fresh profile completes tutorial. Native Linux demo export exists; installed Steam launch/default mapping remains hardware proof. |
| 4. Suspend/resume (brief supplement; [Steam resume callback](https://partner.steamgames.com/doc/api/ISteamUtils#AppResumingFromSuspend_t)) | Notification checks PASS; physical sleep pending | [focused log](focused-verified.log): committed checkpoint flush, live combat/action lock preservation, repeated/interrupted suspend and audio restoration. No synthetic hardware-sleep claim. |
| 4. [Default graphics / performance](https://partner.steamgames.com/doc/steamhardware/compat#Requirements_for_Steam_Deck_and_Steam_Machine) | Defaults observed; frame rate pending | Deck default Edge smoothing Off, fullscreen, UI 115%, production cel mode `all`. Valve requires 30 fps at 800p; headless instrumentation cannot establish that. |
| 5. Unambiguous fixes only | No product patch warranted by observed evidence | Keyboard integration already exists; no wrong-family screen found. Font/layout decisions are reserved to the director. Existing sweep failures remain reported for triage. |

Examples: title “Navigate”, size 16: x-equivalent 9.20 px, smallest letter 8.43 px; hand “Sidestep Slash”, size 14: 7.02/6.38 px; Skills “FULL GAME”, size 14: 7.83/7.83 px. These are font-ink metric candidates, not fresh raster approval. Known transparent backing labels are excluded ([receipt](transparent-backing-text.json)); overlapping panels, inline RichText, baked text and animated draw transforms still need pixels. Raw JSON retains original node IDs.

Observed result lines:

```text
SD16 CONTROLLER AND STEAM: PASS (104 checks)
SD16 SUSPEND NOTIFICATIONS: PASS
SD16 FOCUSED RESULT: PASS (113 checks)
GRIMOIRE STEAM KEYBOARD: PASS
GRIMOIRE SEARCH PROBE RESULT: PASS
SD16 DECK SETTINGS BACK: PASS
CONTROLLER SCREEN SWEEP: PASS (0 findings)
CONTROLLER SCREEN SWEEP: FAIL (4 findings)
UX09 CONTROLLER INPUT: PASS { "joypad_button": 976, "joypad_motion": 256, "pointer": 0, "keyboard": 0, "other_gameplay_state_injections": 0, "authorized_refills": "health-refills.jsonl" }
Ran 189 tests in 40.975s
OK
```

The zero-finding sweep line is the isolated Deck Settings-back check; the four-finding line is the full sweep and unchanged desktop menu baseline. [Source audit](source-audit.json) matched all 1,243 files under `scripts/`, allowing only 17 documented proof-hook copies.

Python ran **only the default group** (20 modules); [summary](python-default/summary.json). No full suites or new permanent tests. Final proof script `--check-only`, Python tool compilation, shell syntax and `git diff --check` passed. Initial missing-import probes and a cancelled broad import (130) are retained; final scoped projects used existing imports. Environmental certificate/ObjectDB and focus warnings remain in logs. The read-only Git timing-cache update failed after the Python tests passed; runner exit was 0.

**Proof for the design owner:** [exact native commands and planned capture paths](proof-commands.md), including Deck 1280×800/115%, desktop 1920×1080/100%, and whole-demo cel captures. No windowed attempts or new PNG captures here. Hardware Steam keyboard, sleep/resume, installed default mapping/resolution and frame rate remain open. Inspection fixture: not applicable to an audit with no product changes; the fresh-route and screen probes provide inspection.

**TODO_DESIGN:** `TODO_DESIGN_DECK_TEXT_LEGIBILITY` is a data field in [design-todos.json](design-todos.json). Director supplies sizes/layout after inspecting the candidate screens.

**Chosen defaults:** proof only: x/H/0 reference glyphs; integer logical canvas 1670×1043 derived from the observed release geometry; native screen/route guards 600/14,400 s and luma checks 20/3. Existing sweep fixture seed 73491/reduced motion and ux-09 seed 7/controller timing defaults were retained ([defaults](proof-defaults.json), [tools](tools/)). No player-visible value was chosen.
