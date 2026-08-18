class CreateTrades < ActiveRecord::Migration[7.1]
  def change
    create_table :trades do |t|
      t.bigint :mlb_transaction_id, null: false
      t.date :occurred_on, null: false
      t.text :description, null: false
      t.string :source_name, null: false
      t.string :source_url
      t.datetime :last_synced_at, null: false
      t.jsonb :raw_data, null: false, default: {}
      t.timestamps
    end
    add_index :trades, :mlb_transaction_id, unique: true
    add_index :trades, :occurred_on

    create_table :trade_participants do |t|
      t.references :trade, null: false, foreign_key: true
      t.references :player, null: true, foreign_key: true
      t.bigint :player_mlb_id, null: false
      t.string :player_name, null: false
      t.references :from_team, null: true, foreign_key: { to_table: :teams }
      t.references :to_team, null: true, foreign_key: { to_table: :teams }
      t.integer :from_team_mlb_id
      t.string :from_team_name
      t.integer :to_team_mlb_id
      t.string :to_team_name
      t.jsonb :raw_data, null: false, default: {}
      t.timestamps
    end
    add_index :trade_participants, [ :trade_id, :player_mlb_id ], unique: true
    add_index :trade_participants, :player_mlb_id
  end
end
