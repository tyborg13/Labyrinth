# SFX pipeline

This unit is tooling only. The director shortlists by measurement, the owner
listens and approves, and the builder derives game-ready files from those picks.
It does not choose sounds or alter game audio, analytics or saves.

## Approved sources and licences

Read-only source root:
`/Users/borgerding/workspace/Labyrinth/output/sfx-sources-2026-10-12/`.
`CATALOGUE.md`, `INDEX.tsv` and the three source `LICENSE.txt` files are owner
records and are never modified by these tools.

| Source folder | Carried licence ID | Rule supplied with this task |
| --- | --- | --- |
| `sonniss_gdc` | `Sonniss GDC Bundle licence` | Game incorporation and internal team audition; no redistribution as sound effects, sample libraries or asset packs; no AI/ML training |
| `kenney` | `CC0-1.0` | CC0 election in the supplied source records |
| `opengameart` | `CC0-1.0` | CC0 election in the supplied source records, including multi-licensed submissions |

Mixkit is excluded. Paths containing `mixkit` or a directory beginning
`sfx-sources-excluded` are rejected before file access, including symlink
destinations. Source paths must stay inside one of the three approved folders.
Every indexed source needs its folder's `LICENSE.txt`. Every take and derivative
sidecar entry retains a licence ID and source hash. Build files are for game
incorporation, not distributing an SFX library. A publicly hosted static audition
page may contain CC0 candidates; Sonniss auditions must remain within the team.
The tools provide static files, never publish them or access the network.

The saved Sonniss record describes the current licence as a summary and asks the
owner to retain a dated copy of the full terms. This pipeline preserves that
record; it does not replace it with a new legal interpretation.

## Index, slice and analyse

Use the existing audio venv; numpy, scipy, soundfile and pyloudnorm are already
installed. FFmpeg and ffprobe come from PATH. No package installation is needed.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/index.py --sources /Users/borgerding/workspace/Labyrinth/output/sfx-sources-2026-10-12 --out /private/tmp/labyrinth_codex/sfx_lab/index.json --workers 4
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/slice.py --index /private/tmp/labyrinth_codex/sfx_lab/index.json --out /private/tmp/labyrinth_codex/sfx_lab/takes.jsonl --workers 4
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/features.py --index /private/tmp/labyrinth_codex/sfx_lab/index.json --takes /private/tmp/labyrinth_codex/sfx_lab/takes.jsonl --out /private/tmp/labyrinth_codex/sfx_lab/features.jsonl --workers 4
```

The owner can replace the temporary output paths with their desired `output/`
directory. Keep the three analysis outputs together so renderers can locate the
index beside `features.jsonl`. Index order and JSON serialization are stable;
outputs contain no clock timestamps. Every WAV, Ogg, FLAC and MP3 of at least
30 ms is indexed. `.DS_Store` and `__MACOSX` are ignored. Bit depth is zero for
compressed/unknown formats; PCM/floating formats retain their actual depth.

The nonoverlapping RMS envelope uses 10 ms frames, averaging channel energy
without cancelling opposite-phase stereo. Its maximum sets the relative gate:
`max(-50 dBFS, envelope peak - 45 dB)`. A take begins at the first frame above
the gate. A 120 ms run below the gate closes its active span. Preserve that
release and any remaining tail above -60 dBFS, with a four-second tail limit;
never extend into the next take. Active spans shorter than 40 ms are ignored,
including a partial final frame. A single qualifying span yields one take;
silence yields none. Take numbers start at one:
`<source sha256 first 12 characters>#<number>`.

`start_seconds` and `end_seconds` address the original recording. Identical
source files can have identical take IDs. Query keeps both provenance records;
renderers reject ambiguous IDs until the candidate supplies `source_path`.
Changing an audio file after indexing causes hash verification to fail.

Feature fields:

| Field | Definition |
| --- | --- |
| `duration`, `peak_dbfs` | Full take duration and maximum absolute sample level |
| `lufs`, `loudness_method` | pyloudnorm integrated LUFS for at least 0.4 s; shorter takes use RMS dBFS and explicitly identify `short_rms_dbfs` |
| `attack_seconds` | First -20 dB crossing relative to envelope peak, to envelope peak |
| `decay_seconds` | Envelope peak to first -30 dB crossing; null if the recording never reaches it |
| `centroid_hz` | Mean energy-weighted centroid over non-silent Hann-window spectra |
| `low_band_ratio`, `high_band_ratio` | Summed spectral power below 200 Hz / above 5 kHz divided by full-band power |
| `tonality` | Reciprocal of mean spectral flatness, with a numerical denominator floor; a larger value is more tonal |
| `envelope` | 64 linearly sampled, peak-normalized RMS envelope points |

Spectral analysis uses at most 4096 samples per frame, 50% overlap and batches
of 128 frames. Silent spectral frames do not affect centroid/flatness means.
Silence produces null loudness/peak, zero band ratios and zero envelope, never
nonstandard JSON Infinity/NaN. Takes from the same file share one decode per
feature worker. Analysis uses at most four workers and one BLAS/OpenMP thread
per worker. FFmpeg calls use two threads and at most four concurrent processes
across sound-lab invocations, with cooperative file locks.

## Query a measured shortlist

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/index.py query --features /private/tmp/labyrinth_codex/sfx_lab/features.jsonl --path impact --duration 0.04 1.5 --centroid 200 3000 --low-band 0.1 1 --attack 0 0.1 --decay 0 1 --lufs -35 -10 --sort low_band_ratio --descending --limit 30
```

All range bounds are inclusive; filters are ANDed. `--path` is a case-insensitive
substring; `--regex` is an optional case-sensitive Python regex. `--sort` accepts
any scalar feature, `source_path` or `take_id`; null values sort last. The compact
table is TSV. The director must distinguish short RMS dBFS from integrated LUFS
using the take's `loudness_method` when making a final shortlist.

## Audition and approve

The owner's picks file uses cue IDs, notes and candidate labels without adding
tool-selected names. Trims are seconds **relative to the take**, before pitch.
`source_path` is optional except when resolving a duplicated take ID.

```json
{
  "<cue_id>": {
    "note": "<owner note>",
    "candidates": [
      {"take": "<take_id>", "label": "A", "gain_db": 0}
    ]
  }
}
```

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/audition.py --picks /private/tmp/labyrinth_codex/sfx_lab/picks.json --features /private/tmp/labyrinth_codex/sfx_lab/features.jsonl --out /private/tmp/labyrinth_codex/sfx_lab/audition
```

Each candidate becomes `audio/<cue>/<label>.mp3`: 48 kHz, mono or stereo matching
the source's front pair, MP3 q4, -20 integrated LUFS (short sounds: -14 dBFS peak),
3 ms linear fade-in and 30 ms equal-power quarter-sine fade-out.
Processing normalizes after trim/pitch/fade, applies the approved gain
offset, and enforces short peak targets. The actual encoded output is remeasured
and corrected for codec drift. Silent or clipping renders fail explicitly.

`index.html` is titled **Escape the Umbra — Sound Audition**. It contains inline
CSS/JavaScript and one section per cue with its note. Each candidate is a row
containing its label/radio, **Play** button, a small SVG sparkline drawn from the
64-point envelope, key features, muted small source path and licence. The page
uses a warm dark ink background `#0c0a08`, text `#efe3c8`, secondary `#b5a58a`,
gold accent `#c9a25e`, ember pick highlight `#e8893a`, 16 px body text and system
serif headings. It uses installed system fonts and no downloaded assets.
It loads no remote resources or JSON via fetch, so file URLs and static hosting
both work. The approved keyboard mappings are:

| Shortcut | Action |
| --- | --- |
| Space | Play/stop the focused candidate; stop resets its play position |
| 1–4 | Play candidate A–D in the focused cue |
| J / K | Focus the next / previous cue, without automatic playback |
| P | Toggle the pick radio of the last played candidate |

Candidate rows, their play buttons and radios all establish candidate focus.
Cue navigation stops at the first/last cue; a missing A–D candidate does nothing.
Text entry and modified/repeated keystrokes retain their normal behavior. Native
Space on Copy picks is preserved. Playing a candidate stops other audio.
The **Copy picks** button exports only selected cues, preserving each selected
candidate's trim, pitch, gain and optional source path in the original picks
format. Secure hosts use the Clipboard API; local/insecure pages use the copy
fallback and leave the JSON selected for manual copying if permission is denied.
There is no default radio selection or automatic playback.

`audition.json` records provenance, actual levels, output hashes, processing
parameters and an empty `design_pending` list. Browser listening, keyboard focus,
clipboard permissions and page appearance need owner inspection; a headless
HTML/JS proof does not claim that inspection.

Approval is a separate owner-authored document: replace candidates with selected
`variants`, supply the brief's category and loop decision, and preserve approved
processing values. Copy picks deliberately does not invent a category or loop
decision. No approval or picks document is rewritten by the tools.

```json
{
  "<cue_id>": {
    "category": "impact",
    "variants": [{"take": "<take_id>", "gain_db": 0, "pitch": 1.0,
                  "lowpass_hz": null, "fade_out_ms": 30}],
    "loop": false
  }
}
```

## Build approved variants

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tools/sfx_lab/build.py --approved /private/tmp/labyrinth_codex/sfx_lab/approved.json --features /private/tmp/labyrinth_codex/sfx_lab/features.jsonl --out-dir assets/audio/sfx/cues --manifest spec/assets/sfx/manifest.json
```

The command writes `<cue>/<cue>_<nn>.ogg`, with numbering starting at `01`,
Vorbis q6 and 48 kHz. The current PATH FFmpeg has no `libvorbis` encoder, so the
already-installed soundfile/libsndfile Vorbis encoder supplies q6 through its
quality interface (0.6), and FFmpeg remuxes it with bitexact flags and a fixed Ogg
serial offset of zero. No extra dependency or encoder installation is needed.
Determinism applies to the same installed toolchain, not arbitrary future codec
versions. Unit tests compare bytes across different output directories.

| Category | Integrated target | Short target (< 0.4 s) |
| --- | --- | --- |
| impact | -16 LUFS | -3 dBFS |
| body | -18 LUFS | -4 dBFS |
| vocal | -20 LUFS | -6 dBFS |
| ui | -26 LUFS | -12 dBFS |
| card | -24 LUFS | -10 dBFS |
| ambience | -30 LUFS | Always integrated LUFS; short ambience is rejected |
| spell | -18 LUFS | -4 dBFS |
| movement | -28 LUFS | -14 dBFS |
| status | -22 LUFS | -8 dBFS |
| pickup | -22 LUFS | -8 dBFS |
| stinger | -16 LUFS | -3 dBFS |

Source mono remains mono. For more than two channels, audition and build use
channel 0 as L and channel 1 as R, ignoring all other channels. Ambience/stingers
keep this stereo pair regardless of its width. For other categories, compute
`mid = (L + R)/2`, `side = (L - R)/2`: retain stereo when
`RMS(side)/RMS(mid) >= 0.25`, otherwise average L/R to mono. Exact dual mono
therefore becomes mono for ordinary cues. Pure anti-phase has nonzero side and
zero mid, so stays stereo; its unbounded ratio is represented as null in JSON
alongside the finite mid/side RMS measurements.

Processing order is take/trim, optional pitch resampling, channel policy,
optional causal second-order Butterworth lowpass, 3 ms linear fade-in, loop
crossfade or equal-power quarter-sine fade-out, normalization and gain, then
encoding/verification. Lowpass uses scipy `butter(..., output="sos")` followed
by `sosfilt` before normalization. Pitch is tape-style resampling: pitch and
duration change together. Every rendered take receives the 3 ms fade-in.

Any category with `loop: true` blends the final and initial 0.5 s, removes one overlap, and wraps
at the file boundary. The manifest records full-file loop start/end. Loop audio
does not receive a fade into silence. A loop requires more than one second of
input. A lowpass on a loop uses periodic warmup before crossfading. The 3 ms
fade-in is applied before the loop crossfade, preserving the seamless output
boundary. Crossfade weights are `cos(theta)` for the tail and `sin(theta)` for
the head, with theta running from 0 to pi/2. All categories use this treatment.

For sounds at least 0.4 s, normalization aims at the category's integrated
target, then applies approved `gain_db`; the impact/UI peak caps take precedence.
Short sounds use the category peak target and retain RMS measurements in the
manifest. No taste-selected compressor or limiter is introduced. If a mandated
cap prevents the loudness target, the manifest flags the cap. Otherwise measured
encoded loudness must be within 0.5 LU of the processed target; encoded peak
caps are checked within 0.05 dB. Short Vorbis quantizer changes can cause direct
gain corrections to oscillate; verification brackets gain with up to 16
encode/measure attempts and retains the closest valid encoding. Clipping without a specified cap fails and
requires an owner-approved lower gain.

The manifest lists every output's relative path, cue/category/variant, source
path and source ID, original take range, licence ID, source and output SHA-256,
loop points, effective trim/pitch/gain/filter/fade parameters, channel decision,
normalization method/targets, actual output levels and encoder settings. It is
written atomically after every variant succeeds; individual audio files also use
atomic replacement. A failed build may leave already-completed audio variants,
but never publishes a partial new manifest.

## Approved design constants

The design owner's sfx-00 feedback 1 resolved all rendering/page decisions.
They are stored in plain named constants in `common.py`, `build.py` and
`audition.py`; no additional configuration or unresolved design field is needed.
`SHORT_PEAK_TARGETS`, `STEREO_SIDE_RATIO`, `MULTICHANNEL_DOWNMIX`, `LOWPASS_ORDER`,
`LOWPASS_FILTER`, `FADE_CURVE`, `FADE_IN_MS`, `LOOP_CROSSFADE_CURVE`, `PITCH_MODE`,
`NON_AMBIENCE_LOOP`, `AUDITION_CSS`, `KEYBOARD_SHORTCUTS`, `PAGE_TITLE` and
`PLAY_BUTTON_TEXT` record those decisions. The optional legacy `--design-config`
argument remains read-only and checks supplied values against the approved
constants; a conflicting supplied value is rejected rather than silently
overriding the owner's design. Candidate trims/gains/pitch/filter cutoffs and
loop flags remain owner-provided per pick/approval file.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python tests/test_sfx_lab.py --proof-out /private/tmp/labyrinth_codex/sfx_lab/proof -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && /Users/borgerding/.cache/umbra-sfx/venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && python3 tools/godot_task_runner.py --task-id sfx-00 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The focused tests cover slicing boundaries/tails, sine/noise feature sanity,
all source formats, byte determinism across workers and render destinations,
two-cue HTML/audio/provenance, offline/secure-host copy and keyboard handlers,
all 11 category loudness targets, short peak targets, filters/trims/pitch,
loop seams/channel policy, source-hash/identity ambiguity and excluded paths.
No audio fixtures are committed.

Windowed owner inspection command (not run in the implementation sandbox):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/sfx-00 && open /private/tmp/labyrinth_codex/sfx_lab/proof/audition/index.html
```

Inspect at 1920×1080 and 100% browser scale. Play both candidates, exercise the
Space, 1–4, J/K and P; choose one per cue, and verify
Copy picks on a file URL and the owner's authorized static host. No renderer
capture has been claimed. A Godot visual probe/inspection fixture is not
applicable because this unit has no game code, scene or player-facing surface.
The owner performs final listening and design approval; the retained page is a
synthetic implementation fixture using approved page design, not a sound shortlist.

Implementation defaults that no player sees: subprocess/CLI-test timeout 180 s,
FFmpeg slot polling 25 ms, hashing blocks 1 MiB, spectrum frames 4096 samples,
batches 128 frames, numerical floor 1e-20, resampling rational denominator bound
100000, at most 16 encode/measure attempts, 0.05 dB codec correction tolerance, and
the named synthetic-test values in `tests/test_sfx_lab.py`. The acceptance
loudness tolerance is 0.5 LU as required by the brief.
