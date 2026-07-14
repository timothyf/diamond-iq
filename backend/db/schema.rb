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

ActiveRecord::Schema[7.1].define(version: 2026_07_13_002000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "games", force: :cascade do |t|
    t.bigint "schedule_id", null: false
    t.bigint "mlb_id", null: false
    t.date "official_date", null: false
    t.datetime "scheduled_at"
    t.string "game_type", null: false
    t.string "status", null: false
    t.string "detailed_status"
    t.bigint "home_team_id", null: false
    t.bigint "away_team_id", null: false
    t.bigint "home_probable_pitcher_id"
    t.bigint "away_probable_pitcher_id"
    t.string "venue_name"
    t.integer "game_number"
    t.string "doubleheader"
    t.integer "home_score"
    t.integer "away_score"
    t.string "source_name", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["away_probable_pitcher_id"], name: "index_games_on_away_probable_pitcher_id"
    t.index ["away_team_id", "official_date"], name: "index_games_on_away_team_id_and_official_date"
    t.index ["away_team_id"], name: "index_games_on_away_team_id"
    t.index ["home_probable_pitcher_id"], name: "index_games_on_home_probable_pitcher_id"
    t.index ["home_team_id", "official_date"], name: "index_games_on_home_team_id_and_official_date"
    t.index ["home_team_id"], name: "index_games_on_home_team_id"
    t.index ["mlb_id"], name: "index_games_on_mlb_id", unique: true
    t.index ["official_date", "status"], name: "index_games_on_official_date_and_status"
    t.index ["schedule_id"], name: "index_games_on_schedule_id"
    t.check_constraint "away_score IS NULL OR away_score >= 0", name: "games_nonnegative_away_score"
    t.check_constraint "home_score IS NULL OR home_score >= 0", name: "games_nonnegative_home_score"
    t.check_constraint "home_team_id <> away_team_id", name: "games_distinct_teams"
  end

  create_table "pitch_data", force: :cascade do |t|
    t.date "source_start_date"
    t.date "source_end_date"
    t.datetime "fetched_at_utc"
    t.date "game_date"
    t.bigint "game_pk", null: false
    t.string "game_type"
    t.string "home_team"
    t.string "away_team"
    t.integer "inning"
    t.string "inning_topbot"
    t.integer "at_bat_number", null: false
    t.integer "pitch_number", null: false
    t.bigint "pitcher"
    t.string "player_name"
    t.bigint "batter"
    t.string "stand"
    t.string "p_throws"
    t.string "pitch_type"
    t.string "pitch_name"
    t.string "description"
    t.string "events"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "balls"
    t.integer "strikes"
    t.integer "outs_when_up"
    t.float "release_speed"
    t.float "release_spin_rate"
    t.float "release_extension"
    t.float "release_pos_x"
    t.float "release_pos_y"
    t.float "release_pos_z"
    t.float "pfx_x"
    t.float "pfx_z"
    t.float "plate_x"
    t.float "plate_z"
    t.integer "zone"
    t.float "launch_speed"
    t.float "launch_angle"
    t.float "hit_distance_sc"
    t.string "bb_type"
    t.float "estimated_ba_using_speedangle"
    t.float "estimated_woba_using_speedangle"
    t.float "woba_value"
    t.float "delta_run_exp"
    t.integer "bat_score"
    t.integer "fld_score"
    t.integer "post_bat_score"
    t.integer "post_fld_score"
    t.string "sv_id"
    t.float "age_bat"
    t.float "age_bat_legacy"
    t.float "age_pit"
    t.float "age_pit_legacy"
    t.float "api_break_x_arm"
    t.float "api_break_x_batter_in"
    t.float "api_break_z_with_gravity"
    t.float "arm_angle"
    t.float "attack_angle"
    t.float "attack_direction"
    t.integer "away_score"
    t.float "ax"
    t.float "ay"
    t.float "az"
    t.float "babip_value"
    t.integer "bat_score_diff"
    t.float "bat_speed"
    t.float "bat_win_exp"
    t.integer "batter_days_since_prev_game"
    t.integer "batter_days_until_next_game"
    t.float "break_angle_deprecated"
    t.float "break_length_deprecated"
    t.float "delta_home_win_exp"
    t.float "delta_pitcher_run_exp"
    t.string "des"
    t.float "effective_speed"
    t.float "estimated_slg_using_speedangle"
    t.bigint "fielder_2"
    t.bigint "fielder_3"
    t.bigint "fielder_4"
    t.bigint "fielder_5"
    t.bigint "fielder_6"
    t.bigint "fielder_7"
    t.bigint "fielder_8"
    t.bigint "fielder_9"
    t.integer "game_year"
    t.float "hc_x"
    t.float "hc_y"
    t.integer "hit_location"
    t.integer "home_score"
    t.integer "home_score_diff"
    t.float "home_win_exp"
    t.float "hyper_speed"
    t.string "if_fielding_alignment"
    t.float "intercept_ball_minus_batter_pos_x_inches"
    t.float "intercept_ball_minus_batter_pos_y_inches"
    t.float "iso_value"
    t.integer "launch_speed_angle"
    t.float "miss_distance"
    t.integer "n_priorpa_thisgame_player_at_bat"
    t.integer "n_thruorder_pitcher"
    t.string "of_fielding_alignment"
    t.bigint "on_1b"
    t.bigint "on_2b"
    t.bigint "on_3b"
    t.integer "pitcher_days_since_prev_game"
    t.integer "pitcher_days_until_next_game"
    t.integer "post_away_score"
    t.integer "post_home_score"
    t.float "spin_axis"
    t.float "spin_dir"
    t.float "spin_rate_deprecated"
    t.float "swing_length"
    t.float "swing_path_tilt"
    t.float "sz_bot"
    t.float "sz_top"
    t.string "tfs_deprecated"
    t.string "tfs_zulu_deprecated"
    t.string "type"
    t.bigint "umpire"
    t.float "vx0"
    t.float "vy0"
    t.float "vz0"
    t.integer "woba_denom"
    t.index ["batter"], name: "index_pitch_data_on_batter"
    t.index ["game_date"], name: "index_pitch_data_on_game_date"
    t.index ["game_pk", "at_bat_number", "pitch_number"], name: "idx_pitch_data_unique_pitch", unique: true
    t.index ["pitch_type"], name: "index_pitch_data_on_pitch_type"
    t.index ["pitcher"], name: "index_pitch_data_on_pitcher"
  end

  create_table "player_season_stats", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "stat_type_id", null: false
    t.integer "season", null: false
    t.decimal "value", precision: 12, scale: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "team_id"
    t.index ["player_id", "stat_type_id", "season"], name: "idx_on_player_id_stat_type_id_season_58662b691e", unique: true
    t.index ["player_id"], name: "index_player_season_stats_on_player_id"
    t.index ["stat_type_id"], name: "index_player_season_stats_on_stat_type_id"
    t.index ["team_id"], name: "index_player_season_stats_on_team_id"
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

  create_table "roster_players", force: :cascade do |t|
    t.bigint "roster_id", null: false
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_roster_players_on_player_id"
    t.index ["roster_id", "player_id"], name: "index_roster_players_on_roster_id_and_player_id", unique: true
    t.index ["roster_id"], name: "index_roster_players_on_roster_id"
  end

  create_table "rosters", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.integer "season", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "season"], name: "index_rosters_on_team_id_and_season", unique: true
    t.index ["team_id"], name: "index_rosters_on_team_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.integer "season", null: false
    t.string "schedule_type", default: "regular", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "source_name", null: false
    t.string "source_key", null: false
    t.string "source_url"
    t.datetime "last_synced_at", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season", "schedule_type"], name: "index_schedules_on_season_and_schedule_type"
    t.index ["source_key"], name: "index_schedules_on_source_key", unique: true
    t.check_constraint "end_date >= start_date", name: "schedules_valid_date_range"
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

  add_foreign_key "games", "players", column: "away_probable_pitcher_id"
  add_foreign_key "games", "players", column: "home_probable_pitcher_id"
  add_foreign_key "games", "schedules"
  add_foreign_key "games", "teams", column: "away_team_id"
  add_foreign_key "games", "teams", column: "home_team_id"
  add_foreign_key "player_season_stats", "players"
  add_foreign_key "player_season_stats", "stat_types"
  add_foreign_key "player_season_stats", "teams"
  add_foreign_key "players", "teams"
  add_foreign_key "roster_players", "players"
  add_foreign_key "roster_players", "rosters"
  add_foreign_key "rosters", "teams"
end
