class AddChapterNameToVisitors < ActiveRecord::Migration[7.2]
  def change
    add_column :visitors, :chapter_name, :string
  end
end
