module TestDataHelper
  def json_body
    JSON.parse(response.body)
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
        stat_type: stat_type,
        season: 2024,
        value: 1.5
      }.merge(attributes)
    )
  end
end
