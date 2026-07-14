# Player Positions

Stage 2 introduces normalized position lookup and player-position assignment tables.

## Data model

- `positions` stores reusable position metadata such as MLB code, abbreviation, display name, type, and display order.
- `player_positions` connects a player to one or more positions.
- A `NULL` season represents the player's current general position assignment.
- A populated season represents a historical season assignment.
- Each player can have only one primary current position and one primary position per season.

The legacy `team_memberships.primary_position` and `team_memberships.secondary_positions` fields remain available for compatibility. New analytical and profile features should read from `player_positions` after the backfill has been run.

## Setup

```bash
cd backend
bin/rails db:migrate
bin/rails db:seed
```

`db:seed` loads the standard defensive positions through SeedFu.

## Backfill current assignments

After seeding positions, backfill normalized assignments from each player's latest current team membership:

```bash
bin/rails player_positions:backfill_from_team_memberships
```

The task is idempotent. It updates known assignments and removes stale current assignments only when every source position code can be mapped. Unknown codes are reported and existing assignments are preserved for manual review.

## API

Position lookup data is available at:

```text
GET /api/positions
```

Player detail responses include:

- `positions.primary`
- `positions.secondary`
- `positions.assignments`

The assignments collection includes current and historical season-aware records.
