class MlbRosterStatus
  CODE_MAP = {
    "A" => "active",
    "D7" => "injured_7_day",
    "D10" => "injured_10_day",
    "D15" => "injured_15_day",
    "D60" => "injured_60_day",
    "BRV" => "bereavement",
    "PAT" => "paternity",
    "FME" => "family_medical_emergency",
    "RST" => "restricted",
    "SUS" => "suspended",
    "RM" => "minors",
    "MIN" => "minors",
    "DFA" => "designated_for_assignment"
  }.freeze

  STATUS_PRIORITY = {
    "active" => 0,
    "bereavement" => 1,
    "paternity" => 1,
    "family_medical_emergency" => 1,
    "injured_7_day" => 2,
    "injured_10_day" => 2,
    "injured_15_day" => 2,
    "injured_60_day" => 2,
    "restricted" => 3,
    "suspended" => 3,
    "minors" => 4,
    "designated_for_assignment" => 5
  }.freeze

  def self.normalize(code:, description: nil)
    normalized_code = code.to_s.strip.upcase
    return CODE_MAP.fetch(normalized_code) if CODE_MAP.key?(normalized_code)

    description.to_s.parameterize(separator: "_").presence || "unknown_#{normalized_code.downcase.presence || 'status'}"
  end

  def self.priority(status)
    STATUS_PRIORITY.fetch(status.to_s, 99)
  end

  def self.injured?(status)
    status.to_s.start_with?("injured_")
  end
end
