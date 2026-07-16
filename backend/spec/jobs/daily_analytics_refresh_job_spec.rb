require "rails_helper"

RSpec.describe DailyAnalyticsRefreshJob, type: :job do
  it "runs the incremental analytics refresh" do
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: true, message: "Refreshed", data: {})

    described_class.perform_now(start_date: "2026-07-15", end_date: "2026-07-16", calculation_version: "2.0.0")

    expect(DailyAnalyticsRefresh).to have_received(:call).with(
      start_date: "2026-07-15",
      end_date: "2026-07-16",
      calculation_version: "2.0.0"
    )
  end

  it "raises on refresh failure so the job can retry" do
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: false, message: "Calculation failed", data: {})

    expect { described_class.perform_now(start_date: "2026-07-15") }.to raise_error(RuntimeError, "Calculation failed")
  end
end
