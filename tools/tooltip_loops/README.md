# tip-02 round 1 — compressed loops and per-recording speed

Implementation and headless checks are complete. Changes remain uncommitted.
**Fresh native re-recording and native performance/capture proof remain pending.**
The checked-in working assets are compressed migrations of the approved tip-01
recordings, not new recordings. Their provenance says `requires_native_rerecord:
true` and retains the actual normal recording speed. In particular, the current
Grub asset still contains the original 210-frame / 7-second sequence. The native
capture explicitly rejects migrated footage as tip-02 acceptance proof.

## Requirement 1: speed and duration

`data/tooltip_loops.json` selects fast for Grub and normal for Burst/Chain.
Missing speed defaults to normal. The playback helper saves the recording
settings into the task runner's isolated HOME before production `_ready` reads
its `_settings`; CombatPacing therefore uses the exact player's combat-speed
path. Merely applying global settings does not set the scene's `_settings`.

The recorder caps **fast at 165 frames / 5.5 seconds** and **normal at 126 frames /
4.2 seconds**, regardless of loop identity. It rejects overruns without replacing
shipping assets or skipping beats. Headless rehearsal observed:

- Burst: 90 frames, 3.000 seconds, normal.
- Grub: 141 frames, 4.700 seconds, fast. Earlier rehearsal observed 140 frames;
  headless scheduling varies by a frame. Native MovieWriter timing is pending.
- Chain: 90 frames, 3.000 seconds, normal.

Hold 0.6 s, cross-fade 0.25 s, fade-in 0.12 s, baked vignette, crop, window sizes,
contexts, aliases, reduced motion, Seer exclusion, rules, analytics and saves are
preserved. Neither the production run scene nor tooltip presentation code grew.

## Requirement 2: compression and integration

TLW2 stores a 20-byte little-endian header (magic, width, height, fps, count), then
one 12-byte `(absolute buffer offset, byte length, frame row)` index per timeline
frame. Each WebP buffer stores up to 16 consecutive 282×168 images as vertical
rows. This storage layout lets libwebp reuse repeated board pixels across frames;
all frames and timestamps remain intact. Byte-identical chunks share a buffer.

`compress.py` uses libwebp `lossless=1`, `near_lossless=60`, then 40, evaluates
**both** levels, and retains the first passing candidate. A plain lossless level
100 fallback is evaluated only if neither near-lossless candidate passes.
Measurements compare every decoded RGB channel with raw baked renderer frames.
Near-lossless requires ≤1,500,000 bytes, each channel maximum ≤8 and each channel
mean ≤0.5; fallback requires ≤3,000,000 bytes and zero error.

The offline encoder uses the already installed Pillow libwebp through its public
encoder ABI; no pip install or game dependency was added. `--check-only` validates
encoder availability/ABI before the recorder parse check. `--libwebp` on the
compressor can select an existing library on a different recording machine.

Final migration results (RGB maxima and means, bytes include header/index):

| Loop | Level | Bytes | Max RGB | Mean RGB | Pass |
| --- | ---: | ---: | --- | --- | --- |
| Burst | 60 | 573,078 | 2, 2, 2 | .434109, .440820, .429601 | yes, selected |
| Burst | 40 | 439,814 | 4, 4, 4 | .784584, .790114, .765543 | no, mean |
| Grub | 60 | 1,268,350 | 2, 2, 2 | .457284, .459012, .457539 | yes, selected |
| Grub | 40 | 911,356 | 4, 4, 4 | .839301, .844847, .819452 | no, mean |
| Chain | 60 | 459,822 | 2, 2, 2 | .435606, .435259, .431417 | yes, selected |
| Chain | 40 | 359,682 | 4, 4, 4 | .785865, .785038, .784027 | no, mean |

All three select level 60; no fallback is needed. Total payload is 2,301,250 bytes
versus 55,429,980 bytes raw. Original renderer/source provenance is retained in
`.tlw.json`, with compression configuration, original raw SHA256, encoder version,
tool hashes, both candidates' results and the selected asset SHA256 added.

The raw `.tlp` files and old sidecars have been removed. The registry uses `.tlw`;
both export presets include `.tlw` and `.tlw.json`. The loader API is unchanged.
It reads/decompresses on a worker, copies only the requested four-frame read-ahead
and uploads at most **one texture per tick**. The eight-texture cache still expires
10 seconds after close. The conservative bound including an entire decoded
16-frame chunk, compressed input, pending frames, texture copies, index and
transient upload is **11,005,632 bytes for one active tooltip**. Native frame cost
and ≥20 fps are not claimed from headless checks.

The normal native `record.py` command records all three into task-local temp raw
files, then compresses and compares them. It replaces shipping assets only after
all loops pass and their recorded speeds, durations and raw SHA256 match. Failed
recording/compression leaves shipping assets intact. The separate one-time
`--migrate-existing` mode was used here; it explicitly marks old footage as needing
native recording and does not retime or relabel it as fast.

## Files changed

- `data/tooltip_loops.json`: speed fields and compressed paths.
- `scripts/tooltip_loop_format.gd`: bounded index/chunk decoder.
- `scripts/tooltip_loop_cache.gd`: worker decoding, incremental upload, memory bound.
- `tools/tooltip_loops/webp_encode.py`, `compress.py`: encoder, error/size gates,
  reports, provenance, safe asset/registry/export replacement and raw removal.
- `tools/tooltip_loops/playback.gd`, `record.gd`, `record.py`: speed, ceilings,
  isolated raw capture and automatic compression after successful recording.
- `tools/tooltip_loops/capture.gd`: compressed fixture/lifecycle/all-frame decode
  checks, speed ceilings, native fresh-footage gate and worker-decode diagnostics.
- `export_presets.cfg`, three `.tlw` files and their `.json` provenance; this README.

## Focused proof

Observed after the corresponding final changes:

- Headless tooltip semantics: `TIP01 TOOLTIP SEMANTICS: PASS (0 failures)`.
  Includes actual asset-frame decoding, source routing, negative Seer, capped
  popup sizing, reduced motion and ten-second real-time stream expiry.
- Headless recorder semantics: `TIP01 SEMANTICS RESULT: PASS (0 failures)`.
- Headless rehearsal: `TIP02 PLAYBACK burst_ember_tick: PASS (90 frames at 30 fps; 3.000 s; speed=normal)`;
  `TIP02 PLAYBACK marked_burrow_grub: PASS (141 frames at 30 fps; 4.700 s; speed=fast)`;
  `TIP02 PLAYBACK chain_card: PASS (90 frames at 30 fps; 3.000 s; speed=normal)`;
  `TIP01 REHEARSAL RESULT: PASS (0 failures)`.
- Recorder Python `--check-only` and capture GDScript `--check-only`: exit 0.
- Compression migration: `TIP02 COMPRESSION: PASS (3 loops)`.
- Actual chunk decode crosscheck through the Godot runner:
  `TIP02 GODOT CHUNK CROSSCHECK: PASS (390 frames; exact Pillow/Godot RGB agreement)`.
- Isolated temporary Python integration fixture:
  `TIP02 COMPRESS INTEGRATION FIXTURE: PASS (chunk boundary; both levels; first passing selection; registry/export switch; raw removal; rejects stale speed without replacing assets)`.
- UI lint: `Ran 25 tests in 3.898s` / `OK`.
- Approved-content manifest: `Ran 1 test in 9.083s` / `OK`.
- `git diff --check`: exit 0.

The headless Godot checks also log the sandbox's existing
`get_system_ca_certificates (platform/macos/os_macos.mm:1014)` message.
No permanent test modules, full suites, windowed runs, Git writes, reviews or
publication were performed. The first Python bytecode check encountered the
sandbox's denied macOS cache directory; a task-local `PYTHONPYCACHEPREFIX` worked.

Full precision compression report:
`/private/tmp/labyrinth_codex/tip-02/migration-compression-report.json` and each
asset's provenance. Decoder hash fixture/script:
`/private/tmp/labyrinth_codex/tip-02/codec-proof/`.

## Proof for the design owner

Run recording first; it automatically compresses all three fresh recordings and
updates their provenance. Then run capture in a fresh process, at 1920×1080 and
100% UI scale. The capture retains the ≤4 ms added-frame, ≥20 fps, memory and
expiry gates and measures Burst first without decoder warm-up.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-02 && python3 tools/tooltip_loops/record.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-02 && python3 tools/visual_probe_runner.py tools/tooltip_loops/capture.gd --task-id tip-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tools/tooltip_loops/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/tip-02/capture-manifest.json --overwrite-result-manifest
```

Expected recording PNGs, raw comparison inputs and compression report:
`/private/tmp/labyrinth_codex/tip-02/record/`.
Expected tooltip PNGs and measurements:
`/private/tmp/labyrinth_codex/tip-02/capture/`.
No new native captures exist yet. No inspection fixture command was requested.

## TODO_DESIGN placeholders, chosen defaults and open issues

No TODO_DESIGN placeholders or new perceivable values. Internal choices are named
constants: `CHUNK_FRAMES = 16`, offline encoder `ENCODER_METHOD = 6` and
`ENCODER_QUALITY = 100.0` (compression effort, not a lossy-format quality control).
The new integration fixture uses `FIXTURE_FRAMES = 17` to cross a chunk boundary
and `FIXTURE_CHANNEL = 17`; it writes only a unique temporary directory. Existing
proof sampling/timeouts are preserved, with the output namespace changed to tip-02.

Outstanding: native fresh recording of all three (especially the fast Grub),
visual comparison at 100% UI scale, and native cold-open/frame-rate proof. The
current migrated Grub duration is deliberately identified as old normal footage;
it does not satisfy the new recording-speed requirement until native recording.
