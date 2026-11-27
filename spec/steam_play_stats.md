# Steam play stats

Escape the Umbra sends integer Steam User Stats tied to the active Steam
account. Steam aggregates the enabled stats across accounts and exposes a
daily history. The game sends counters, one-time flags and a nonaggregated
first-launch UTC day. Gameplay JSONL, save data, player text, card and combat
history, and session markers stay local. The demo and full app use separate
Steam schemas. The demo collects play stats while its performance stats stay
disabled.

## What the game collects

The `when` field in [the play-stat manifest](../steam/play_stats_manifest.json)
defines each metric. The game records launch platform, main menu arrival,
focused and in-run minutes, tutorial participation, run outcomes, fight
depth, quit screens, controller use, and link and Rise Again presses. A
StoreStats submission reflects changes since the last successful store and
can occur after the day an event happened.

- The first menu activation counts a session and a player launch. Returning
  to the menu within the same app launch adds no session. The Steam Deck
  platform flag uses the Steam SDK check.
- The run clock is the Chronicle clock. Continue uses its saved baseline.
  A locally persisted high-water minute prevents counting the same minute
  again after restarting from an earlier checkpoint on this device.
- The clean-quit path samples the underlying screen, including under
  Settings and the Grimoire. Quit depth uses the run's saved count of combats
  started. A local marker records elapsed wall-clock minutes at launch and
  then on idle frames, at most once per elapsed minute. A leftover marker
  provides the unclean session's bucket at the next Steam launch.
- Load errors count when Continue fails to install a saved run and the menu
  displays its failure dialog. Profile loading already falls back to a backup
  or defaults without a separate player-facing load-error cover.
- Save errors count once per profile or run-checkpoint request that finishes without a successful write, retry, or fallback.

The observer accepts selected events at the local recorder's append boundary.
It queues integer changes in memory. Pending batches and targets persist in
the existing account-scoped Steam stats queue, which also preserves the order
of launches and new runs while Steam stats are unavailable. The automatic
play flush skips the persistence scheduler's rule-resolution and reserved
post-draw frames. Steam stores on the existing 300-second cadence and after
a run ends, with at least 60 seconds between ordinary attempts. The clean-quit
attempt submits within the existing shutdown watchdog and does not wait for a
Steam callback. Headless tests and probes leave the real Steam SDK inactive.
The task's proofs use an in-memory fake.

## Steamworks setup

Generate the CSV from the protected manifest. Create the 77 definitions in
Steamworks App Admin for demo app `5575620`, then publish those definitions.
Use the same schema on the full app `4530510` when it starts collecting play
stats. Preserve API names and meanings across releases. The packed game's
allowlist is checked against the manifest by the task proof.

```sh
python3 tools/steam_play_stats.py schema --output /tmp/steam-play-schema.csv
```

Set type to INT, set by Client, increment only, minimum 0 and default 0.
Set maximum 1 for player flags. Enable aggregation for the listed flags and
counters. Keep `play_v1_first_day` per-account.

## Reporting

Run a report with `STEAMWORKS_PUBLISHER_KEY` in the environment. On macOS the
tool can also read the existing `labyrinth-steamworks-publisher-key` Login
Keychain item. See [performance telemetry](performance_telemetry.md#reading-fleet-wide-results)
for Keychain setup.

```sh
python3 tools/steam_play_stats.py report --appid 5575620 --days 7
python3 tools/steam_play_stats.py report --fixture tools/play01/report_fixture.json
```

The report sums the daily totals in the requested inclusive UTC window. A
player flag contributes on the day Steam records its first increment, so the
funnel figures describe milestone activity in that window across accounts.
The average session uses focused minutes divided by menu sessions. Average
run minutes use new runs as the denominator. The unclean-exit rate divides
unclean exits by recorded session endings. An account can appear on several
platforms if it launches on different devices. Steam documents the aggregation
and daily query parameters. [Steamworks global stats](https://partner.steamgames.com/doc/features/achievements#global_stats),
[GetGlobalStatsForGame](https://partner.steamgames.com/doc/webapi/ISteamUserStats#GetGlobalStatsForGame)
