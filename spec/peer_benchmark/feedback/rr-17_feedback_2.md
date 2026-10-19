# rr-17 feedback 2 (director, from the Codex review at 52f9ca4b2)

Review: `/private/tmp/labyrinth_codex/review/rr-17-52f9ca4b2.md`. The look is approved by the director and posted to
the owner; nothing visual changes in this round. Fix all five:

1. **Sidecars (blocking).** Run the headless import through the task runner and leave every new `.uid`/`.import`
   sidecar for resources this range added (actions.gd, production textures, rr17 test scripts, ...).
   `tests/test_godot_sidecars.py` must pass. Don't add sidecars for the two files that were already missing at the base
   unless the guard requires them.
2. **Simultaneous deaths keep every creature's own clock.** The Capacitor's 147-frame death clock must not stretch
   anyone else's: in a multi-kill, each dying creature advances its own declared sequence. The whole sequence lasts as
   long as the longest one, but every other creature's frames and last-frame time are exactly what the base code gives
   (Seer 1.683 s, Tick 0.883 s and so on). Add simultaneous-kill regressions (Capacitor with each of the six existing
   maquette creatures, plus a case without the Capacitor that is byte-identical to the base).
3. **Every chain hop sounds once.** Emit each crossed hop's cue independently of the displayed hop (`actions.gd:75`),
   so a four-hop Arc Burst plays four hop cues normally, under reduced motion, and when callbacks skip to recovery. Add
   all three regressions. No new sounds; same cues, same order.
4. **Production motion is verified against the protected compilation.** Sample the production rig's motion (not only
   the case copy) and compare it with the protected compiled data; check production bindings too. Keep the review's
   reversed production death lean as a regression mutation that must now be caught.
5. **Shadow checker baseline.** `rr17_shadow_check.gd` takes the baseline as an argument or extracts it from the Git
   base. No paths into another checkout.

Proof: focused rr17 tests and gates, the new regressions, a mutation table (each guard removed → caught), the rr12
runtime, the three SFX sync programs, the registration audit and the sidecar guard. List the windowed commands the
director must re-run (production capture and gates at least). Proof captures stay gitignored. No full suites.
