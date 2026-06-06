# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_06_06_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "player_season_stats", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "stat_type_id", null: false
    t.integer "season", null: false
    t.decimal "value", precision: 12, scale: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "stat_type_id", "season"], name: "idx_on_player_id_stat_type_id_season_58662b691e", unique: true
    t.index ["player_id"], name: "index_player_season_stats_on_player_id"
    t.index ["stat_type_id"], name: "index_player_season_stats_on_stat_type_id"
  end

  create_table "player_stats", force: :cascade do |t|
    t.string "player_id", null: false
    t.string "source_url", null: false
    t.integer "row_number", null: false
    t.jsonb "stats_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "source_url", "row_number"], name: "index_player_stats_on_player_id_and_source_url_and_row_number", unique: true
    t.index ["player_id", "source_url"], name: "index_player_stats_on_player_id_and_source_url"
  end

  create_table "players", force: :cascade do |t|
    t.integer "mlb_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mlb_id"], name: "index_players_on_mlb_id", unique: true
    t.index ["team_id"], name: "index_players_on_team_id"
  end

  create_table "stat_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "label", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "category"], name: "index_stat_types_on_name_and_category", unique: true
  end

  create_table "teams", force: :cascade do |t|
    t.integer "mlb_id", null: false
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.string "team_name", null: false
    t.string "location_name", null: false
    t.string "short_name", null: false
    t.string "team_code", null: false
    t.string "file_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mlb_id"], name: "index_teams_on_mlb_id", unique: true
  end

  add_foreign_key "player_season_stats", "players"
  add_foreign_key "player_season_stats", "stat_types"
  add_foreign_key "players", "teams"
end
