require "rails_helper"

RSpec.describe AdminTaskJob, type: :job do
  it "persists completion progress and a result summary" do
    run = AdminTaskRun.create!(task_name: "player_positions_backfill", total_items: 1)
    allow(AdminTaskRunner).to receive(:call).and_return(
      success: true,
      task: run.task_name,
      message: "Rebuilt 25 player positions",
      data: { updated_count: 25 }
    )

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(
      status: "completed",
      completed_items: 1,
      failed_items: 0,
      error_message: nil
    )
    expect(run.result_data).to include(
      "success" => true,
      "message" => "Rebuilt 25 player positions",
      "data" => { "updated_count" => 25 }
    )
    expect(run.started_at).to be_present
    expect(run.finished_at).to be_present
    expect(run.last_heartbeat_at).to be_present
  end

  it "persists service failures without leaving the run active" do
    run = AdminTaskRun.create!(task_name: "mlb_schedule_sync", total_items: 1)
    allow(AdminTaskRunner).to receive(:call).and_return(
      success: false,
      task: run.task_name,
      message: "Start date is required",
      data: { errors: [ "Start date is required" ] }
    )

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(
      status: "failed",
      completed_items: 0,
      failed_items: 1,
      error_message: "Start date is required"
    )
    expect(run.result_data.dig("data", "errors")).to eq([ "Start date is required" ])
  end
end
