class BackfillAndRequireWorkflowOwners < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      UPDATE lineup_scenarios
      SET owner_id = (SELECT id FROM users WHERE system_account = TRUE ORDER BY id LIMIT 1)
      WHERE owner_id IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE opponent_reports
      SET owner_id = (SELECT id FROM users WHERE system_account = TRUE ORDER BY id LIMIT 1)
      WHERE owner_id IS NULL
    SQL

    change_column_null :lineup_scenarios, :owner_id, false
    change_column_null :opponent_reports, :owner_id, false
  end

  def down
    change_column_null :lineup_scenarios, :owner_id, true
    change_column_null :opponent_reports, :owner_id, true
  end
end
