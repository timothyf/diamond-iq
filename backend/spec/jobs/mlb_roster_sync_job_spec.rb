require "rails_helper"

RSpec.describe MlbRosterSyncJob, type: :job do
  it "runs roster synchronization through Active Job" do
    allow(Date).to receive(:current).and_return(Date.new(2026, 7, 14))
    result = { success: true, message: "Synchronized", data: { membership_count: 1 } }
    allow(MlbRosterSync).to receive(:call).and_return(result)

    expect(
      described_class.perform_now(
        team_mlb_id: 116,
        season: 2026,
        roster_type: "40Man"
      )
    ).to eq(result)
    expect(MlbRosterSync).to have_received(:call).with(
      team_mlb_id: 116,
      season: 2026,
      roster_type: "40Man",
      as_of: Date.new(2026, 7, 14)
    )
  end

  it "uses the completed season boundary for a past-season job" do
    allow(Date).to receive(:current).and_return(Date.new(2026, 7, 14))
    allow(MlbRosterSync).to receive(:call).and_return(success: true, message: "Synchronized", data: {})

    described_class.perform_now(team_mlb_id: 116, season: 2025)

    expect(MlbRosterSync).to have_received(:call).with(
      team_mlb_id: 116,
      season: 2025,
      roster_type: "40Man",
      as_of: Date.new(2025, 12, 31)
    )
  end

  it "raises so the queue adapter can retry failures" do
    allow(MlbRosterSync).to receive(:call).and_return(success: false, message: "HTTP 503", data: {})

    expect do
      described_class.perform_now(team_mlb_id: 116, season: 2026)
    end.to raise_error(RuntimeError, "MLB roster synchronization failed: HTTP 503")
  end
end
