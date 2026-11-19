# perf-142 round 1 thread-safety review

New Run keeps the round-0 preparation pipeline. Its graph worker now receives
a private dictionary containing the guardian records (id, element and relic),
the resolved guardian weight for the selected depth, and a deep copy of the
special-encounter catalog. The existing authored definitions supply all values.

The seed selected after replacement recovery and profile preparation in
`_start_run()` is authoritative. The staged path reuses a completed or pending
prediction only if both inputs match. A mismatch cancels the prediction and
runs the same solver for the authoritative inputs on the worker. The direct
boot path still uses the synchronous engine entry point. Save replacement and
analytics are committed together after graph preparation.

## Worker audit

The worker entry runs `_produce_owned_cpu_value` → `_generate_graph` →
`initialize_prepared`. The graph and paint workers can observe only their own
inputs and the synchronized per-job cancellation token. Worker reachability
below includes the shared generator's older-revision branches where useful for
checking the common code.

| Reachable code | Ownership and static state |
| --- | --- |
| `initialize_prepared`, `_initialize_walk_revision`, `_node`, `_apply_type_fields`, `_ring_coord`, `_depth_bands`, `_depth_bands_or_empty`, `_link`, `_link_by_lane`, `_door_directions`, `_coords` | The caller transfers private input values. Layout, rooms, doors, sections and dictionary writes belong to the worker. `generation_inputs` and the legacy revision-3 entry remain on the calling thread. |
| `_section_layout_v7_with_weight`, `_web_layout_v7`, `_web_row_v7`, `_layout_from_children_v7`, `_weighted_index_v7`, `_weighted_roll`, `_diagnostic_v5` | Private seeded RNG, local candidate arrays, topology and diagnostics. Reads authored constants. No shared cache writes. The worker checks cancellation between section attempts and structural proposals. |
| `_assign_types_v5`, `_prepare_types`, `_solve_types_v5`, `_propagate_types_v5`, `_route_bounds_v5`, `_section_counts_v5`, `_type_signature_v5`, `_types_possible_v5`, `_local_type_possible_v5`, `_fork_types_possible_v5`, `_long_divergence_v5`, `_complete_types_legal`, `_prefix_type_legal`, `_prefix_bounds`, `_is_fight`, `_is_service` | Private domains, topology, memo, search budget and type weights. The worker receives the integer guardian weight. It never calls `DepthRules.data`, `DepthRules.guardian_weight` or `Guardians.for_boss`. |
| `_fallback_layout_v7`, `_fallback_cell`, `_fallback_layout`, `_fallback_walks`, `_straight_fallback_walks`, `_layout_from_walks`, `_walk_layout`, `_walk_layout_v5`, `_walk_moves`, `_section_layout_v5_with_weight`, `_structure_legal_v5`, `_physical_doors_legal`, `_repair_types` | Fallback JSON uses an owned file read and a new parsed dictionary. Older revision search helpers use private writes and read authored constants. Caller-supplied diagnostics callbacks on historical tooling paths are absent on the revision-7 worker path. |
| `refresh_knowledge`, `record_event`, `descendants`, `key`, `active_section`, `room`, `section`, `enabled`, `modern`, `full_visibility` | Read or update the generated run dictionary and its new map event arrays. No shared gameplay or persistence state. |
| `DragonBossLibrary.boss_id_for_depth`, `elemental_boss_order`, `_boss_order_seed`, `element_for_boss`, `room_name_for_boss`, `ElementData.all_elements`, `TypedArrays.strings`, `TypedArrays.vector2i` | Constant lookups, fresh arrays and an owned seeded RNG. The guardian lookup reads the three-field snapshot directly, avoiding both lazy `GameData` registries. |
| `SpecialEncounterLibrary.place_from_catalog`, `_enabled_types`, `_eligible`, `_shuffle`, `_search`, `_routes_legal` | Reads the passed private catalog. Shuffles newly allocated candidates and mutates the owned layout and search state. The worker path cannot invoke the lazy `catalog()` accessor. Cancellation checks also cover placement searches. |

Opening paint runs `_bake_opening_paint` through `bake_band`, `bake_frame`
and `bake_portrait`. The reached paint helpers are `cancel_requested`,
`_brush_mask`, `_ellipse_mask`, `_tinted`, `_gaussian`, `_box_pass`,
`_filtered_wash` and `_max_filter`. They operate on captured CPU image inputs,
private masks, image buffers and palette constants. Cancellation is checked
between paint passes, between blur passes and during row scans. The source,
band, frame and portrait caches are read or published on the main thread.

Textures resolve their CelLook candidate paths on the main thread. The
worker's `_decode_owned_source_image`, `_decode_image_file`,
`_should_prefer_source_file` and `_has_imported_resource` use supplied paths,
owned file/image/config objects and resource-existence checks. Each worker
writes only its preallocated result slot. The main thread joins, reports any
missing or corrupt variants through `CelLook.warn_missing()`, and publishes
textures. The worker cannot touch CelLook's warning flag or GPU resources.

The rig, surface, map and audio producers using the generic drain continue to
produce owned CPU values. The reaper changes their cancellation handoff, not
their preparation or publication APIs. A removed cover cancels pending graph
and paint work. Root-owned drains poll for completion, retry slots cannot be
reused while a prior worker still owns them, and the final root shutdown joins
outstanding work. Audio imports also drain at the root when an attempt ends.
The cover polls the requested alignment streams and publishes finished imports
before the synchronous SFX bank can load them. Optional synchronous audio
warming starts after the scene request completes, avoiding contention with
the PackedScene loader.

## SFX fixture teardown

Verbose Godot logs identified live WAV and Ogg playback objects before the
fixture fix. Stopping voices plus a scene timer still reproduced the warning.
The fixture now stops voices, waits for two observed mixer updates, and frees
the banks. The clean verbose run compared 85 stream lengths and reported
`SFX SYNC BANK TEST RESULT: PASS (0 failures)`, with no leaked instances or
resources still in use. See [Godot 4.6.1's audio mix and playback deletion code](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/audio/audio_server.cpp#L478-L494).

## Focused proof

- The scratch startup harness completed 50 cold-registry New Runs, including
  10 forced seed mismatches. It removed the loading cover with each worker
  active 10 times and immediately attempted 20 retries while the earlier
  drain was still present. The longest measured cover removal was 12.292 ms.
  The run emitted no errors or warnings. The disposable project override
  pointed TLS at the host certificate bundle to avoid the sandbox Keychain
  diagnostic. Production project settings were the same as before.
- The prepared solver matched eight complete release graph receipts for two
  seeds and Umbra depths 0, 1, 5 and 20. Legacy-map hashes, the structural and
  type rejection checks, and assertion-free special-placement fallback passed.
- The typed-array scan found the same seven unrelated worktree findings at
  the round-0 commit when compared with the newer `codex/release`. Applying
  the unit's changed sources to a disposable snapshot of release gave
  `TYPED ARRAY SCAN: 18 scripts; 0 new; 1 pre-existing`.
- The menu input and resume checks, the cel loader check, and SFX-sync passed.
  The SFX-sync fixture's verbose exit showed zero retained playback objects.
- The Steam Demo Windows pack check reported `CEL_PACK_TEST paths=3089
  failures=0`. The macOS release-template smoke loaded 740 scripts and nine
  scenes and reported `EXPORT_SMOKE RESULT: PASS`.

## Headless comparison

Godot 4.6.1, demo seed 7, 1920×1080 at 100% scale. The release control used
the original pinned source at `e5a6d3f53`. The stand-in ran under macOS
`taskpolicy -c background`. Full intervals and phase names are in
`/private/tmp/labyrinth_codex/perf-142/round1/verified-normal.md` and
`verified-background.md`.

| Profile | Longest frame, release → candidate | Press to first map, release → candidate |
| --- | ---: | ---: |
| Normal | 353.118 → 53.695 ms (−84.8%) | 2,909.540 → 3,266.029 ms |
| Stand-in | 5,546.599 → 250.407 ms (−95.5%) | 21,344.933 → 17,687.799 ms |

Both takes matched the release live state, save, profile, first-map receipts and
opening-dialogue image hashes after normalizing the two nondeterministic
fields documented in the probe. All 63 stand-in candidate intervals over
100 ms have named work or wait context. The release stand-in maximum was an
unattributed gap during its scene-request interval. Its longest named
run-state frame measured 2,085.264 ms. The candidate maximum was audio
warming during scene texture preparation.

The normal proxy's longest interval was on the click that dismissed the
opening dialogue and exposed the map. The normal take reached its first map
356.489 ms later than its release control. Native frame limits and renderer
captures remain unverified in the headless sandbox.
