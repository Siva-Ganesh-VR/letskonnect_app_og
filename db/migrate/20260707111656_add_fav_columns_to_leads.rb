class AddFavColumnsToLeads < ActiveRecord::Migration[7.2]
  def change
    add_column :leads, :is_favorite, :boolean, default: false, null: false
    add_column :leads, :favorited_at, :datetime
  end
end
