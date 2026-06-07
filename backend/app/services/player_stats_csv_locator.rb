class PlayerStatsCsvLocator
  PREFERRED_OUTPUT_DIRECTORY = Pathname(Dir.home).join("Projects", "mlb-stats-downloader", "otuput")
  SEARCH_GLOBS = [
    "*batter*stats*.csv",
    "*pitcher*stats*.csv",
    "*player*season*stats*.csv",
    "*season*stats*.csv",
    "*player*stats*.csv",
    "*pitch*stats*.csv"
  ].freeze
  REQUIRED_HEADERS = %w[season playerId stat_type].freeze

  def self.all(search_roots: nil)
    new(search_roots: search_roots).all
  end

  def self.call(search_roots: nil)
    new(search_roots: search_roots).call
  end

  def self.preferred_output_directory
    PREFERRED_OUTPUT_DIRECTORY
  end

  def initialize(search_roots: nil)
    @search_roots = Array(search_roots.presence || default_search_roots).compact.map { |root| Pathname(root) }.uniq
  end

  def call
    all.first
  end

  def all
    preferred_candidates(valid_candidate_files).map(&:to_s)
  end

  private

  attr_reader :search_roots

  def default_search_roots
    [
      self.class.preferred_output_directory,
      Rails.root.join("tmp", "imports"),
      Rails.root.join("db", "imports"),
      Pathname(Dir.home).join("Downloads"),
      Pathname(Dir.home).join("Desktop"),
      Pathname(Dir.home).join("Projects")
    ]
  end

  def candidate_files
    search_roots.flat_map do |root|
      next [] unless root.exist? && root.directory?

      SEARCH_GLOBS.flat_map do |glob|
        Dir.glob(root.join("**", glob).to_s, File::FNM_CASEFOLD).map { |path| Pathname(path) }
      end
    end.uniq
  end

  def valid_candidate_files
    candidate_files.select { |path| valid_stats_csv?(path) }
  end

  def preferred_candidates(paths)
    grouped_paths = paths.group_by { |path| csv_family(path) }

    preferred = []
    preferred.concat(select_family_candidates(grouped_paths.delete(:batter)))
    preferred.concat(select_family_candidates(grouped_paths.delete(:pitcher)))
    grouped_paths.values.flatten.each do |path|
      preferred << path unless preferred.include?(path)
    end

    preferred
  end

  def select_family_candidates(paths)
    return [] if paths.blank?

    present_file = paths.find { |path| path.basename.to_s.downcase.include?("present") }
    return [present_file] if present_file

    [paths.max_by { |path| File.mtime(path) }]
  end

  def csv_family(path)
    basename = path.basename.to_s.downcase
    return :batter if basename.include?("batter")
    return :pitcher if basename.include?("pitcher")

    :other
  end

  def valid_stats_csv?(path)
    first_line = File.open(path, &:readline)
    normalized_headers = first_line.split(",").map { |header| header.to_s.strip.delete_prefix("\uFEFF") }

    REQUIRED_HEADERS.all? { |required_header| normalized_headers.include?(required_header) }
  rescue EOFError, Errno::ENOENT, Errno::EISDIR, ArgumentError
    false
  end
end
