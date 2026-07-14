require "rails_helper"

RSpec.describe "Api::Positions", type: :request do
  it "returns position lookup data in display order" do
    first_base = create_position(
      mlb_code: "3",
      abbreviation: "1B",
      name: "First Base",
      position_type: "infielder",
      sort_order: 3
    )
    pitcher = create_position(
      mlb_code: "1",
      abbreviation: "P",
      name: "Pitcher",
      position_type: "pitcher",
      sort_order: 1
    )

    get api_positions_path

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").map { |position| position.fetch("id") }).to eq([pitcher.id, first_base.id])
    expect(json_body.dig("data", 0, "mlb_code")).to eq("1")
    expect(json_body.dig("data", 0, "abbreviation")).to eq("P")
    expect(json_body.dig("data", 0, "position_type")).to eq("pitcher")
  end
end
