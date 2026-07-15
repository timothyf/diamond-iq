require "rails_helper"

RSpec.describe MlbRosterStatus do
  describe ".normalize" do
    it "normalizes active, injured-list, and minor-league codes" do
      expect(described_class.normalize(code: "A", description: "Active")).to eq("active")
      expect(described_class.normalize(code: "D10", description: "Injured 10-Day")).to eq("injured_10_day")
      expect(described_class.normalize(code: "RM", description: "Reassigned to Minors")).to eq("minors")
    end

    it "preserves useful unknown status descriptions" do
      expect(described_class.normalize(code: "NEW", description: "Special Assignment")).to eq("special_assignment")
      expect(described_class.normalize(code: "NEW", description: nil)).to eq("unknown_new")
    end
  end

  it "identifies normalized injured-list statuses" do
    expect(described_class.injured?("injured_60_day")).to be(true)
    expect(described_class.injured?("active")).to be(false)
  end

  it "prioritizes active status for the current-team cache" do
    expect(described_class.priority("active")).to be < described_class.priority("injured_10_day")
  end
end
