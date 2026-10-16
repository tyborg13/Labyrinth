# demo-01 — round 7 (wrong renderer + slow capture; owner was watching)

Director stopped the run after profiling the recording process (macOS `sample`, 5 s, main thread):
- 74% in `MovieWriterPNGWAV::write_frame` → `png_write_row` → `deflate`, 22% in `GL_ReadPixels` (ANGLE→Metal readback),
  ~2% game. ≈0.47 s per frame; a 4 s clip took ~2 min.
- **Blocking defect:** `pipeline.py:53` forces `--rendering-method gl_compatibility --rendering-driver opengl3_angle`.
  The game runs `renderer/rendering_method="mobile"` (Forward Mobile on Metal). Clips recorded on the compatibility
  renderer may not show what the player sees — unacceptable for clips meant to judge the pixel FX.

Changes:
1. Record with the project's own renderer: no rendering-method/driver overrides. Parse the Godot log and fail the clip
   unless it reports Forward Mobile on Metal (same as the visual probes: "Metal ... - Forward Mobile").
2. Record Movie Maker to AVI (MJPEG + PCM, `--write-movie <clip>/movie.avi`) with `editor/movie_writer/mjpeg_quality`
   = 1.0 (set via the clip's override settings so it applies before the writer starts; verify it took effect). No PNG
   sequences. The AVI is the per-clip intermediate: run sync/duration analysis from its PCM track + the event log,
   build the clip/reel MP4s from it, then delete the AVI after the reels are encoded and probed.
3. Keep: disk guard, continue-past-failures, comparison rules, captions, codecs, fades, sync table policy.
4. Print per-clip wall time and seconds-per-frame in the record summary.
Focused demo tests only; do not commit; same windowed list (validate, record, compare, encode, probe).
