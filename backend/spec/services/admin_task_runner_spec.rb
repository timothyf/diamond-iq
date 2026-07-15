require "rails_helper"

RSpec.describe AdminTaskRunner do
  it "runs a schedule synchronization with normalized inputs" do
    result = { success: true, message: "Synchronized 12 MLB games", data: { created_game_count: 12 } }
    allow(MlbScheduleSync).to receive(:call).and_return(result)

    response = described_class.call(
      task_name: "mlb_schedule_sync",
      params: {
        start_date: "2026-07-15",
        end_date: "2026-07-17",
        game_types: "R,F",
        sport_id: "1"
      }
    )

    expect(response).to include(success: true, task: "mlb_schedule_sync")
    expect(MlbScheduleSync).to have_received(:call).with(
      start_date: Date.new(2026, 7, 15),
      end_date: Date.new(2026, 7, 17),
      game_types: "R,F",
      sport_id: 1
    )
  end

  it "runs player profile synchronization with optional filters" do
    allow(MlbPlayerProfilesSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized 2 MLB player profiles",
      data: { profile_count: 2 }
    )

    described_class.call(
      task_name: "mlb_player_profiles_sync",
      params: { only_missing: "false", batch_size: "25", limit: "2", mlb_ids: "700270,669360" }
    )

    expect(MlbPlayerProfilesSync).to have_received(:call).with(
      only_missing: "false",
      batch_size: 25,
      limit: 2,
      mlb_ids: "700270,669360"
    )
  end

  it "rejects invalid or reversed schedule dates without calling the synchronizer" do
    allow(MlbScheduleSync).to receive(:call)

    response = described_class.call(
      task_name: "mlb_schedule_sync",
      params: { start_date: "2026-07-16", end_date: "2026-07-15" }
    )

    expect(response).to include(success: false, message: "End date must be on or after start date")
    expect(MlbScheduleSync).not_to have_received(:call)
  end

  it "returns a not-found result for tasks outside the allowlist" do
    response = described_class.call(task_name: "db_drop", params: {})

    expect(response).to include(success: false, error: :not_found, task: "db_drop")
  end
end
