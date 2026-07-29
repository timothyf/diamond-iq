class ExpandSavedAnalysisUrls < ActiveRecord::Migration[7.1]
  def change
    change_column :saved_analyses, :reproducible_url, :text, null: false
  end
end
