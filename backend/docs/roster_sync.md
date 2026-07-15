# MLB roster synchronization

## Model contract

`TeamMembership` is the historical source of truth for a player's team, roster status, jersey number, and position over a dated window. Date-specific roster questions must query `TeamMembership.active_on(date)`.

`Roster` and `RosterPlayer` remain as a compatibility snapshot/cache. A successful MLB synchronization rebuilds that cache from active team memberships. New features should not write roster history through these models; they can eventually be removed after all snapshot consumers use `TeamMembership` directly.

`players.team_id` is a denormalized current-team cache retained for existing callers. The synchronizer refreshes it from the best active membership after every import. Historical code must not use it. If more than one active status exists, active status wins over temporary, injured, restricted, minor-league, and unknown statuses; the most recently started membership breaks ties. Because this legacy column is non-null, a player with no active membership retains the last synchronized team until a later active membership is observed.

MLB status codes are preserved in `source_status_code` and `source_status_description`, while `roster_status` stores the normalized value. Known injured-list codes become `injured_7_day`, `injured_10_day`, `injured_15_day`, or `injured_60_day`. Other known codes include `active`, `bereavement`, `paternity`, `family_medical_emergency`, `restricted`, `suspended`, `minors`, and `designated_for_assignment`. Unknown codes fall back to the parameterized MLB description, or `unknown_<code>`.

## Membership windows

The MLB roster endpoint is a snapshot, not a transaction history feed. The synchronizer therefore uses observation-based windows:

- A player's first observed normalized status starts a membership on the requested `as_of` date.
- Repeating the same snapshot updates that membership in place.
- A status or team change closes the prior window on the day before `as_of` and starts a new one on `as_of`.
- A player omitted from a later team snapshot has the MLB-sourced membership closed on the day before `as_of`.
- Importing a snapshot older than the cached roster snapshot is rejected to avoid corrupting inferred windows.

## Running synchronization

The team must already exist with the matching `teams.mlb_id`.

```sh
bin/rails db:migrate
bin/rails 'mlb_roster:sync[116,2026]'
```

Environment variables are also supported:

```sh
TEAM_MLB_ID=116 SEASON=2026 ROSTER_TYPE=40Man bin/rails mlb_roster:sync
```

The synchronization boundary is derived from `SEASON`: completed seasons run through December 31 of that year, while the current season runs through `Date.current`. Future seasons are rejected.

For a queue-backed refresh, enqueue `MlbRosterSyncJob` with `team_mlb_id`, `season`, and optionally `roster_type`; it applies the same automatic season boundary.

## Dated Active and 40-man snapshots

`RosterSnapshot` and `RosterSnapshotPlayer` preserve exact MLB roster responses independently of `TeamMembership` and the legacy `Roster` cache. A snapshot is uniquely identified by team, date, and roster type. Capturing the same date again replaces its player entries and raw response, while snapshots from other dates remain unchanged.

The Admin task `mlb_roster_snapshots_sync` downloads both the `active` and `40Man` views for one team and date. Both downloads must succeed before either snapshot is written. Snapshot capture never opens, closes, or changes a `TeamMembership` window.

The same capture can be run directly:

```sh
bin/rails 'mlb_roster_snapshots:sync[116,2026-07-15]'
```

Stored snapshots can be retrieved with:

```text
GET /api/roster_snapshots?team_mlb_id=116&on=2026-07-15
```

This endpoint performs an exact-date lookup and reports either roster view that has not yet been stored in `meta.missing_roster_types`.
