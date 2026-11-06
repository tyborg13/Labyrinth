# qa-64 release hunt

Base/HEAD `7e6e4e23b`, branch `codex/qa-64` (before qa-63). No product source or asset changed. All changes remain uncommitted. Tools/raw evidence: `/private/tmp/labyrinth_codex/qa-64/`; commands and diagnostic defaults: [README](README.md).

| Requirement | Result |
|---|---|
| 1. Both campaigns, >=15 runs, censuses, final-dragon win | 17 runs ended; 15 with corrected observer. Original default/no-embrace 45-minute/two-process windows drained. Default seed 5 won Noctyrax in section 5 at decision 2989. Strict census overall: **FAIL**, 6/7 comparisons passed. |
| 2. Per-decision presentation and fresh comparisons, added event/rail/Health checks | 30636 decisions. Board/HUD/hand/map/forecast checks; independent plan engines; scratch cache rebuilds with original references restored; private fresh CardDisplay caches/engine. Event/preview texture identities, grants, Scavenger stock/view state, ordered visible rail and unit bars/forecasts checked. Real Continue, purchase/purge/Exhaust, scale/zoom changes, map reopen/travel and 126 authored event-choice hovers pass focused probes. GPU pixels remain for owner. |
| 3. Findings and reproductions | Below; every occurrence/context and last inputs remain in `runtime-triage.json`, campaign `findings.json`/`report.md` and original traces. No safe product fix of <=10 lines was established. |

| Campaign | Ended | Win | Embrace | Fight budget | Decisions |
|---|---:|---:|---:|---:|---:|
| default | 6 | 3 | 3 | 0 | 12392 |
| no-embrace | 5 | 4 | 0 | 1 | 13344 |
| default-extra | 6 | 0 | 5 | 1 | 4900 |

Findings:

- **OPEN dummy-texture diagnostic:** default seed 4, decision 556; travel Treasure `(5,6)` → Scavenger `(7,-6)`. Engine `texture_storage.h:84`; GDScript caller `scripts/combat_board_view.gd:8708`, via `scripts/board_prop_command_cache.gd:36`. Cached drawing caller dates to perf-09 (`e54215f0b`), before this merge range; actual texture-lifetime cause and introducing merge remain unknown. Pinned replay: `run_hunt_task.py --runs 1 --processes 1 --seed 4 --stop-after 557 --output-dir <fresh-dir> --script /private/tmp/labyrinth_codex/qa-64/texture_trace_replay.gd`. It reissued all 557 method-equivalent actions and matched checkpoint 556, with zero repetitions of the diagnostic. This is non-reproduction, not a fix.
- **OPEN dummy-texture RID at shutdown:** default seed 8, after final-dragon victory at decision 2886; one `DummyTexture` RID remained owned. Source emits this in [`core/templates/rid_owner.h`](https://github.com/godotengine/godot/blob/14d19694e/core/templates/rid_owner.h#L408-L415), its allocator destructor. No allocation stack or introducing merge is established. The same run logged null-texture initialization at decision 2311 after a treasure choice; causality is unproven. Reproduce the full default seed 8 via `run_hunt_cache_observed.gd`; preserve its complete trace and shutdown log. A bounded engine-only control (32 existing card textures, six batches/eight workers) produced neither diagnostic.
- **OPEN native appearance of glossary overflow:** first default seed 4, decision 1356, hover `RelicChoice_briar_vambrace`; also other relics. `scripts/card_focus_tooltip_stack.gd:325` warns during above-row layout. Warning code `db82e2cfb5` predates the listed merges and the class occurs in qa-56; these occurrences’ introducing cause is unestablished. Replay seed 4 through decision 1357 using `run_hunt_cache_observed.gd`; inspect the retained trace because seed-only UI replays can diverge. Dummy logical viewport is 1920×1920, so this does not establish overflow at native 1920×1080.
- **Fight exploration limit:** no-embrace seed 7 ended at decision 1884 in section-2 `t3_full_line`, with Warden and Grave Surgeon alive. `tools/run_hunt.gd:166-168` enforces 400 fight decisions. Turn 75, healing/guarding/movement/fatigue continued; the 50-unchanged-decision guard did not fire. Same seed/outcome was already recorded in qa-56. Replay `--no-embrace --seed 7` through 1884; full terminal state is in `fight-limit-no-embrace-7.json`. The inherited bot budget ended this active fight. Supplemental default seed 13 also stopped at decision 2232, section 3 room `(15,0)`, in `t3_full_line`, turn 75; Warden 26/27, Harrier 15/15, Acolyte 18/18 and Grave Surgeon 15/15 were still active. Reproduce default `--seed 13 --stop-after 2233`; `fight-limit-default-extra-13.json` retains its exact terminal state/last 20 inputs. No gameplay softlock or introducing product merge was established for either case.
- **Strict orphan assertion failed:** no-embrace seed 5, decision 2272, first section-5 room. Four detached nodes belong to one retained CardWidget summary layout; one layout is within the production capacity of four (`scripts/card_widget.gd:91`, retention at `:1631`, cleanup at `:1685`). All four disappear on scene deletion. The retained-tree implementation dates to perf-44 (`e70716b64`), before the listed merges; the same seed/census result appears in qa-56; the strict failure is retained, alongside passing ownership/capacity checks. Replay no-embrace seed 5 through decision 2273.
- **Observer revisions:** 85 opening-Health records, 20 pre-readiness preview records and 25 ambiguous terrain records remain in the raw ledger. Early default seeds 4/5 compared detached cards before run projection and terrain by tile instead of ID. Independent recomputation verifies 20 preview records/61 card definitions; the 608-action terrain replay and overlapping-ID negative-control regression pass. Original alarms and failed diagnostic attempts remain outside Git. Corrected-observer runs exclude those first two from their required count. Initial opening Health 24 versus hunt override 9999 is inherited. Untriaged model records: 0. Literal campaign `SCRIPT ERROR:` count: 0.

The coarse tree-growth alarms compare populated retained pools against the cold tree (`tools/run_hunt.gd:270`). Pool-adjusted censuses and owner/capacity checks are reported separately; original alarms remain in campaign findings. Censuses retain unchanged strict assertions. Full tree/pool/tile/owner results: `node-census-triage.json`. Independent lifetime ownership: **PASS**, 746 room samples, 28 positive orphan samples, 0 unowned/capacity/cleanup failures. See `lifetime-ownership.json`.

Checks observed:

- Cold import: exit 0; inherited certificate/duplicate-UID diagnostics retained.
- `QA56 CENSUS OVERALL: FAIL 6/2 required comparisons; 7 attempts retained` (unchanged strict orphan assertion).
- `QA56 LIFETIME OWNERSHIP: PASS runs=17 room_samples=746 positive_samples=28 unknown_or_capacity_failures=0 pending=0`
- `QA56 OBSERVER VALIDATION: PASS board/stage/forecast/rail/health/sliced-HUD poisoning detected; original references restored; scale/zoom change+restore checked`
- `QA64 EVENT ENTRY: PASS entries=2 hovered_choices=126 map_close_reopen=4`
- `QA56 MENU CONTINUE: PASS committed combat preserved; overlapped loading and fresh presentation checked`
- `QA56 PURCHASE PURGE: PASS real purchase/confirmation/Exhaust; fresh presentation checked` (also filtered pack view).
- `QA64 INPUT CONTROL: PASS normalized_prefix=90/90 raw_prefix=40/90` (only generated node ordinals differ).
- `QA64 TERRAIN OBSERVER: PASS overlapping tile IDs checked; poisoned live Health detected`
- `QA64 EVENT COVERAGE: PASS completed=17 event_decisions=320 checks=320 failures=0 pending=0`
- `QA64 PREVIEW PROJECTION: PASS records=20 cards=61 failures=0`
- Three final native scripts: headless `--check-only`, exit 0 each. Engine-only texture stress: `QA64 DUMMY RID STRESS: finished batches=6 workers=8`, exit 0, no texture errors/leak warning.
- Python default: `Ran 183 tests in 29.822s` / `OK`; audit: 55 modules, 19 selected. Optional Git timing-cache write was denied by read-only metadata; suite exit 0. No full suites ran.

**Proof for the design owner:** exact three windowed commands/contracts and expected capture paths are in README. No windowed attempt or PNG capture occurred. Required size/scale: 1920×1080, 100%. Native whole-run/event/targeted-replay scripts have headless parser checks; visual correctness remains unverified. No inspection-fixture command was requested; director owns that workflow.

**TODO_DESIGN:** none. **Chosen defaults:** diagnostic-only inherited hunt settings, named probe bounds/negative controls, private evidence paths and corrected-observer minimum; enumerated in README. **Open issues:** the runtime observations above and native pixel inspection. Director owns commit, peer review, fixture and publication.
