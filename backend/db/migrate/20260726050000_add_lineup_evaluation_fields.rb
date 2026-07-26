class AddLineupEvaluationFields < ActiveRecord::Migration[7.1]
  def change
    add_column :lineup_scenarios, :evaluation_inputs, :jsonb, null: false, default: {}
    add_column :lineup_scenarios, :score_breakdown, :jsonb, null: false, default: {}
    add_column :lineup_scenarios, :total_score, :decimal, precision: 6, scale: 2
  end
end
