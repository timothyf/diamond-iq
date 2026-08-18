class AddDrsStatType < ActiveRecord::Migration[7.1]
  def up
    timestamp = connection.quote(Time.current)
    execute <<~SQL.squish
      INSERT INTO stat_types (name, label, category, created_at, updated_at)
      VALUES ('DRS', 'DRS', 'batting', #{timestamp}, #{timestamp})
      ON CONFLICT (name, category) DO NOTHING
    SQL
  end

  def down
    execute <<~SQL.squish
      DELETE FROM stat_types
      WHERE category = 'batting' AND name = 'DRS'
    SQL
  end
end
