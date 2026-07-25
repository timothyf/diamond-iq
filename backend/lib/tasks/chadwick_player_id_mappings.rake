namespace :chadwick_player_id_mappings do
  desc "Import MLB player cross-site identifiers from a Chadwick Register zip archive"
  task import: :environment do
    zip_path = ENV["ZIP_PATH"].presence || Rails.root.join("..", "..", "chadwick-register.zip")
    result = ChadwickPlayerIdMappingsImporter.call(zip_path: zip_path)

    abort result[:message] unless result[:success]

    puts result[:message]
    puts "Skipped non-MLB identities: #{result.dig(:data, :skipped_count)}"
  end
end
