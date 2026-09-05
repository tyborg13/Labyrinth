## Use Steam Target-Hardware Telemetry

When a performance report comes from a Steam build, read [the telemetry specification](../../../../spec/performance_telemetry.md) and use the committed Steam aggregates as target-hardware evidence when all of the following are true:

- the affected device materially differs from the available development machine, especially Steam Deck;
- the tested build contains the relevant instrumentation and its stat definitions are published for the app that was actually launched;
- the session was allowed to emit at least one summary through an interval, gameplay-context boundary, or clean shutdown, and the client then had a five-minute store opportunity or completed its clean-shutdown flush.

Query before choosing an optimization when a relevant test has already happened, and query again after the candidate build is tested. Determine whether the user launched the main or Playtest app from the test/build context, then resolve that variant's ID from `steam/steam_build_config.env`; never mix their results. Use a short date range covering the test and save the raw report outside committed source unless the task explicitly calls for a checked-in fixture:

```bash
python3 tools/steam_performance_stats.py report \
  --appid <tested-app-id> \
  --days <test-window-days> \
  --output /tmp/<task-id>-steam.json
```

The report command expects `STEAMWORKS_PUBLISHER_KEY` to already be configured in the trusted development environment. The Steam client needs no publisher Web API key to upload: the authenticated SDK session writes client-set User Stats. The publisher key is only for this developer-side global read. Never request that a user paste the key into chat, print it, commit it, place it in an exported build, or persist it beyond the trusted environment they authorized. Creating/revoking a key, publishing stat definitions, or changing App Admin is an external mutation and still requires explicit user authorization.

If the trusted environment does not have a key, do not stop at “telemetry unavailable” and do not make the user operate Steamworks when an authorized signed-in browser session is available. Prefer this autonomous, secret-safe bootstrap:

1. Use Computer Use or browser control with the existing signed-in Steamworks session.
2. Open **Users & Permissions → Manage Groups**, select the group associated with the exact tested app, and inspect its existing Web API key.
3. If an existing publisher key is available, copy it only long enough to inject it into the report subprocess. Never include it in tool output, chat, shell tracing, files, command history, or source control. Clear the clipboard immediately after the subprocess receives it.
4. Run the report and validate transport/sample denominators before continuing.

Reading an existing key through an already authorized account is the default no-involvement path. If no signed-in browser session or suitable existing key is available, explain that specific limitation. Creating or revoking a key is an external mutation: do it only when the user has explicitly authorized that change. The least-privilege creation path is:

1. A Steamworks partner administrator opens **Users & Permissions → Manage Groups**.
2. Create a dedicated performance-telemetry group, or select an existing least-privilege group.
3. Associate the exact app being queried. Escape the Umbra uses main app `4530510` and Playtest app `4531660`; include both only when the same key should query both variants.
4. Select **Create WebAPI Key**, grant only **General API calls**, optionally restrict it to the trusted machine's stable outbound IP, and save.
5. Do not use an ordinary Steam Community user Web API key: `GetGlobalStatsForGame` requires a publisher key whose group contains the queried app.

On macOS, use Login Keychain as the fallback when browser retrieval is unavailable and the user chooses to store the key locally. Never ask them to paste or export the key into chat. The secure prompt created by the trailing `-w` keeps the value out of shell history:

```bash
security add-generic-password -U -a "$USER" \
  -s "labyrinth-steamworks-publisher-key" -w
```

After the user confirms it is stored, inject it only into the report subprocess without printing it:

```bash
STEAMWORKS_PUBLISHER_KEY="$(security find-generic-password \
  -a "$USER" -s "labyrinth-steamworks-publisher-key" -w)" \
python3 tools/steam_performance_stats.py report \
  --appid <tested-app-id> \
  --days <test-window-days> \
  --output /tmp/<task-id>-steam.json
```

If the account lacks Steamworks administrator rights, identify an administrator from the partner home page; only an administrator can create the publisher key or grant the required access. Never inspect or echo the resulting secret.

Validate transport before interpreting performance:

- An omitted-key/API error is not a zero; it usually means the definitions are unpublished, the app/key is wrong, or access failed.
- Treat an all-zero platform cohort with zero `sessions`, `windows`, and `frame_samples` as absent or insufficient upload evidence, not proof of good performance.
- A zero missed-frame or section value is meaningful only when its paired denominator (`samples`, `windows`, or `calls`) is positive for the same platform prefix and time range.
- Use the exact device prefix, such as `perf_v1_linux_steamdeck`; do not blend desktop and Deck cohorts when diagnosing a device report.

Use aggregates to locate the problem, not merely confirm that it exists. Compare missed-frame ratios as `over_* / samples`, section mean cost as `tenths_ms / calls / 10`, and relevant workload cohorts such as `combat_animation` versus `combat_idle`, density, depth, and relic count. Preserve the raw denominators and state the app, prefix, date range, and sample size. Steam aggregates may contain multiple builds or players in the requested window, so do not claim a candidate caused a change unless build exposure makes that inference defensible. Use the richer local JSON/native benchmark to reproduce and attribute any hotspot Steam identifies.

If the current schema cannot answer where the slowdown occurs, add the smallest sparse, additive cohort or paired `calls`/`tenths_ms` section that distinguishes the competing hypotheses. Update the runtime instrumentation, `steam/performance_stats_manifest.json`, `spec/performance_telemetry.md`, and relevant tests together. Every new manifest key also requires publication in the tested app's Steamworks Stats & Achievements admin before a subsequent build can upload it; call that administrative step out explicitly and validate it with a real session before relying on the metric. Missing credentials or unavailable target data should be reported as a limitation, not treated as a blocker to useful matched local profiling.
