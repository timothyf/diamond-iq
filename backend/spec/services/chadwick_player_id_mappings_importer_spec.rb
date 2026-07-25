require "rails_helper"
require "tmpdir"

RSpec.describe ChadwickPlayerIdMappingsImporter do
  it "imports MLB mappings from every people file and updates them idempotently" do
    Dir.mktmpdir("chadwick-register-spec") do |directory|
      root = Pathname(directory)
      data_directory = root.join("chadwick-register", "data")
      data_directory.mkpath

      described_class::PEOPLE_FILES.each do |entry|
        path = root.join(entry)
        path.dirname.mkpath
        path.write("key_person,key_uuid,key_mlbam,key_retro,key_bbref,key_bbref_minors,key_fangraphs,key_npb,key_sr_nfl,key_sr_nba,key_sr_nhl,key_wikidata\n")
      end
      root.join(described_class::PEOPLE_FILES.first).write(<<~CSV)
        key_person,key_uuid,key_mlbam,key_retro,key_bbref,key_bbref_minors,key_fangraphs,key_npb,key_sr_nfl,key_sr_nba,key_sr_nhl,key_wikidata
        abc12345,abc12345-1234-4567-890a-123456789012,682985,greenr001,greenri03,greene000ril,25976,,,,,Q123
        def67890,def67890-1234-4567-890a-123456789012,,,,minor001,,123,,,,
      CSV
      zip_path = root.join("register.zip")
      _output, error, status = Open3.capture3("zip", "-q", "-r", zip_path.to_s, "chadwick-register", chdir: root.to_s)
      raise error unless status.success?

      first = described_class.call(zip_path: zip_path, imported_at: Time.zone.parse("2026-07-25 12:00:00"))
      mapping = PlayerIdMapping.find_by!(mlb_id: 682_985)

      expect(first).to include(success: true)
      expect(first.dig(:data, :imported_count)).to eq(1)
      expect(first.dig(:data, :skipped_count)).to eq(1)
      expect(mapping).to have_attributes(
        chadwick_id: "abc12345",
        retrosheet_id: "greenr001",
        baseball_reference_id: "greenri03",
        baseball_reference_minors_id: "greene000ril",
        fangraphs_id: "25976",
        wikidata_id: "Q123"
      )

      expect { described_class.call(zip_path: zip_path) }.not_to change(PlayerIdMapping, :count)
    end
  end

  it "returns a useful failure for a missing archive" do
    result = described_class.call(zip_path: "/missing/chadwick-register.zip")

    expect(result).to include(success: false)
    expect(result[:message]).to include("was not found")
  end
end
