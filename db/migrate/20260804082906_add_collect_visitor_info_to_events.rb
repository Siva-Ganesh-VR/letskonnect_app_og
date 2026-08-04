class AddCollectVisitorInfoToEvents < ActiveRecord::Migration[7.2]
  def change
    remove_column :events, :whatsapp_enabled, :boolean, default: false, null: false
    add_column :events, :collect_visitor_info, :string, default: "web_form", null: false
  end
end
