class AdminTaskRun < ApplicationRecord
  belongs_to :initiated_by, class_name: "User", optional: true
  has_one :admin_task_upload, dependent: :destroy
  STATUSES = %w[queued running completed failed cancelled].freeze
  ACTIVE_STATUSES = %w[queued running].freeze
  TERMINAL_STATUSES = %w[completed failed cancelled].freeze

  validates :task_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :total_items, :completed_items, :failed_items,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :estimated_duration_seconds,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :recent_first, -> { order(created_at: :desc) }

  def active?
    status.in?(ACTIVE_STATUSES)
  end

  def terminal?
    status.in?(TERMINAL_STATUSES)
  end

  def cancel_requested?
    cancel_requested_at.present?
  end

  def processed_items
    completed_items + failed_items
  end

  def progress_percentage
    return 100.0 if status == "completed"
    return 0.0 if total_items.zero?

    [ (processed_items.to_f / total_items * 100).round(1), 100.0 ].min
  end

  def elapsed_seconds
    return unless started_at

    ((finished_at || Time.current) - started_at).round
  end

  def estimated_remaining_seconds
    return unless active? && processed_items < total_items

    # Keep the estimate stable while an item is in flight. The baseline is
    # recalculated when an item completes, then simply counts down until the
    # next completion moves the anchor.
    anchor_at = remaining_time_anchor_at || (processed_items.positive? ? updated_at : started_at)
    return estimated_duration_seconds if anchor_at.nil?

    baseline_seconds = if processed_items.positive?
      return unless started_at

      elapsed_at_anchor = anchor_at - started_at
      elapsed_at_anchor.to_f / processed_items * (total_items - processed_items)
    else
      estimated_duration_seconds
    end
    return unless baseline_seconds

    [ baseline_seconds - (Time.current - anchor_at), 0 ].max.round
  end
end
