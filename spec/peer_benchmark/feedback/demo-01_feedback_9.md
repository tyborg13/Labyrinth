# demo-01 — round 9 (Codex peer review of b2d535c2c: CHANGES REQUESTED)

Fix all five findings exactly as the reviewer proposes (full text: /private/tmp/labyrinth_codex/review/demo-01-b2d535c2c.md):
1. **Blocking — probes capture the wrong viewport.** [demo_clip.gd:124](/private/tmp/labyrinth_codex/review/demo-01-b2d535c2c/tools/demo_clips/demo_clip.gd:124) captures the root window; all 21 owner screenshots are **3024×1701**. Stage probes inside a fixed **1920×1080 SubViewport**, route hover input there, and capture its texture. Rerun all 21 real-renderer probes.

2. **Medium — rerunning encode destroys existing deliveries.** [encode.py:155](/private/tmp/labyrinth_codex/review/demo-01-b2d535c2c/tools/demo_clips/encode.py:155) deletes MP4s before validating their sources; reels do likewise at line 173. After successful AVI cleanup, another encode removes the deliveries and then fails. Reproduced with the synthetic lifecycle. Validate sources first and replace outputs atomically after successful encoding and probing.

3. **Medium — repeated cues produce false sync measurements.** [sync.py:101](/private/tmp/labyrinth_codex/review/demo-01-b2d535c2c/tools/demo_clips/sync.py:101) chooses a correlation maximum without detecting competing occurrences. Two correctly aligned identical hits at 0.500/0.600 seconds both receive the 0.615-second peak, falsely flagging the first as **+115 ms**. Detect ambiguous matches and report them as unmeasured, or establish distinct event-to-occurrence assignments.

4. **Medium — exemption guards lack portable tests.** [test_demo_recording.py:153](/private/tmp/labyrinth_codex/review/demo-01-b2d535c2c/tests/test_demo_recording.py:153) skips all three Thornwall tests without ignored owner artifacts. Removing reference fingerprints, source fingerprints, or exact frame matching survives clean-checkout tests. Add committed or generated fixtures covering each rejection guard.

5. **Medium — the clock test misses broken time scaling.** [demo_clip_clock_test.gd:13](/private/tmp/labyrinth_codex/review/demo-01-b2d535c2c/tests/demo_clip_clock_test.gd:13) still passes after removing `Engine.time_scale` from presentation-clock advancement. Assert clock values and dispatch frames across scales 0, 1, and 2.


Also add a test that ffmpeg wrapper calls keep -threads 2. Focused tests only; no full suites (tools only). Do not commit. List the windowed probe command; the recorded takes need no re-recording if the probe stages its own scenes.
