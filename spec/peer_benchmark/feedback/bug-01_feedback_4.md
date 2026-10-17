# bug-01 feedback 4 — the native dump ran: classify the 44 differing cases

The dump worked (0 script errors). Outputs: `output/bug-01/native_dump_run2/`. It holds `report.json` for every
case, images for representative cases (002, 010, 011, 021, 027, 028, 046, 058, 101, 103, 104, 105) and the run log.
`time_raw_0_25s` is 0 px in every case, so the shader-`TIME` hypothesis is rejected: nothing animates over 0.25 s.

## My preliminary reading (confirm against your case definitions)
| Pattern | Cases | Reading |
|---|---|---|
| restored ≠ fresh only in a 56×12 box at (778,332); fresh = original | 10–14 (HP only, doors) | The restored board shows the HP damage ghost (pale trail from 24→12; see case_010). The fresh board never saw the old HP. Expected behaviour, so the test must settle or reset the health ghost before comparing, not treat it as cache drift. |
| restored = fresh (0 px); fresh ≠ original | 46–91, 101 (elemental floors, combined) | The case changes the floor on purpose. For cache correctness the right comparison is restored vs fresh, which passes. The native assertion against "original submissions" is the wrong baseline here. |
| restored = original (0 px); fresh differs | 21 floor light, 27 zoom, 28 pan, 104 hidden layout reset, 2/3 actor-clock fixtures | Either "original" means "the same state rendered earlier", in which case this is fine, or the restored board kept the pre-change image, which would be a **real stale-cache bug** (light, zoom or pan changes not redrawing). This is the crucial question. |
| All three differ | 103 partial reactivation, 105 new room | Needs your analysis. |

## Do
1. **Classify every case** against its definition: expected-change (wrong baseline), ghost/transient UI (settle it),
   or cache bug.
2. **Cache bugs.** If 21/27/28/104/103/105 really keep stale floor pixels after light, zoom, pan, layout or room
   changes, that's a production bug. Fix the invalidation, add a native regression, and tell me what a player would
   see (e.g. floor not updating after zoom).
3. **Wrong baselines.** Compare restored vs fresh, with original only where the case means "no change". Settle the
   health ghost (and any other transient UI) before the native comparison.
4. Keep strict pixel equality. The mutation must still fail on its pixel alone.
5. Hand back the native proof command and the mutation command.
