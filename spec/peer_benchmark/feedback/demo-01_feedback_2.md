# demo-01 — round 2 (recording filled the disk)

`pipeline.py record` wrote full-resolution PNG frames for every clip and both takes before encoding: 23 GB of raw frames
filled the Mac's disk to 0 bytes and the run died (exit 120). The raw folder was deleted with owner approval.
Validation (21/21 PASS, headless determinism 21/21) is unaffected.

Change the recording flow:
1. **Stream per clip:** record one clip → immediately convert its frames + WAV to a lossless intermediate
   (`libx264rgb -qp 0`, or FFV1, plus the WAV) → run that clip's sync/duration analysis → delete the PNG frames →
   next clip. Peak raw usage must stay at one clip's frames. Keep logs/WAV/intermediates; never keep frame sequences.
2. **One native take per clip.** Determinism is proven by the headless double run; drop the second native take and
   compare event logs between the native take and the headless validation run instead.
3. **Disk guard:** before each clip, require ≥ 8 GB free on the output volume (`shutil.disk_usage`); otherwise stop with
   a clear error before writing anything. Print free space at start and end.
4. `encode.py` builds per-clip MP4s and the 3 reels from the intermediates (same codec, caption and fade settings).
5. Report the total size of `output/demo-clips-2026-10-15/` after a full run in the result.
Do not commit. Headless proof as before plus a test for the disk guard and frame deletion; repeat the windowed list.
