# qa-07 feedback 2 — delta review CHANGES on 09f60c6d7

Review: `spec/peer_benchmark/feedback/qa-07_review_09f60c6d7.md`.

1. **Presentation program flake (Medium; the important one).** Under load, the extracted presentation program hit
   its 180 s per-child cap: 349.758 s run, FAIL at 180.232 s. Agent units and reviews often run concurrently on this
   machine, so the suite has to pass under load.
   - Split that domain into two or more program children of roughly equal time, with assertions preserved and
     counted, so each finishes well under 180 s with nothing else running. Target ≤ 110 s each.
   - Keep the 180 s per-child cap and the 900 s total cap.
   - Then show three consecutive green full runs while another Godot suite runs concurrently. Use the full Python
     suite or a second Godot program as the load, and report the wall times.
2. **Windows orphan when the root exits (Medium).** Own the Windows process tree from launch with a kill-on-close Job
   Object, using ctypes, no new dependency. Keep `taskkill /T /F` as the fallback. Test both exit timings in the
   simulation: root alive at cancel, and root already exited.
3. **Namespace initialisation guard (Low).** Assert the requested namespace before the fixture's first persistence
   operation, so removing bootstrap initialisation fails.
4. **`/F` guard (Low).** Assert the complete owned-PID `/T /F` command, and that an unrelated process survives.
