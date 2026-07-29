class ExpandAcquisitionReviewWorkflow < ActiveRecord::Migration[7.1]
  REVIEW_STATUSES = %w[
    initial_review
    analyst_review
    scout_review
    medical_review
    discuss_internally
    contact_club_or_agent
    no_longer_pursuing
  ].freeze

  def up
    add_reference :watchlist_entries, :candidate_owner, foreign_key: { to_table: :users }, index: true
    add_column :watchlist_entries, :acquisition_rationale, :text
    add_column :watchlist_entries, :estimated_cost, :decimal, precision: 12, scale: 2
    add_column :watchlist_entries, :availability, :string, null: false, default: "unknown"
    add_column :watchlist_entries, :concerns, :text
    add_column :watchlist_entries, :review_status, :string, null: false, default: "initial_review"

    execute <<~SQL
      UPDATE watchlist_entries
      SET review_status = CASE status
        WHEN 'scouting' THEN 'initial_review'
        WHEN 'active' THEN 'analyst_review'
        WHEN 'paused' THEN 'discuss_internally'
        WHEN 'closed' THEN 'no_longer_pursuing'
        ELSE 'initial_review'
      END
    SQL

    add_check_constraint :watchlist_entries,
      "review_status IN ('#{REVIEW_STATUSES.join("', '")}')",
      name: "watchlist_entries_valid_review_status"
    add_check_constraint :watchlist_entries,
      "estimated_cost IS NULL OR estimated_cost >= 0",
      name: "watchlist_entries_estimated_cost_nonnegative"
  end

  def down
    remove_check_constraint :watchlist_entries, name: "watchlist_entries_valid_review_status"
    remove_check_constraint :watchlist_entries, name: "watchlist_entries_estimated_cost_nonnegative"
    remove_reference :watchlist_entries, :candidate_owner, foreign_key: true
    remove_columns :watchlist_entries, :acquisition_rationale, :estimated_cost, :availability, :concerns, :review_status
  end
end
