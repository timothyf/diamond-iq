class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :action, :auditable_type, :auditable_id, presence: true

  def self.record!(user:, action:, record:, changes: {}, metadata: {})
    create!(
      user: user,
      action: action,
      auditable_type: record.class.base_class.name,
      auditable_id: record.id,
      change_set: changes.to_h,
      metadata: metadata.to_h
    )
  end
end
