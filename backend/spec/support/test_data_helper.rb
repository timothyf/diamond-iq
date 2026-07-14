module TestDataHelper
  def json_body
    JSON.parse(response.body)
  end

  def with_admin_api_token(token)
    previous_token = ENV["ADMIN_API_TOKEN"]
    token.present? ? ENV["ADMIN_API_TOKEN"] = token : ENV.delete("ADMIN_API_TOKEN")

    yield
  ensure
    previous_token.present? ? ENV["ADMIN_API_TOKEN"] = previous_token : ENV.delete("ADMIN_API_TOKEN")
  end

  def admin_headers(token = "test-admin-token")
    { "Authorization" => "Bearer #{token}" }
  end

  def create_team(attributes = {})
    index = Team.count + 1

    Team.create!(
      {
        mlb_id: 1000 + index,
        name: "Team #{index}",
        abbreviation: "T#{index}",
        team_name: "Team#{index}",
        location_name: "City #{index}",
        short_name: "Club#{index}",
        team_code: "tm#{index}",
        file_code: "tm#{index}"
      }.merge(attributes)
    )
  end

  def create_player(team: nil, attributes: {})
    team ||= create_team
    index = Player.count + 1

    Player.create!(
      {
        mlb_id: 2000 + index,
        first_name: "First#{index}",
        last_name: "Last#{index}",
        team: team
      }.merge(attributes)
    )
  end

  def create_stat_type(attributes = {})
    index = StatType.count + 1

    StatType.create!(
      {
        name: "stat#{index}",
        label: "STAT#{index}",
        category: "batting"
      }.merge(attributes)
    )
  end

  def create_player_season_stat(player: nil, stat_type: nil, attributes: {})
    player ||= create_player
    stat_type ||= create_stat_type

    PlayerSeasonStat.create!(
      {
        player: player,
        team: player.team,
        stat_type: stat_type,
        season: 2024,
        scope_type: "team",
        scope_key: player.team.abbreviation,
        value: 1.5
      }.merge(attributes)
    )
  end

  def create_schedule(attributes = {})
    index = Schedule.count + 1

    Schedule.create!(
      {
        season: 2026,
        schedule_type: "regular",
        start_date: Date.new(2026, 3, 25),
        end_date: Date.new(2026, 9, 27),
        source_name: "MLB Stats API",
        source_key: "mlb:2026:regular:#{index}",
        source_url: "https://statsapi.mlb.com/api/v1/schedule?sportId=1&season=2026",
        last_synced_at: Time.current
      }.merge(attributes)
    )
  end

  def create_game(attributes = {})
    index = Game.count + 1

    Game.create!(
      {
        schedule: create_schedule,
        mlb_id: 700_000 + index,
        official_date: Date.current + index.days,
        scheduled_at: Time.current + index.days,
        game_type: "R",
        status: "scheduled",
        home_team: create_team,
        away_team: create_team,
        source_name: "MLB Stats API",
        source_url: "https://statsapi.mlb.com/api/v1.1/game/#{700_000 + index}/feed/live",
        last_synced_at: Time.current
      }.merge(attributes)
    )
  end

  def create_team_season_roster(team: nil, season: 2026, attributes: {})
    team ||= create_team

    Roster.create!(
      {
        team: team,
        season: season
      }.merge(attributes)
    )
  end
end
