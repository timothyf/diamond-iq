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
    return unless active? && started_at && processed_items.positive? && processed_items < total_items

    (elapsed_seconds.to_f / processed_items * (total_items - processed_items)).round
  end
end
