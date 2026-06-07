require "rails_helper"
require "tmpdir"

RSpec.describe PlayerStatsCsvLocator, type: :service do
  it "returns the most recently modified valid stats csv from the search roots" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      invalid_csv = root.join("transactions.csv")
      older_valid_csv = root.join("player_season_stats_2025.csv")
      newer_valid_csv = root.join("pitching_player_season_stats_2026.csv")

      invalid_csv.write("date,amount,description\n2026-01-01,10.00,Not baseball\n")
      older_valid_csv.write("season,playerId,stat_type\n2025,123,batter\n")
      newer_valid_csv.write("season,playerId,stat_type\n2026,456,pitcher\n")

      File.utime(Time.now - 120, Time.now - 120, older_valid_csv)
      File.utime(Time.now, Time.now, newer_valid_csv)

      located_path = described_class.call(search_roots: [root])

      expect(located_path).to eq(newer_valid_csv.to_s)
    end
  end

  it "prefers present batter and pitcher files when both are available" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      older_batter_csv = root.join("mlb_batter_stats_2014-2026.csv")
      present_batter_csv = root.join("mlb_batter_stats-1970-present.csv")
      present_pitcher_csv = root.join("mlb_pitcher_stats-1970-present.csv")

      [older_batter_csv, present_batter_csv, present_pitcher_csv].each do |path|
        path.write("season,playerId,stat_type\n2026,123,batter\n")
      end

      located_paths = described_class.all(search_roots: [root])

      expect(located_paths).to eq([present_batter_csv.to_s, present_pitcher_csv.to_s])
    end
  end

  it "returns nil when no matching csv contains the required stats headers" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join("random.csv").write("foo,bar,baz\n1,2,3\n")

      expect(described_class.call(search_roots: [root])).to be_nil
    end
  end
end
