class CreateAdminTaskUploads < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_task_uploads do |t|
      t.references :admin_task_run, null: false, foreign_key: true, index: { unique: true }
      t.string :original_filename, null: false
      t.string :content_type
      t.bigint :byte_size, null: false
      t.string :checksum, null: false
      t.binary :contents, null: false

      t.timestamps
    end
  end
end
