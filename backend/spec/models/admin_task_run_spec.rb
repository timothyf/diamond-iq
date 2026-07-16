require "rails_helper"

RSpec.describe AdminTaskRun, type: :model do
  it "calculates progress, elapsed time, and estimated remaining time" do
    run = described_class.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      total_items: 100,
      completed_items: 38,
      failed_items: 2,
      started_at: 4.minutes.ago
    )

    expect(run.processed_items).to eq(40)
    expect(run.progress_percentage).to eq(40.0)
    expect(run.elapsed_seconds).to be_between(239, 241)
    expect(run.estimated_remaining_seconds).to be_between(358, 362)
  end

  it "recognizes active, terminal, and cancellation states" do
    run = described_class.new(task_name: "mlb_game_details_sync", status: "queued")
    expect(run).to be_active
    expect(run).not_to be_terminal

    run.status = "cancelled"
    run.cancel_requested_at = Time.current
    expect(run).to be_terminal
    expect(run).to be_cancel_requested
  end
end
