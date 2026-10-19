# mq-08 feedback 1 (director, from the Codex review at 46fbff1fe)

The geometry is accepted (shoulder rise 66.3 px as level 3D shoulders, pauldron 159/93 vs head 68, true turn, limb
lengths kept). The director is already painting over these clays: the delivered clays, part maps and joints must not
change in this round. Two findings remain (review: `/private/tmp/labyrinth_codex/review/mq-08-46fbff1fe.md`):

1. **Tests must exercise the live guards.** `tests/test_glacial_mirror_shoulder.py` excludes the pauldron centre (line
   68) and trusts the saved report's `passed` flag (line 104). Assert the measured delivery values (both shoulders,
   the shoulder rise against the rule, both shoulder-mass tops and the head top, the turn transform). Run the live
   shoulder, pauldron, turn and partial-capture-mode gates on invalid fixtures (a far cap moved 80 px up in both the
   migration and the canonical recipe; a lowered far shoulder; a mirrored rear; a partial capture) and require each to
   fail. A partial capture can never receive full-delivery certification. The review's five surviving mutations must
   now be caught.
2. **Regeneration starts clean.** `glacial_mirror/workflow.py` merges into an existing project (line 113) and always
   records `cache_reused: false` (line 289). New runs require fresh, empty directories. A resumed run preserves and
   validates the original input-only inventory and refuses generated outputs (`.blend`, cloth caches, captures) as
   inputs. Report `cache_reused` truthfully. Refresh the affected regeneration proof through the bridge.

Proof: the focused maquette, delivery and art-identity tests, the new invalid-fixture tests, a mutation table (each
guard removed → caught), and the refreshed regeneration comparisons (clays and part maps unchanged). No full suites.
