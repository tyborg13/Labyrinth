# demo-01 — round 3 (director's windowed run)

Disk handling works (output 0.29 GB after the first clip, frames deleted). Two failures:
1. **record** stopped after fire_volley: `DETERMINISM FAIL` native vs headless. The only differences are frame indices:
   every event from the first cue onward is exactly +1 frame in the native take (cue 110 vs 109, card_resolved 176 vs
   175, end_frame 260 vs 259); kinds, order, payloads and per-frame actor states are identical. A windowed renderer may
   start one frame later than headless — that is not nondeterminism. Compare native vs headless on the event sequence
   and per-frame states with frame indices normalised by a single constant offset (|offset| ≤ 2 frames, same offset for
   every event in the clip); report the offset per clip. Any other difference still fails. Sync is measured from the
   native take itself, so it is unaffected.
2. **probe** aborted: `Invalid renderer/driver combination 'mobile' and 'opengl3_angle'`. Use the same renderer flags
   as the project's other 1920x1080 visual probes (e.g. `tools/visual_probe_runner.py` defaults / metal on this Mac);
   never hard-code a driver the renderer rejects.
Run only the focused demo tests plus `pipeline.py validate` (no full suites this round — nothing outside
tools/demo_clips changed). Do not commit. Repeat the windowed list (record, compare, encode, probe).
