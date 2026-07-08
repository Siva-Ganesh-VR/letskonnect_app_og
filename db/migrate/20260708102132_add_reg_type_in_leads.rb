class AddRegTypeInLeads < ActiveRecord::Migration[7.2]
  def change
    add_column :leads, :reg_type, :string, default: 'QR Scan', null: false
    add_column :visitors, :reg_type, :string, default: 'QR Scan', null: false
  end
end
