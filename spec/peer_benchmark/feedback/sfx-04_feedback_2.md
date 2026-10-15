# sfx-04 feedback 2 (director, after peer review of 38db67ae2)

The trims and the router's drop/steal logic are verified. Work on top of HEAD. Do not commit.

1. **Swap lost its sound** (blocker): call `_sfx_router.blink()` in the swap branch (`run_scene.gd` ~24145) on the first
   frame `_animate_surface_change` renders the exchanged positions; add a `player/swap` harness scenario.
2. **Veil blinks stay silent** (blocker; out of scope to add sounds): the router's blink trigger fires only for effects
   with no `actor_key` or `actor_key == "player"`; harness row proving an enemy veil Fade/Ambush blink plays nothing.
3. **Area loudness** (blocker; director decision): contacts that land on the **same frame** play **one** instance (the
   primary) — never stacked copies of the same sample; contacts landing on later frames play the −6 dB layer at their
   own frame. Test: same-frame multi-target hits produce exactly one voice; the sfx-03 100 ms short-window loudness of
   a 3-target same-frame area hit is within ±0.5 LU of a single hit.
4. **Regression checks in the suite** (blocker): run the harness with `--assert-onsets` as a sub-suite of
   `tests/run_tests.gd` (headless; skip cleanly with a clear message only if the sound-lab venv is required and missing —
   prefer a Godot-only path), failing when observations or covered cue × call-site pairs shrink; `--check` writes its
   report to a temp path (never rewrites tracked files); replace the whole-file sha256 and line-number pins in
   `tests/sfx_sync_test.py` with call-site identity by function name + code snippet.
5. **Dragon wings**: request the wing flap on the first frame of **each** move segment (per tile), as before.
6. **Dragon roar** (director decision): the roar starts with the wind-up (as you did), and its peak is aligned to the
   wind-up's release frame (treat the release as the roar's climax in the audit; trim its head if needed per the
   feedback-1 rule).
7. **Docs/data text**: update `spec/audio.md` (area hits, roar, wings) and the `rules.area_hits` description text in
   `data/sfx_cues.json` to the new behaviour (director-authorized text edit; no other changes to that file).
8. `sfx_bank.gd`: set `last_ms` only after a voice is acquired.
9. Make the Reproduce section independent of `/private/tmp` (regenerate features into the repo-ignored lab folder or
   document the command that produces them).

Proof: harness `--assert-onsets` (incl. swap + veil rows), the new suite, sync tests, sound-lab tests, SFX bank,
threats_at_rest, full suite; the updated listening checklist.
