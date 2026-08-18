require "rails_helper"

RSpec.describe "Api::Player trades", type: :request do
  it "returns one grouped trade with linked and fallback participants" do
    padres = create_team(mlb_id: 135, name: "San Diego Padres", abbreviation: "SD")
    nationals = create_team(mlb_id: 120, name: "Washington Nationals", abbreviation: "WSH")
    wood = create_player(team: nationals, attributes: { mlb_id: 695_578, first_name: "James", last_name: "Wood" })
    trade = Trade.create!(
      mlb_transaction_id: 642_337,
      occurred_on: Date.new(2022, 8, 2),
      description: "Washington traded Juan Soto and Josh Bell to San Diego for six players.",
      source_name: "MLB Stats API transactions",
      source_url: "https://statsapi.mlb.com/api/v1/transactions?transactionIds=642337",
      last_synced_at: Time.current
    )
    trade.trade_participants.create!(
      player: wood,
      player_mlb_id: wood.mlb_id,
      player_name: wood.full_name,
      from_team: padres,
      to_team: nationals,
      from_team_mlb_id: padres.mlb_id,
      from_team_name: padres.name,
      to_team_mlb_id: nationals.mlb_id,
      to_team_name: nationals.name
    )
    trade.trade_participants.create!(
      player_mlb_id: 665_742,
      player_name: "Juan Soto",
      from_team: nationals,
      to_team: padres,
      from_team_mlb_id: nationals.mlb_id,
      from_team_name: nationals.name,
      to_team_mlb_id: padres.mlb_id,
      to_team_name: padres.name
    )

    get api_player_path(wood), params: { sections: "core" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "trades")).to contain_exactly(
      include(
        "mlb_transaction_id" => 642_337,
        "occurred_on" => "2022-08-02",
        "participants" => contain_exactly(
          include(
            "player" => include("id" => wood.id, "mlb_id" => wood.mlb_id, "full_name" => "James Wood"),
            "from_team" => include("id" => padres.id),
            "to_team" => include("id" => nationals.id)
          ),
          include(
            "player" => include("id" => nil, "mlb_id" => 665_742, "full_name" => "Juan Soto"),
            "from_team" => include("id" => nationals.id),
            "to_team" => include("id" => padres.id)
          )
        )
      )
    )
  end
end
