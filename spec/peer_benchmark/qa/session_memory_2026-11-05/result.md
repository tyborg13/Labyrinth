# qa-53 session-memory result

**Live object/resource counts plateau; a small dead-ID bounds-cache leak is
confirmed in the protected asset path.** It is handed to perf-54 with a repro.
No production file, asset, permanent test, save schema or analytics emitter changed.
All task additions remain uncommitted. HEAD is `ec119e9ae7e9fec59212bd541f5a982406e2a762`.

## Numbered requirements

1. **Measured.** The corrected single-process session completes five real-menu
   runs: Noctyrax victory, then four deaths. Decisions: `2595/39/33/33/33`.
   All eleven boundaries include requested CPU/GPU monitors, complete native class
   counts and top 20s; all five recaps are visible and the last scene is the menu.
   Headless GPU zeros are **unavailable** measurements; native GPU proof remains
   for the owner. Before/after tables and all class breakdowns are linked below.
2. **Classified with a stated limit.** Seven first-death warmup classes plateau.
   All later menus have 10,697 objects, 280 nodes, 1,467 resource-monitor entries
   and zero orphans. Texture-bounds entries grow by three dead identities per
   repeated run. Corrected static memory grows 128,888 bytes from menus 2→5;
   exact byte ownership of that small residual is not fully established.
3. **Protected leak reported; diagnostics fixed.** Global bounds entries outlive
   transient door-frame/portrait textures. The independent 1/5/20 lifetime repro
   confirms linear stale data with freed texture IDs. The brief protects perf-54's
   asset-load/preparation path, so it is unchanged. Observer report retention and
   freed-value traversal were corrected. No permanent regression test was added
   because no product fix was made. BAYER exit references are isolated to the two
   pixel shaders; the historical qa-45 ObjectDB/resource warning is not reproduced
   or claimed fixed.

## Settled menu comparison

Static bytes are Godot's counter, not RSS. “After” corrects observation only;
game sources are identical. GPU/video columns in the full tables are unavailable
under the dummy renderer.

| Run | Outcome | Before static bytes | Corrected static bytes | Corrected objects | Resources |
|---|---|---:|---:|---:|---:|
| 1 | victory | 1026947516 | 1025212928 | 10675 | 1462 |
| 2 | defeat | 1032877788 | 1027409172 | 10697 | 1467 |
| 3 | defeat | 1036568824 | 1027414196 | 10697 | 1467 |
| 4 | defeat | 1040258132 | 1027506596 | 10697 | 1467 |
| 5 | defeat | 1043931328 | 1027538060 | 10697 | 1467 |

The original observer held large metadata graphs; its menus 2→5 increased
11,053,540 bytes. The corrected observer keeps reports on disk. Exact stale-key
audit: `37/40/43/46/49` dead instance keys at the five menus. Summary-layout orphans
are bounded (19 before, 27 corrected, every member attributed) and clear on menu
return. No intentional summary cache or retained batch was changed.

## Verification

- Corrected run: `QA53 SESSION: PASS runs=5 boundaries=11 errors=[]`, runner **0**.
- Native census: `QA53 CENSUS CHECK: PASS full native population; repeat class counts identical; bridge overhead=2 objects`, exit **0**.
- Menu: `TEST RESULT: PASS — main menu resume safety`, exit **0**.
- Cleanup: `DEPARTED CLEANUP RESULT: {"cases":3,"draining_at_menu":true,"errors":[],"native":false,"orphans":0}`, exit **0**.
- Persistence: `PERF03 DEFERRED PERSISTENCE RESULT: PASS (0 failures)`, exit **0**;
  its intentional failure-injection errors remain in the raw log.
- Python default: `Ran 182 tests in 37.347s`, `OK`, exit **0**, 19/55 modules;
  isolation audit passes. Optional Git timing-cache write was denied. No full suite.
- Cold import: initial 900-second attempt **124** while converting assets;
  documented 1,800-second retry **0**. Existing CA/UID/socket diagnostics retained.
- Cache repro: `QA53 TEXTURE BOUNDS REPRO: PASS`, exit **0**, growth **1/5/20**
  for textures and atlases after IDs die. Shader exit controls all exit **0**:
  BAYER references **0/1/1/2** for empty/quantize/lines/both; no ObjectDB warning.

**Equality:** all 2,733 actions/policy-RNG states, eleven saved-run hashes, final
profile and 7,789 analytics records agree after documented clock/transport-ID
normalization. All 22 pre/post-census nonmutation checks pass. The first 2,595
committed-state hashes match exactly. The raw strict comparison stays **FAIL**:
initial policy RNG is unseeded and the carried Swift detail says 20 versus 21
minutes. The remaining 138 state hashes are not recomputed or claimed equal.
No assertion on master was rewritten.

## Evidence and handoff

[Detailed ownership/limits](findings.md), [before table](before-boundaries.md),
[after table](after-boundaries.md), [before classes](before-top-20.md),
[after classes](after-top-20.md), [stale keys](stale-bounds-key-audit.json),
[semantic audit](semantic-integrity.json), [unchanged strict failure](strict-integrity-comparison.json),
[checks](headless-verification.json), [source check](source-check.json),
[evidence index](evidence-index.json), [reproduction/defaults/native command](README.md).
Raw logs and per-instance censuses are under `/private/tmp/labyrinth_codex/qa-53/`;
large object graphs stay outside Git. Native captures actually produced: **none**.

Open: protected bounds-cache fix; unassigned small static-memory residual; native
GPU/captures; historical ObjectDB/resource warning. No TODO_DESIGN fields are
needed. Every chosen value is diagnostic and listed in README. The owner retains
commit, peer review, inspection fixture and publication. None was run or requested.
