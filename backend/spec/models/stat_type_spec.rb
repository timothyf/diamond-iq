require "rails_helper"

RSpec.describe StatType, type: :model do
  it "is valid with a name, label, and category" do
    expect(create_stat_type).to be_valid
  end

  it "allows the same name in different categories" do
    create_stat_type(name: "avg", category: "batting")

    stat_type = described_class.new(name: "avg", label: "AVG", category: "pitching")

    expect(stat_type).to be_valid
  end

  it "requires the name to be unique within a category" do
    create_stat_type(name: "avg", category: "batting")

    duplicate = described_class.new(name: "avg", label: "AVG", category: "batting")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include("has already been taken")
  end

  it "requires required fields" do
    stat_type = described_class.new

    expect(stat_type).not_to be_valid
    expect(stat_type.errors[:name]).to include("can't be blank")
    expect(stat_type.errors[:label]).to include("can't be blank")
    expect(stat_type.errors[:category]).to include("can't be blank")
  end
end
