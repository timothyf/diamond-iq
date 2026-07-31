class AddLineupDecisionSupport < ActiveRecord::Migration[7.1]
  def change
    add_column :lineup_scenarios, :decision_constraints, :jsonb, null: false, default: {}
    add_column :lineup_scenarios, :decision_weights, :jsonb, null: false, default: {}
    add_column :lineup_scenarios, :recommendation_data, :jsonb, null: false, default: {}
  end
end
