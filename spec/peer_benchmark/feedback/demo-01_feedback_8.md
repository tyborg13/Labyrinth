# demo-01 — round 8 (director's run on the real renderer: 19/21 encoded)

Good: real renderer (Forward Mobile/Metal), MJPEG writer ~13–30 s per clip (was ~2 min), lightning trap cue measured
0.35 s, pixel_fx reel delivered to the owner. My one-line fix is in demo_clip.gd:29 — `OS.get_cmdline_args()` never
contains engine flags such as `--write-movie`; I switched it to `Engine.get_write_movie_path()`. Keep it and add a test.
I also moved captions bottom-left in clips.json (`position_px [48, 930]`, `subtitle_top_px 974`): the top-left caption
collided with the room header. Both director copies are already updated.

Two comparisons fail:
1. enemy_bite: native leads by one frame at H146 (offset −1). Allow per-item offsets in [−2, +2].
2. weaver_thornwall: offset jumps to +47 at H153 (N200) and +41 at H188. Find the exact event/row and its cause (read
   both event logs and the code path). If it is a presentation wait that only exists with a real renderer (e.g. an
   animation-finished or tooltip signal the headless run completes instantly), record a per-clip, per-event exemption
   in the comparison report with the identified cause and allow it; payloads/order/states must still match exactly.
   If it is a real behavioural difference, report it and do not exempt it.
3. Input-hash refusal: a caption-only change in clips.json made encode refuse the takes. Hash only the clip fields that
   affect recording (setup, actions, speeds, volumes, defaults) for take validity; captions/caption_style only affect
   encoding.
Focused tests only; do not commit; same windowed list.
