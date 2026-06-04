class CreateStatTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :stat_types do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :stat_types, :name, unique: true
  end
end