class AddGroupSizeToVisitors < ActiveRecord::Migration[7.2]
  def change
    add_column :visitors, :group_size, :integer, default: 1, null: false
  end
end

