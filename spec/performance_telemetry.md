# Runtime performance telemetry

Escape the Umbra records low-overhead performance windows so Steam Deck and playtest builds can identify frame-time regressions without copying profiler files between devices. This is separate from the gameplay-event contract in `spec/analytics.md`.

## What is recorded

`PerformanceTelemetry` samples frame intervals every rendered process frame and rendering monitors every tenth frame. Once per 60-second window (and on shutdown), it writes one summary containing:

- frame interval mean, median, p95, p99, maximum, and missed 60/50/30/20 FPS budgets;
- draw calls, canvas objects, primitives, and process-time mean/maximum;
- static memory, object, node, and orphan-node counts;
- renderer, viewport, OS/model, Steam Deck detection, and game version;
- gameplay context: mode, depth/type/element, turn, living enemies, hand/relic counts, Umbra stage, animation activity, targeting state, controller hand state, and the active map/menu/grimoire/pile/character surface;
- frame distributions split into active workload, enemy-density, run-depth, and relic-density cohorts;
- exact call counts and elapsed microseconds for instrumented stage, hand, card-preview, tracker, pile, character, and combat-engine phases.

The sampler never writes raw per-frame events to disk. It keeps at most 7,200 frame samples plus the active cohort copies in memory and performs percentile sorting only when a summary is flushed. Context changes update a cached cohort list; they do not flush or write files. Payloads do not include Steam ID, persona name, save data, card history, or free-form player text.

Each summary also includes a `steam_stats` transport diagnostic. It records the selected platform prefix, current-stats readiness, queued/pending counts, accepted and rejected keys, and any shutdown `StoreStats` result. This does not contain Steam identity; it exists so a support bundle can distinguish missing sampling from a client-side Steam upload failure.

## Local storage

Records are append-only JSONL at:

```text
user://telemetry/performance-YYYY-MM-DD.jsonl
```

The sibling `user://telemetry/meta.json` contains a random installation ID used to group sessions from one install; it contains no Steam ID or persona. `SteamService` may relocate Godot's `user://` root into the Steam-user-specific Escape the Umbra directory, but the telemetry path remains the same relative to `user://`. Setting `telemetry/performance/local_enabled=false` disables both the JSONL records and the persistent installation ID while still allowing Steam or explicitly configured HTTP aggregation to sample.

## Upload configuration

Uploading is disabled when no endpoint is configured. A playtest build can enable it without another client dependency:

```text
LABYRINTH_TELEMETRY_ENDPOINT=https://telemetry.example.com/v1/performance
LABYRINTH_TELEMETRY_TOKEN=<ingest-only bearer token>
```

The endpoint may also be set as `telemetry/performance/upload_url` in project settings. The token is intentionally environment-only so it is not committed in the project. Godot's built-in `HTTPRequest` sends one JSON summary per window. A failed or busy request never deletes the local JSONL record.

The recommended inexpensive collector is a small Cloudflare Worker that validates the schema/token and writes the body to R2. It adds no game SDK, can start within the Workers and R2 free tiers, and preserves the raw summaries for later aggregation. PostHog is a reasonable dashboard-first alternative, but it introduces a third-party analytics service and event model.

## Steamworks aggregates

Steam-active builds automatically mirror additive performance aggregates into predeclared Steamworks User Stats. The API names start with one of these versioned platform prefixes:

```text
perf_v1_windows_desktop
perf_v1_macos_desktop
perf_v1_linux_desktop
perf_v1_linux_steamdeck
```

After Steam initialization, `SteamService` explicitly calls `RequestCurrentStats` and waits for a successful `UserStatsReceived` callback for the active app and Steam user before reading or writing any counter. Performance windows that arrive first are merged into an additive readiness queue, persisted in the account-scoped user directory, and released after that callback; the once-per-session counter is admitted to that queue only once. This small transport spool survives an early shutdown and is removed as soon as Steam accepts every queued delta. Every 60-second telemetry window then calls `SetStat` only for non-zero global metrics, active frame cohorts, and subsystem groups that actually ran. A typical window therefore touches roughly 30–60 keys even though the complete schema contains 676 definitions. `SetStat` changes Steam's local in-memory stat cache; `SteamService` makes one non-overlapping batched `StoreStats` call at most every five minutes, plus shutdown, and clears each pending absolute target only after Steam's asynchronous stored callback for the active app succeeds. If Steam rejects a store and refreshes its volatile cache from the server, the service reapplies those retained targets before retrying so the diagnostic and once-per-session increments survive.

The cohort counters provide both a denominator (`samples`) and missed-frame counts at 20, 33.33, and 50 ms. Section groups provide both `calls` and `tenths_ms`. Those pairs make ratios and average cost per call mergeable across users; percentiles and maxima remain in local/HTTP JSON because globally summing them would be mathematically misleading.

Steam User Stats are associated with the current Steam account even though the committed report tool reads only global fleet aggregates and never requests individual identities. Collection is enabled by default for current playtest builds; the shipping privacy disclosure and any required opt-out policy must describe that behavior accurately.

Valve's public documentation specifies a 128-byte stat-name buffer and a 100-achievement default cap, but does not publish a maximum count for stats. The committed schema stays in the hundreds, updates only an active subset, and must still be validated in each app's Steamworks App Admin before publication.

### One-time App Admin setup

The canonical definition list is `steam/performance_stats_manifest.json`. Expand it to CSV for the main app and Playtest app:

```bash
python3 tools/steam_performance_stats.py schema \
  --output output/steam-performance-stats.csv
```

Create and publish each key as an aggregated, increment-only, client-set `INT` stat. Until the definitions are published, GodotSteam will reject those names and the client will keep only the JSONL summaries.

### Reading fleet-wide results

Use a publisher Web API key only on a trusted development machine or CI environment, never in a game build:

```bash
export STEAMWORKS_PUBLISHER_KEY='<publisher key>'
python3 tools/steam_performance_stats.py report \
  --appid 4531660 \
  --days 7 \
  --output output/steam-performance-playtest.json
```

The report command queries Steam's `GetGlobalStatsForGame` Web API in batches and covers every key in the manifest. Platform and cohort ratios can then be calculated as `missed_frames / samples`; timed-phase mean milliseconds are `tenths_ms / calls / 10`. Whole-operation `_total` phases remain in local JSON but are excluded from Steam sums so nested phases are not double-counted.

`GetGlobalStatsForGame` requires a publisher Web API key, not a Steam Community user API key. A Steamworks partner administrator creates one under **Users & Permissions → Manage Groups**. Prefer a dedicated group containing only the queried application (`4530510` for main and `4531660` for Playtest), grant only **General API calls**, and use an IP whitelist when the trusted reader has a stable outbound address. Valve documents publisher-key creation and permissions in [Authentication using Web API Keys](https://partner.steamgames.com/doc/webapi_overview/auth?l=english&language=english).

On a trusted macOS development machine, store the key without placing it in shell history or the repository:

```bash
security add-generic-password -U -a "$USER" \
  -s "labyrinth-steamworks-publisher-key" -w
```

Enter the value only at the secure prompt created by the trailing `-w`. A report can then inject it directly from Login Keychain into that subprocess without printing it:

```bash
STEAMWORKS_PUBLISHER_KEY="$(security find-generic-password \
  -a "$USER" -s "labyrinth-steamworks-publisher-key" -w)" \
python3 tools/steam_performance_stats.py report \
  --appid 4530510 \
  --days 7 \
  --output output/steam-performance-main.json
```

Steam Cloud/Remote Storage still only synchronizes player-owned files between that player's devices; it is not used as a central developer analytics inbox. The richer JSON performance window remains the exact diagnostic source of truth, while Steam User Stats provides automatic fleet-wide aggregates without another runtime dependency.

References:

- [Steamworks ISteamUserStats](https://partner.steamgames.com/doc/api/ISteamUserStats?language=english)
- [Steamworks Stats and Achievements](https://partner.steamgames.com/doc/features/achievements?l=english)
- [Steamworks GetGlobalStatsForGame](https://partner.steamgames.com/doc/webapi/ISteamUserStats?l=english&language=english)
- [Steam Cloud](https://partner.steamgames.com/doc/features/cloud?language=english)
- [ISteamRemoteStorage](https://partner.steamgames.com/doc/api/ISteamRemoteStorage?language=english)
- [Cloudflare Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Cloudflare R2 pricing](https://developers.cloudflare.com/r2/pricing/)
- [PostHog pricing](https://posthog.com/pricing)
