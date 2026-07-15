require "json"

class NormalizeMlbScheduleGameTypes < ActiveRecord::Migration[7.1]
  def up
    schedule_model = Class.new(ActiveRecord::Base) do
      self.table_name = "schedules"
    end
    game_model = Class.new(ActiveRecord::Base) do
      self.table_name = "games"
    end

    schedule_model.where("source_key LIKE ?", "mlb:schedule:%").find_each do |schedule|
      prefix, separator, suffix = schedule.source_key.rpartition(":")
      next if separator.blank? || !suffix.start_with?("[")

      game_types = JSON.parse(suffix)
      next unless game_types.is_a?(Array)

      normalized_game_types = game_types.map { |value| value.to_s.strip.upcase }.reject(&:blank?).uniq.sort
      next if normalized_game_types.empty?

      normalized_type = normalized_game_types.join(",")
      normalized_key = "#{prefix}:#{normalized_type}"
      existing_schedule = schedule_model.find_by(source_key: normalized_key)

      if existing_schedule && existing_schedule.id != schedule.id
        game_model.where(schedule_id: schedule.id).update_all(schedule_id: existing_schedule.id)
        schedule.destroy!
      else
        schedule.update!(source_key: normalized_key, schedule_type: normalized_type)
      end
    rescue JSON::ParserError
      next
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Legacy JSON-formatted game types cannot be reconstructed safely"
  end
end
