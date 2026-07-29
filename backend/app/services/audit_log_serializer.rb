class AuditLogSerializer
  def self.call(log)
    {
      id: log.id,
      action: log.action,
      auditable_type: log.auditable_type,
      auditable_id: log.auditable_id,
      changes: log.change_set,
      metadata: log.metadata,
      created_at: log.created_at,
      user: log.user && {
        id: log.user.id,
        name: log.user.name,
        email: log.user.email,
        role: log.user.role
      }
    }
  end
end
