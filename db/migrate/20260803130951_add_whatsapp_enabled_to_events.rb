class AddWhatsappEnabledToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :whatsapp_enabled, :boolean, default: false, null: false
  end
end
