require "rails_helper"

RSpec.describe MlbRosterSyncJob, type: :job do
  it "runs roster synchronization through Active Job" do
    result = { success: true, message: "Synchronized", data: { membership_count: 1 } }
    allow(MlbRosterSync).to receive(:call).and_return(result)

    expect(
      described_class.perform_now(
        team_mlb_id: 116,
        season: 2026,
        roster_type: "40Man",
        as_of: "2026-07-14"
      )
    ).to eq(result)
    expect(MlbRosterSync).to have_received(:call).with(
      team_mlb_id: 116,
      season: 2026,
      roster_type: "40Man",
      as_of: "2026-07-14"
    )
  end

  it "raises so the queue adapter can retry failures" do
    allow(MlbRosterSync).to receive(:call).and_return(success: false, message: "HTTP 503", data: {})

    expect do
      described_class.perform_now(team_mlb_id: 116, season: 2026)
    end.to raise_error(RuntimeError, "MLB roster synchronization failed: HTTP 503")
  end
end
