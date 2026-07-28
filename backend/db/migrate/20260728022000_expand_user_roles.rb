class ExpandUserRoles < ActiveRecord::Migration[7.1]
  def change
    remove_check_constraint :users, name: "users_valid_role"
    add_check_constraint :users,
      "role::text = ANY (ARRAY['admin'::character varying, 'administrator'::character varying, 'analyst'::character varying, 'coach'::character varying, 'scout'::character varying, 'editor'::character varying, 'viewer'::character varying]::text[])",
      name: "users_valid_role"
  end
end
