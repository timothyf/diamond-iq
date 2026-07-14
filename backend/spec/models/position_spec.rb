require "rails_helper"

RSpec.describe Position, type: :model do
  it "is valid with a supported position type" do
    expect(create_position).to be_valid
  end

  it "normalizes MLB codes and abbreviations" do
    position = create_position(
      mlb_code: " o ",
      abbreviation: " of ",
      name: "Outfield",
      position_type: "outfielder"
    )

    expect(position.mlb_code).to eq("O")
    expect(position.abbreviation).to eq("OF")
  end

  it "requires unique MLB codes and abbreviations" do
    create_position(mlb_code: "1", abbreviation: "P", name: "Pitcher", position_type: "pitcher")

    duplicate = described_class.new(
      mlb_code: "1",
      abbreviation: "p",
      name: "Another Pitcher",
      position_type: "pitcher",
      sort_order: 20
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:mlb_code]).to include("has already been taken")
    expect(duplicate.errors[:abbreviation]).to include("has already been taken")
  end

  it "rejects unsupported position types" do
    position = described_class.new(
      mlb_code: "99",
      abbreviation: "X",
      name: "Unknown",
      position_type: "unsupported",
      sort_order: 99
    )

    expect(position).not_to be_valid
    expect(position.errors[:position_type]).to include("is not included in the list")
  end

  it "orders positions by sort order" do
    second = create_position(sort_order: 2)
    first = create_position(sort_order: 1)

    expect(described_class.ordered).to eq([first, second])
  end
end
