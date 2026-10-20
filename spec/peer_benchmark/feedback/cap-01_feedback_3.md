# cap-01 feedback 3 (director; windowed run of 817b48bf7)

**Results.** The director accepts the encoder choice: lossless WebP.

| | Before | After (WebP, cropped) |
|---|---|---|
| Seer production | ~30 min, ~4 GB | 256 s, 0.58 GB |
| Mortar production | ~30 min, ~4 GB | 552 s, 1.33 GB (two view runs) |

Of 20 equivalence checks, 16 pass:
- native and production gate verdicts and errors are identical;
- reels match exact decoded frames;
- every matched production frame's pixel hash is identical.

The 4 failures are the `idle` clip's unmatched production frames (5–7 per side), against the 2-frame limit.

Two tool rules need fixing. The captures stay as they are; no re-capture.

1. **Looping stepped clips (`idle`) compare by pose set, not by phase.**
   - The stepped idle holds about 10 snapped poses. Real-time capture samples the loop at different moments in each
     run, so phase matching leaves unmatched frames even when every pixel matches.
   - For clips the case data marks as looping (or `idle` if there's no such flag), require identical sets of distinct
     pixel hashes before and after, per view.
   - Non-looping clips keep the phase rule and its 2-frame limit.
2. **The speed and size target is reported, not fatal.**
   - Record per-run and per-rig seconds and GB in `capture_performance.json`, and print them.
   - `after` exits 0 when the captures and manifests are valid.
   - The target, a few minutes and under 1 GB per production run, stays as a printed check for the director.
3. Re-run `compare` on `/tmp/cap01-proof/before` and `/tmp/cap01-proof/after-r2` yourself if your sandbox can read
   them. If it can't, give the exact command.
   - Focused tests for the looping-clip rule: a pose set that differs must fail; reordered or resampled identical poses
     must pass.
