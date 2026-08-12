class AddDefensiveStatTypes < ActiveRecord::Migration[7.1]
  STAT_TYPES = [
    [ "OAA", "OAA" ],
    [ "fieldingPercentage", "Fldg%" ]
  ].freeze

  def up
    timestamp = connection.quote(Time.current)
    values = STAT_TYPES.map do |name, label|
      "(#{connection.quote(name)}, #{connection.quote(label)}, 'batting', #{timestamp}, #{timestamp})"
    end

    execute <<~SQL.squish
      INSERT INTO stat_types (name, label, category, created_at, updated_at)
      VALUES #{values.join(', ')}
      ON CONFLICT (name, category) DO NOTHING
    SQL
  end

  def down
    execute <<~SQL.squish
      DELETE FROM stat_types
      WHERE category = 'batting' AND name IN ('OAA', 'fieldingPercentage')
    SQL
  end
end
