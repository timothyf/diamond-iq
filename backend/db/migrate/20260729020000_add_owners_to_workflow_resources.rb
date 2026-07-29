class AddOwnersToWorkflowResources < ActiveRecord::Migration[7.1]
  def change
    add_reference :lineup_scenarios, :owner, foreign_key: { to_table: :users }, null: true
    add_reference :opponent_reports, :owner, foreign_key: { to_table: :users }, null: true
  end
end
