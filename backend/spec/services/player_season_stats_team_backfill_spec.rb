require "rails_helper"

RSpec.describe PlayerSeasonStatsTeamBackfill, type: :service do
  it "backfills missing team ids from the associated player team" do
    tigers = create_team(abbreviation: "DET", team_name: "Tigers")
    existing_team = create_team(abbreviation: "MIN", team_name: "Twins")
    player = create_player(team: tigers, attributes: { first_name: "Al", last_name: "Kaline" })
    stat_type = create_stat_type(name: "homeRuns", label: "HR")
    missing_team_stat = create_player_season_stat(
      player: player,
      stat_type: stat_type,
      attributes: { season: 1965, team: nil, value: 18 }
    )
    existing_team_stat = create_player_season_stat(
      player: player,
      stat_type: stat_type,
      attributes: { season: 1970, team: existing_team, value: 16 }
    )

    result = described_class.call

    expect(result).to include(
      dry_run: false,
      missing_count: 1,
      eligible_count: 1,
      updated_count: 1,
      skipped_count: 0
    )
    expect(missing_team_stat.reload.team).to eq(tigers)
    expect(existing_team_stat.reload.team).to eq(existing_team)
  end

  it "reports eligible rows without updating them during a dry run" do
    team = create_team
    player = create_player(team: team)
    stat = create_player_season_stat(player: player, attributes: { team: nil })

    result = described_class.call(dry_run: true)

    expect(result).to include(
      dry_run: true,
      missing_count: 1,
      eligible_count: 1,
      updated_count: 0,
      skipped_count: 0
    )
    expect(stat.reload.team).to be_nil
  end
end
