require "rails_helper"

RSpec.describe MlbPlayerProfilesSyncJob, type: :job do
  it "runs profile synchronization through Active Job" do
    result = { success: true, message: "Synchronized", data: { profile_count: 2 } }
    allow(MlbPlayerProfilesSync).to receive(:call).and_return(result)

    expect(
      described_class.perform_now(only_missing: true, batch_size: 25, limit: 100, mlb_ids: [ 700_270 ])
    ).to eq(result)
    expect(MlbPlayerProfilesSync).to have_received(:call).with(
      only_missing: true,
      batch_size: 25,
      limit: 100,
      mlb_ids: [ 700_270 ]
    )
  end

  it "raises so the queue adapter can retry failures" do
    allow(MlbPlayerProfilesSync).to receive(:call).and_return(success: false, message: "HTTP 503", data: {})

    expect do
      described_class.perform_now
    end.to raise_error(RuntimeError, "MLB player profile synchronization failed: HTTP 503")
  end
end
