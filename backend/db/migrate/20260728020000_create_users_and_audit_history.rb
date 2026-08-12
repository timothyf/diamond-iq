class CreateUsersAndAuditHistory < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :role, null: false, default: "viewer"
      t.string :password_salt
      t.string :password_digest
      t.string :auth_token_digest
      t.datetime :last_signed_in_at
      t.datetime :disabled_at
      t.boolean :system_account, null: false, default: false
      t.timestamps
    end
    add_index :users, "lower(email)", unique: true, name: "idx_users_lower_email"
    add_index :users, :auth_token_digest, unique: true
    add_check_constraint :users, "role IN ('admin', 'editor', 'viewer')", name: "users_valid_role"

    create_table :audit_logs do |t|
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.jsonb :changes, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :audit_logs, [ :auditable_type, :auditable_id, :created_at ], name: "idx_audit_logs_auditable_history"
    add_index :audit_logs, [ :user_id, :created_at ], name: "idx_audit_logs_user_history"

    add_reference :watchlists, :owner, foreign_key: { to_table: :users }
    add_reference :need_profiles, :owner, foreign_key: { to_table: :users }

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          INSERT INTO users (email, name, role, system_account, created_at, updated_at)
          VALUES ('system@ninelens.local', 'NineLens System', 'admin', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
        execute <<~SQL.squish
          UPDATE watchlists
          SET owner_id = (SELECT id FROM users WHERE system_account = TRUE)
          WHERE owner_id IS NULL
        SQL
        execute <<~SQL.squish
          UPDATE need_profiles
          SET owner_id = (SELECT id FROM users WHERE system_account = TRUE)
          WHERE owner_id IS NULL
        SQL
      end
    end
  end
end
