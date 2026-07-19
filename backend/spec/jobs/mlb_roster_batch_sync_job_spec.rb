require "rails_helper"

RSpec.describe MlbRosterBatchSyncJob, type: :job do
  it "tracks completed teams and stores the batch summary" do
    team = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    run = AdminTaskRun.create!(
      task_name: "mlb_roster_sync",
      task_parameters: { team_scope: "team", team_mlb_id: team.mlb_id, season: Date.current.year },
      total_items: 1
    )
    allow(MlbRosterSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized roster",
      data: { membership_count: 40 }
    )

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(
      status: "completed",
      total_items: 1,
      completed_items: 1,
      failed_items: 0,
      current_item_mlb_id: nil,
      current_item_label: nil
    )
    expect(run.result_data).to include(
      "progress_unit" => "teams",
      "team_count" => 1,
      "successful_team_count" => 1,
      "membership_count" => 40
    )
  end

  it "honors a cancellation request before starting the next team" do
    team = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    run = AdminTaskRun.create!(
      task_name: "mlb_roster_sync",
      task_parameters: { team_scope: "team", team_mlb_id: team.mlb_id, season: Date.current.year },
      total_items: 1,
      cancel_requested_at: Time.current
    )
    allow(MlbRosterSync).to receive(:call)

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "cancelled", completed_items: 0, failed_items: 0)
    expect(run.result_data).to include("progress_unit" => "teams", "cancelled" => true)
    expect(MlbRosterSync).not_to have_received(:call)
  end
end
