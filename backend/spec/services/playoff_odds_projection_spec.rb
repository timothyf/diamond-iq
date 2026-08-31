require "rails_helper"

RSpec.describe PlayoffOddsProjection do
  it "uses safe defaults when an older configuration has no projections section" do
    allow(NineLensConfig).to receive(:fetch).with(:operations).and_return({})

    result = described_class.new(divisions: [], remaining_games: [], seed: 2026).result

    expect(result).to include(
      simulations: 10_000,
      remaining_games: 0,
      teams: {}
    )
  end
end
