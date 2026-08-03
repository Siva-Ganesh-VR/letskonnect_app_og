class AddSendRegistrationWhatsappToVisitors < ActiveRecord::Migration[7.2]
  def change
    add_column :visitors, :send_registration_whatsapp, :boolean, default: false
  end
end
