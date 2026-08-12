# DiamondIQ Backend README

## Runtime configuration

Operational defaults and external-service endpoints are defined in
`config/ninelens.yml` and loaded through `Rails.application.config.x.diamond_iq`.
Every value in that file has an environment-variable override, including API
URLs, HTTP timeouts, game-detail worker limits, queue retry settings, and task
estimate defaults. Secrets such as `ADMIN_API_TOKEN` and database credentials
remain environment or Rails-credentials values.

## Sample-data bootstrap

For a local installation with real MLB data spanning April-May 2025 and April-May 2026, run:

```sh
bin/rails sample_data:bootstrap
```

See [docs/sample_data.md](docs/sample_data.md) for the preview command, expected scope, and optional controls.

## MLB roster synchronization

After migrating the database, synchronize a team's dated 40-man roster with:

```sh
bin/rails 'mlb_roster:sync[116,2026,2026-07-14]'
```

See [docs/roster_sync.md](docs/roster_sync.md) for the roster model contract, status normalization, membership-window behavior, environment-variable usage, and background-job option.

To populate profiles for existing players without synchronizing team rosters:

```sh
bin/rails mlb_player_profiles:sync
```

This defaults to players whose `player_profiles` record is missing. Use `ONLY_MISSING=false` to refresh existing profiles, `LIMIT=100` for a bounded run, or `MLB_IDS=700270,669360` for specific players.
