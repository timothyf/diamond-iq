require "rails_helper"
require "tempfile"

RSpec.describe "Api::PitchData", type: :request do
  it "lists pitch data rows ordered by most recent game context and applies a bounded limit" do
    earlier = PitchDatum.create!(
      game_pk: 123,
      at_bat_number: 2,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 1),
      pitch_type: "FF",
      raw_data: { "game_pk" => "123", "at_bat_number" => "2", "pitch_number" => "1" }
    )

    latest = PitchDatum.create!(
      game_pk: 124,
      at_bat_number: 3,
      pitch_number: 2,
      game_date: Date.new(2026, 4, 2),
      pitch_type: "SL",
      raw_data: { "game_pk" => "124", "at_bat_number" => "3", "pitch_number" => "2" }
    )

    get api_pitch_data_path, params: { limit: 1 }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "limit")).to eq(1)
    expect(json_body.dig("meta", "count")).to eq(1)
    expect(json_body.fetch("data").length).to eq(1)
    expect(json_body.dig("data", 0, "id")).to eq(latest.id)
    expect(json_body.dig("data", 0, "pitch_type")).to eq("SL")

    get api_pitch_data_path, params: { limit: 9_999 }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "limit")).to eq(500)
    expect(json_body.dig("meta", "per_page")).to eq(500)
    expect(json_body.dig("meta", "page")).to eq(1)
    expect(json_body.dig("meta", "total_pages")).to eq(1)
    expect(json_body.dig("meta", "total_count")).to eq(2)
    expect(json_body.dig("meta", "count")).to eq(2)
    expect(json_body.dig("meta", "data_range")).to eq({ "type" => "game_date", "start" => "2026-04-01", "end" => "2026-04-02" })
    expect(json_body.fetch("data").map { |row| row.fetch("id") }).to eq([latest.id, earlier.id])
  end

  it "defaults pitch data pagination to 20 rows per page" do
    21.times do |index|
      PitchDatum.create!(
        game_pk: 1_000 + index,
        at_bat_number: 1,
        pitch_number: 1,
        game_date: Date.new(2026, 4, 1),
        raw_data: { "game_pk" => (1_000 + index).to_s, "at_bat_number" => "1", "pitch_number" => "1" }
      )
    end

    get api_pitch_data_path

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "limit")).to eq(20)
    expect(json_body.dig("meta", "per_page")).to eq(20)
    expect(json_body.dig("meta", "count")).to eq(20)
    expect(json_body.dig("meta", "total_count")).to eq(21)
    expect(json_body.fetch("data").length).to eq(20)
  end

  it "returns distinct pitch event and pitch type options in metadata" do
    PitchDatum.create!(
      game_pk: 301,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 1),
      pitch_type: "FF",
      events: "strikeout",
      raw_data: { "game_pk" => "301", "at_bat_number" => "1", "pitch_number" => "1" }
    )
    PitchDatum.create!(
      game_pk: 302,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 1),
      pitch_type: "SL",
      events: "walk",
      raw_data: { "game_pk" => "302", "at_bat_number" => "1", "pitch_number" => "1" }
    )

    get api_pitch_data_path, params: { per_page: 1 }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "available_events")).to include("strikeout", "walk")
    expect(json_body.dig("meta", "available_pitch_types")).to include("FF", "SL")
  end

  it "paginates pitch data rows" do
    oldest = PitchDatum.create!(
      game_pk: 100,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 1),
      raw_data: { "game_pk" => "100", "at_bat_number" => "1", "pitch_number" => "1" }
    )
    middle = PitchDatum.create!(
      game_pk: 200,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 2),
      raw_data: { "game_pk" => "200", "at_bat_number" => "1", "pitch_number" => "1" }
    )
    newest = PitchDatum.create!(
      game_pk: 300,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 3),
      raw_data: { "game_pk" => "300", "at_bat_number" => "1", "pitch_number" => "1" }
    )

    get api_pitch_data_path, params: { page: 2, per_page: 1 }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "page")).to eq(2)
    expect(json_body.dig("meta", "per_page")).to eq(1)
    expect(json_body.dig("meta", "total_pages")).to eq(3)
    expect(json_body.dig("meta", "total_count")).to eq(3)
    expect(json_body.dig("meta", "count")).to eq(1)
    expect(json_body.fetch("data").map { |row| row.fetch("id") }).to eq([middle.id])

    expect(json_body.fetch("data").map { |row| row.fetch("id") }).not_to include(newest.id)
    expect(json_body.fetch("data").map { |row| row.fetch("id") }).not_to include(oldest.id)
  end

  it "filters pitch data rows by game date, game pk, pitcher, batter, pitch type, and events" do
    matching_row = PitchDatum.create!(
      game_pk: 777,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 30),
      pitcher: 9001,
      batter: 8001,
      pitch_type: "FF",
      events: "strikeout",
      raw_data: { "game_pk" => "777", "at_bat_number" => "1", "pitch_number" => "1" }
    )

    PitchDatum.create!(
      game_pk: 888,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 30),
      pitcher: 9002,
      batter: 8002,
      pitch_type: "SL",
      events: "walk",
      raw_data: { "game_pk" => "888", "at_bat_number" => "1", "pitch_number" => "1" }
    )

    get api_pitch_data_path,
        params: {
          game_date: "2026-04-30",
          game_pk: "777",
          pitcher: "9001",
          batter: "8001",
          pitch_type: "ff",
          events: "STRIKEOUT"
        }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "count")).to eq(1)
    expect(json_body.dig("meta", "filters")).to include(
      "game_date" => "2026-04-30",
      "game_pk" => "777",
      "pitcher" => "9001",
      "batter" => "8001",
      "pitch_type" => "ff",
      "events" => "STRIKEOUT"
    )
    expect(json_body.fetch("data").map { |row| row.fetch("id") }).to eq([matching_row.id])
  end

  it "sorts rows within a game by inning ascending" do
    seventh_inning = PitchDatum.create!(
      game_pk: 777,
      at_bat_number: 1,
      pitch_number: 1,
      inning: 7,
      inning_topbot: "top",
      game_date: Date.new(2026, 4, 30),
      raw_data: { "game_pk" => "777", "at_bat_number" => "1", "pitch_number" => "1", "inning" => "7" }
    )
    first_inning = PitchDatum.create!(
      game_pk: 777,
      at_bat_number: 2,
      pitch_number: 1,
      inning: 1,
      inning_topbot: "top",
      game_date: Date.new(2026, 4, 30),
      raw_data: { "game_pk" => "777", "at_bat_number" => "2", "pitch_number" => "1", "inning" => "1" }
    )
    third_inning = PitchDatum.create!(
      game_pk: 777,
      at_bat_number: 3,
      pitch_number: 1,
      inning: 3,
      inning_topbot: "bot",
      game_date: Date.new(2026, 4, 30),
      raw_data: { "game_pk" => "777", "at_bat_number" => "3", "pitch_number" => "1", "inning" => "3" }
    )

    get api_pitch_data_path, params: { game_pk: "777" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").map { |row| row.fetch("id") }).to eq([first_inning.id, third_inning.id, seventh_inning.id])
    expect(json_body.fetch("data").map { |row| row.fetch("inning") }).to eq([1, 3, 7])
  end

  it "filters pitch data rows by an inclusive game date range" do
    first_in_range = PitchDatum.create!(
      game_pk: 501,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 28),
      raw_data: { "game_pk" => "501", "at_bat_number" => "1", "pitch_number" => "1" }
    )
    second_in_range = PitchDatum.create!(
      game_pk: 502,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 29),
      raw_data: { "game_pk" => "502", "at_bat_number" => "1", "pitch_number" => "1" }
    )
    PitchDatum.create!(
      game_pk: 503,
      at_bat_number: 1,
      pitch_number: 1,
      game_date: Date.new(2026, 4, 30),
      raw_data: { "game_pk" => "503", "at_bat_number" => "1", "pitch_number" => "1" }
    )

    get api_pitch_data_path, params: { game_date_start: "2026-04-28", game_date_end: "2026-04-29" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "filters")).to include(
      "game_date_start" => "2026-04-28",
      "game_date_end" => "2026-04-29"
    )
    expect(json_body.fetch("data").map { |row| row.fetch("id") }).to eq([second_in_range.id, first_in_range.id])
  end

  it "imports pitch data from an uploaded csv" do
    csv_file = Tempfile.new(["pitch-data", ".csv"])
    csv_file.write(<<~CSV)
      game_pk,at_bat_number,pitch_number,game_date,pitch_type,description
      777,1,1,2026-04-01,FF,Called Strike
    CSV
    csv_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, "text/csv", original_filename: "pitch-data.csv")

    expect do
      post import_api_pitch_data_path, params: { file: uploaded_file }
    end.to change(PitchDatum, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json_body.fetch("message")).to eq("Imported 1 pitch data rows")
    expect(json_body.dig("data", "imported_count")).to eq(1)
    expect(PitchDatum.last.description).to eq("Called Strike")
  ensure
    csv_file.close!
  end

  it "rejects pitch data imports when an admin token is configured but missing" do
    csv_file = Tempfile.new(["pitch-data", ".csv"])
    csv_file.write(<<~CSV)
      game_pk,at_bat_number,pitch_number,game_date,pitch_type,description
      777,1,1,2026-04-01,FF,Called Strike
    CSV
    csv_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, "text/csv", original_filename: "pitch-data.csv")

    expect do
      with_admin_api_token("test-admin-token") do
        post import_api_pitch_data_path, params: { file: uploaded_file }
      end
    end.not_to change(PitchDatum, :count)

    expect(response).to have_http_status(:unauthorized)
    expect(json_body["message"]).to eq("Admin API token is required")
  ensure
    csv_file.close!
  end

  it "accepts pitch data downloads with a valid x-admin-token header" do
    allow(PitchDataDownloader).to receive(:call).and_return(
      {
        success: true,
        message: "Downloaded 0 pitch data rows from Baseball Savant",
        data: {
          csv_data: "game_pk,at_bat_number,pitch_number,game_date\n",
          row_count: 0,
          start_date: "2026-04-01",
          end_date: "2026-04-01",
          game_types: ["R"],
          chunk_days: 7
        }
      }
    )

    with_admin_api_token("test-admin-token") do
      post download_api_pitch_data_path,
           params: { start_date: "2026-04-01", end_date: "2026-04-01" },
           headers: { "X-Admin-Token" => "test-admin-token" },
           as: :json
    end

    expect(response).to have_http_status(:unprocessable_content)
    expect(response).not_to have_http_status(:unauthorized)
  end

  it "returns an error when import is missing a file" do
    post import_api_pitch_data_path

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("errors")).to include("CSV file is required")
  end

  it "returns importer failures from the upload endpoint" do
    csv_file = Tempfile.new(["pitch-data-invalid", ".csv"])
    csv_file.write(<<~CSV)
      game_pk,pitch_type
      777,FF
    CSV
    csv_file.rewind

    uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, "text/csv", original_filename: "pitch-data-invalid.csv")

    post import_api_pitch_data_path, params: { file: uploaded_file }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to include("Missing required columns")
  ensure
    csv_file.close!
  end

  it "downloads Baseball Savant pitch data and imports it through the API" do
    csv_data = <<~CSV
      source_start_date,source_end_date,fetched_at_utc,game_date,game_pk,game_type,at_bat_number,pitch_number,pitcher,player_name,batter,pitch_type,description
      2026-04-01,2026-04-01,2026-04-02T00:00:00Z,2026-04-01,777,R,1,1,9001,Pitcher One,8001,FF,called_strike
    CSV

    allow(PitchDataDownloader).to receive(:call).and_return(
      {
        success: true,
        message: "Downloaded 1 pitch data rows from Baseball Savant",
        data: {
          csv_data: csv_data,
          row_count: 1,
          start_date: "2026-04-01",
          end_date: "2026-04-01",
          game_types: ["R"],
          chunk_days: 7
        }
      }
    )

    expect do
      post download_api_pitch_data_path,
           params: {
             start_date: "2026-04-01",
             end_date: "2026-04-01",
             game_types: "R",
             chunk_days: 7
           },
           as: :json
    end.to change(PitchDatum, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(PitchDataDownloader).to have_received(:call).with(
      start_date: "2026-04-01",
      end_date: "2026-04-01",
      game_types: "R",
      chunk_days: 7
    )
    expect(json_body.dig("data", "downloaded_count")).to eq(1)
    expect(json_body.dig("data", "downloaded_start_date")).to eq("2026-04-01")
    expect(json_body.dig("data", "downloaded_game_types")).to eq(["R"])
    expect(PitchDatum.last.pitch_type).to eq("FF")
  end

  it "returns downloader failures from the pitch data download endpoint" do
    allow(PitchDataDownloader).to receive(:call).and_return(
      { success: false, message: "No pitch data rows returned from Baseball Savant", data: {} }
    )

    post download_api_pitch_data_path,
         params: { start_date: "2026-04-01", end_date: "2026-04-01" },
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body["message"]).to eq("No pitch data rows returned from Baseball Savant")
  end

  it "does not wrap pitch data download json params into an unpermitted pitch_datum key" do
    previous_setting = ActionController::Parameters.action_on_unpermitted_parameters
    ActionController::Parameters.action_on_unpermitted_parameters = :raise

    allow(PitchDataDownloader).to receive(:call).and_return(
      { success: false, message: "No pitch data rows returned from Baseball Savant", data: {} }
    )

    expect do
      post download_api_pitch_data_path,
           params: {
             start_date: "2026-05-20",
             end_date: "2026-05-31",
             game_types: "R",
             chunk_days: 7
           },
           as: :json
    end.not_to raise_error

    expect(response).to have_http_status(:unprocessable_content)
    expect(PitchDataDownloader).to have_received(:call).with(
      start_date: "2026-05-20",
      end_date: "2026-05-31",
      game_types: "R",
      chunk_days: 7
    )
  ensure
    ActionController::Parameters.action_on_unpermitted_parameters = previous_setting
  end
end
