class CreatePositionsAndPlayerPositions < ActiveRecord::Migration[7.1]
  POSITION_TYPES = %w[pitcher catcher infielder outfielder designated_hitter two_way other].freeze

  def change
    create_table :positions do |t|
      t.string :mlb_code, null: false
      t.string :abbreviation, null: false
      t.string :name, null: false
      t.string :position_type, null: false
      t.integer :sort_order, null: false

      t.timestamps
    end

    add_index :positions, :mlb_code, unique: true
    add_index :positions, :abbreviation, unique: true
    add_index :positions, :sort_order
    add_check_constraint :positions, "sort_order > 0", name: "positions_positive_sort_order"
    add_check_constraint :positions,
      "position_type IN (#{POSITION_TYPES.map { |value| connection.quote(value) }.join(', ')})",
      name: "positions_valid_position_type"

    create_table :player_positions do |t|
      t.references :player, null: false, foreign_key: true
      t.references :position, null: false, foreign_key: true
      t.boolean :is_primary, null: false, default: false
      t.integer :season
      t.string :source_name, null: false
      t.datetime :last_synced_at, null: false

      t.timestamps
    end

    add_check_constraint :player_positions,
      "season IS NULL OR season > 1800",
      name: "player_positions_valid_season"

    add_index :player_positions,
      [:player_id, :position_id],
      unique: true,
      where: "season IS NULL",
      name: "index_player_positions_unique_current"

    add_index :player_positions,
      [:player_id, :position_id, :season],
      unique: true,
      where: "season IS NOT NULL",
      name: "index_player_positions_unique_season"

    add_index :player_positions,
      :player_id,
      unique: true,
      where: "season IS NULL AND is_primary = TRUE",
      name: "index_player_positions_one_current_primary"

    add_index :player_positions,
      [:player_id, :season],
      unique: true,
      where: "season IS NOT NULL AND is_primary = TRUE",
      name: "index_player_positions_one_season_primary"
  end
end
