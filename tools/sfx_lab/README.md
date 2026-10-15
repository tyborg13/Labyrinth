# Sound lab

Local-only tools for the director's measured shortlist, the owner's audition,
and rendering approved variants. No source downloads, cue selection, game wiring
or packages are installed. Run from the repository root using the existing
sound-lab Python environment (`SFX_PYTHON` in the examples below).

The [pipeline specification](../../spec/sfx_pipeline.md) contains exact commands,
formats, measurement definitions, approved rendering decisions and licence restrictions.

| Entry point | Input | Output |
| --- | --- | --- |
| `design.py --recipes … --features … --out-root …` | Director's layered recipes and measured takes | 24-bit designed WAVs and per-file licence sidecars |
| `index.py --sources … --out …` | Approved library tree | `index.json` |
| `slice.py --index … --out …` | File index | `takes.jsonl` |
| `features.py --index … --takes … --out …` | Index and take boundaries | `features.jsonl` |
| `index.py query --features …` | Measured takes | Sorted TSV shortlist |
| `audition.py --picks … --out … --features …` | Owner candidates | Relative MP3s, `index.html`, `audition.json` |
| `sync.py` | Parent manifest plus per-path sync provenance | Verified lossless head trims; unchanged bytes on a repeated run |
| `build.py --approved … --out-dir … --manifest … --features …` | Owner approval | Relative Ogg variants and manifest |

Each module can also be run as `python -m tools.sfx_lab.<module>`. The package
uses Python namespace packages; no installation step is needed. Index, takes and
features should share a directory; audition/build find `index.json` beside the
features. `--sources` on audition/build can relocate a library with identical
source hashes. Analysis accepts `--workers 1` through `--workers 4`.

Focused behavioral proof, with temporary synthesized fixtures and retained
owner inspection artifacts:

```bash
cd "$TASK_WORKTREE" && "$SFX_PYTHON" tests/test_sfx_lab.py --proof-out output/sfx/lab-proof -v
```

The two-cue proof page is `proof/audition/index.html`. Its tones and cue names
are debug-only fixtures; its rendering, page styling and shortcuts use the
owner-approved production decisions. The first cue contains candidates A–D.
The inline JavaScript handlers are additionally exercised with the existing
`node` executable when available; no JavaScript package is required.

Space plays/stops the focused candidate; 1–4 play A–D in its cue; J/K move to
the next/previous cue; P toggles the pick for the last played candidate. The
page displays a 64-point SVG envelope per row and exports selected picks offline.
No design configuration is required. The optional legacy `--design-config`
flag reads a JSON file and checks supplied settings against approved constants;
it does not substitute another design or rewrite that file.

Determinism is checked with the same installed Python, libsndfile, numerical
libraries and FFmpeg. Updating an encoder may change encoded hashes; rerun the
determinism proof after a toolchain update. All sound-lab FFmpeg calls use two
threads and four cooperative machine-wide lock slots. Keep unrelated encoders
within the machine's same four-process limit.

Layered recipes carry every director-selected processing value; the renderer
does not choose takes or write production recipes. See [Layered designs](../../spec/sfx_pipeline.md#layered-designs)
for the format and design → index → slice → features → audition commands. Repeat
`index.py --sources` for the read-only library and the design output root (the
parent of `designed/`); index order follows argument order and then the existing
file sort. Per-file sidecars determine the designed source's licence. Existing
audition/build `--sources` can relocate either root, with untouched roots kept
from the index, or use a combined tree containing both approved folder sets.

Sync rebuilds read constraints from `assets/audio/sfx/sfx-04-provenance.json` and timing rules from `data/sfx_cues.json`. They verify the parent manifest hash, source hashes, toolchain and output hashes. The default catalogue is `.godot/sfx_lab/features.jsonl`; `--features` and `--sources` can relocate the approved lossless library. Ogg output preserves libsndfile's end-of-stream granules while normalizing the stream serial and repairing page checksums. The rebuild never remuxes short streams through packet timestamps.

```sh
cd "$TASK_WORKTREE" && "$SFX_PYTHON" tools/sfx_lab/sync.py
cd "$TASK_WORKTREE" && "$SFX_PYTHON" tools/sfx_sync_audit.py --report output/sfx/sync_audit.json --check
```

The tracked baseline is compact. Full measurements, scene traces and actual playback PCM stay in `output/sfx/`. Refresh the baseline explicitly with `--refresh-baseline` after reviewing the measured changes. Cap-limited loudness exceptions remain visible in the report.
