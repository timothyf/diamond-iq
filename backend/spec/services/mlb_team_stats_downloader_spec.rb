require "rails_helper"

RSpec.describe MlbTeamStatsDownloader, type: :service do
  it "parses official MLB team hitting totals without aggregating player rows" do
    response = instance_double(
      Net::HTTPSuccess,
      body: {
        "stats" => [{
          "splits" => [{
            "team" => { "id" => 116 },
            "stat" => {
              "gamesPlayed" => 130,
              "hits" => 1060,
              "homeRuns" => 154,
              "avg" => ".242",
              "ops" => ".723"
            }
          }]
        }]
      }.to_json
    )
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)

    expect(described_class.call(season: 2026, category: "batting")).to eq(
      116 => {
        "gamesPlayed" => 130,
        "hits" => 1060,
        "homeRuns" => 154,
        "avg" => ".242",
        "ops" => ".723"
      }
    )
  end
end
