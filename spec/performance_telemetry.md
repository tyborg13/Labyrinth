# Runtime performance telemetry

Escape the Umbra records low-overhead performance windows so Steam Deck and playtest builds can identify frame-time regressions without copying profiler files between devices. This is separate from the gameplay-event contract in `spec/analytics.md`.

## What is recorded

`PerformanceTelemetry` samples frame intervals every rendered process frame and rendering monitors every tenth frame. Once per 60-second window (and on shutdown), it writes one summary containing:

- frame interval mean, median, p95, p99, maximum, and missed 60/50/30/20 FPS budgets;
- draw calls, canvas objects, primitives, and process-time mean/maximum;
- static memory, object, node, and orphan-node counts;
- renderer, viewport, OS/model, Steam Deck detection, and game version;
- coarse gameplay context: mode, depth/type/element, turn, living enemies, hand/relic counts, Umbra stage, animation activity, targeting state, and controller hand state.

The sampler never writes raw per-frame events to disk. It keeps at most 7,200 frame samples in memory and performs percentile sorting only when a summary is flushed. Payloads do not include Steam ID, persona name, save data, card history, or free-form player text.

## Local storage

Records are append-only JSONL at:

```text
user://telemetry/performance-YYYY-MM-DD.jsonl
```

The sibling `user://telemetry/meta.json` contains an anonymous random installation ID used to group sessions from one install. `SteamService` may relocate Godot's `user://` root into the Steam-user-specific Escape the Umbra directory, but the telemetry path remains the same relative to `user://`.

## Upload configuration

Uploading is disabled when no endpoint is configured. A playtest build can enable it without another client dependency:

```text
LABYRINTH_TELEMETRY_ENDPOINT=https://telemetry.example.com/v1/performance
LABYRINTH_TELEMETRY_TOKEN=<ingest-only bearer token>
```

The endpoint may also be set as `telemetry/performance/upload_url` in project settings. The token is intentionally environment-only so it is not committed in the project. Godot's built-in `HTTPRequest` sends one JSON summary per window. A failed or busy request never deletes the local JSONL record.

The recommended inexpensive collector is a small Cloudflare Worker that validates the schema/token and writes the body to R2. It adds no game SDK, can start within the Workers and R2 free tiers, and preserves the raw summaries for later aggregation. PostHog is a reasonable dashboard-first alternative, but it introduces a third-party analytics service and event model.

## Steamworks boundary

Steamworks User Stats is useful for a very small number of published aggregate `INT`, `FLOAT`, or `AVGRATE` values. It is not an arbitrary structured telemetry stream, and `StoreStats` is rate-limited and intended for infrequent updates. Steam Cloud/Remote Storage synchronizes player-owned files between that player's devices; it is not a central developer analytics inbox. Therefore:

- keep the JSON performance window as the source of truth;
- optionally mirror a few stable aggregates (for example session p95 frame time) into predeclared Steam stats after those stat keys are configured and published in Steamworks App Admin;
- do not attempt to use Steam Cloud as a hidden log-upload mechanism.

References:

- [Steamworks ISteamUserStats](https://partner.steamgames.com/doc/api/ISteamUserStats?language=english)
- [Steamworks Stats and Achievements](https://partner.steamgames.com/doc/features/achievements?l=english)
- [Steam Cloud](https://partner.steamgames.com/doc/features/cloud?language=english)
- [ISteamRemoteStorage](https://partner.steamgames.com/doc/api/ISteamRemoteStorage?language=english)
- [Cloudflare Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Cloudflare R2 pricing](https://developers.cloudflare.com/r2/pricing/)
- [PostHog pricing](https://posthog.com/pricing)
