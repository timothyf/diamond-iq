require "rails_helper"

RSpec.describe Schedule, type: :model do
  it "is valid with source and synchronization metadata" do
    expect(create_schedule).to be_valid
  end

  it "requires a unique source key for idempotent imports" do
    create_schedule(source_key: "mlb:2026:regular")

    duplicate = build_schedule(source_key: "mlb:2026:regular")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:source_key]).to include("has already been taken")
  end

  it "rejects an inverted date range" do
    schedule = build_schedule(start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 4, 1))

    expect(schedule).not_to be_valid
    expect(schedule.errors[:end_date]).to be_present
  end

  def build_schedule(attributes = {})
    described_class.new(
      {
        season: 2026,
        schedule_type: "regular",
        start_date: Date.new(2026, 3, 25),
        end_date: Date.new(2026, 9, 27),
        source_name: "MLB Stats API",
        source_key: "mlb:2026:regular:new",
        last_synced_at: Time.current
      }.merge(attributes)
    )
  end
end
