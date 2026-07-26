require "rails_helper"

RSpec.describe "Api::Watchlists", type: :request do
  it "creates watchlists and persists structured acquisition evaluations" do
    team = create_team(name: "Detroit Tigers", abbreviation: "DET")
    player = create_player(team: team, attributes: { first_name: "Target", last_name: "Player" })

    post api_watchlists_path, params: { name: "Trade targets", description: "Deadline candidates" }

    expect(response).to have_http_status(:created)
    watchlist_id = json_body.dig("data", "id")

    post api_watchlist_watchlist_entries_path(watchlist_id), params: { player_id: player.id }

    expect(response).to have_http_status(:created)
    entry_id = json_body.dig("data", "id")
    expect(json_body.dig("data", "recommendation")).to eq("monitor")

    patch api_watchlist_entry_path(entry_id), params: {
      priority: "high", status: "active", recommendation: "pursue",
      fit_score: 5, need_score: 4, cost_score: 3, risk_score: 2,
      tags: [ "Power", " power ", "trade target" ], notes: "Fits the middle of the order."
    }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "tags")).to eq([ "power", "trade target" ])
    expect(json_body.dig("data", "fit_score")).to eq(5)
    expect(json_body.dig("data", "player", "full_name")).to eq("Target Player")

    get api_watchlists_path

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", 0, "entries", 0, "recommendation")).to eq("pursue")
  end

  it "prevents duplicate targets and rejects out-of-range evaluation scores" do
    watchlist = Watchlist.create!(name: "Free agents")
    entry = watchlist.entries.create!(player: create_player)

    post api_watchlist_watchlist_entries_path(watchlist), params: { player_id: entry.player_id }
    expect(response).to have_http_status(:unprocessable_content)

    patch api_watchlist_entry_path(entry), params: { fit_score: 6 }
    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to include("Fit score")
  end
end
