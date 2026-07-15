class RosterSnapshotSerializer
  def self.call(snapshot)
    new(snapshot).call
  end

  def initialize(snapshot)
    @snapshot = snapshot
  end

  def call
    {
      id: snapshot.id,
      season: snapshot.season,
      roster_type: snapshot.roster_type,
      snapshot_on: snapshot.snapshot_on,
      source_name: snapshot.source_name,
      source_url: snapshot.source_url,
      last_synced_at: snapshot.last_synced_at,
      team: {
        id: snapshot.team.id,
        mlb_id: snapshot.team.mlb_id,
        name: snapshot.team.name,
        abbreviation: snapshot.team.abbreviation
      },
      players: sorted_players.map { |entry| serialize_player(entry) }
    }
  end

  private

  attr_reader :snapshot

  def sorted_players
    snapshot.roster_snapshot_players.sort_by { |entry| [ entry.position_code.to_s, entry.full_name ] }
  end

  def serialize_player(entry)
    {
      id: entry.id,
      player_id: entry.player_id,
      mlb_id: entry.mlb_id,
      full_name: entry.full_name,
      jersey_number: entry.jersey_number,
      position_code: entry.position_code,
      position_name: entry.position_name,
      status_code: entry.status_code,
      status_description: entry.status_description
    }
  end
end
