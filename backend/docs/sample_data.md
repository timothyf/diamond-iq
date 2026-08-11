# Sample-data bootstrap

The bootstrap task imports real regular-season MLB data for April-May 2025 and April-May 2026. It is intended for a fresh development installation: it seeds stat types and positions, imports batting and pitching season stats, then synchronizes schedules, game details, player profiles, and Statcast pitch data.

Run migrations first, then preview the work:

```sh
bin/rails db:prepare
DRY_RUN=1 bin/rails sample_data:bootstrap
```

Run the import:

```sh
bin/rails sample_data:bootstrap
```

This imports two full two-month MLB windows, so it makes network requests for many games and can take a while. The task is safe to rerun: existing pitch data is skipped by default. Use `REPLACE_EXISTING=1` to replace pitch rows and season-stat rows in the configured sample periods.

Useful options:

```sh
WORKER_COUNT=4 bin/rails sample_data:bootstrap
SKIP_PITCH_DATA=1 bin/rails sample_data:bootstrap
SKIP_SEASON_STATS=1 SKIP_PROFILES=1 bin/rails sample_data:bootstrap
```

The date windows and pitch-download chunk size are maintained in `config/sample_data.yml`.
