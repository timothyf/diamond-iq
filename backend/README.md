# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

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
