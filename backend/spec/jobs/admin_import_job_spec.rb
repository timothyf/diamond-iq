require "rails_helper"

RSpec.describe AdminImportJob, type: :job do
  it "imports a staged CSV, persists its summary, and removes the staged contents" do
    run = AdminTaskRun.create!(task_name: "pitch_data_import", total_items: 1)
    run.create_admin_task_upload!(
      original_filename: "pitches.csv",
      content_type: "text/csv",
      byte_size: 36,
      checksum: "checksum",
      contents: "game_pk,at_bat_number,pitch_number\n"
    )
    allow(PitchDataImporter).to receive(:call).and_return(
      success: true,
      message: "Imported 10 pitch data rows",
      data: { imported_count: 10, skipped_count: 0 }
    )

    described_class.perform_now(run.id)

    expect(PitchDataImporter).to have_received(:call).with(
      csv_data: "game_pk,at_bat_number,pitch_number\n",
      source_name: "pitches.csv"
    )
    expect(run.reload).to have_attributes(status: "completed", completed_items: 1)
    expect(run.result_data.dig("data", "imported_count")).to eq(10)
    expect(run.admin_task_upload).to be_nil
  end

  it "persists importer errors and still removes the staged contents" do
    run = AdminTaskRun.create!(task_name: "player_season_stats_import", total_items: 1)
    run.create_admin_task_upload!(
      original_filename: "stats.csv",
      content_type: "text/csv",
      byte_size: 7,
      checksum: "checksum",
      contents: "invalid"
    )
    allow(PlayerStatsImporter).to receive(:call).and_return(
      success: false,
      message: "CSV must include headers",
      data: { errors: [ "CSV must include headers" ] }
    )

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(
      status: "failed",
      failed_items: 1,
      error_message: "CSV must include headers"
    )
    expect(run.admin_task_upload).to be_nil
  end
end
