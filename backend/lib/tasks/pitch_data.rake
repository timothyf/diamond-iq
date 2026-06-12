namespace :pitch_data do
  def resolve_pitch_data_path(explicit_path = nil)
    candidate_paths = [
      explicit_path,
      ENV["PITCH_DATA_CSV"],
      Rails.root.join("..", "data", "mlb_pitch_data_april_2026.csv").to_s,
      Rails.root.join("data", "mlb_pitch_data_april_2026.csv").to_s
    ].compact

    candidate_paths.find { |path| File.file?(path) }
  end

  def import_pitch_data_from!(file_path)
    result = PitchDataImporter.call(file_path: file_path, source_name: file_path)

    puts result[:message]

    if result[:success]
      data = result[:data] || {}
      puts "Imported pitch rows: #{data[:imported_count]}"
      puts "Skipped rows: #{data[:skipped_count]}"
      puts "Duplicate rows collapsed: #{data[:duplicate_count]}"
    else
      Array(result.dig(:data, :errors)).each do |error|
        puts "Row #{error[:row_number]}: #{error[:error]}"
      end

      abort "Pitch data import failed"
    end
  end

  desc "Import pitch data from CSV. Usage: bin/rails 'pitch_data:import[path/to/file.csv]' or PITCH_DATA_CSV=/path/file.csv bin/rails pitch_data:import"
  task :import, [:file_path] => :environment do |_task, args|
    file_path = resolve_pitch_data_path(args[:file_path])

    if file_path.blank?
      abort <<~MESSAGE
        Unable to find a pitch data CSV file.
        Try:
          bin/rails 'pitch_data:import[/absolute/path/to/file.csv]'
          PITCH_DATA_CSV=/absolute/path/to/file.csv bin/rails pitch_data:import
      MESSAGE
    end

    puts "Using pitch CSV source: #{file_path}"
    import_pitch_data_from!(file_path)
  end
end
