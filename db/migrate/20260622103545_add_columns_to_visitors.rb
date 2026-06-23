class AddColumnsToVisitors < ActiveRecord::Migration[7.2]
  def change
    add_column :visitors, :looking_for, :string
    add_column :visitors, :decision_maker, :boolean
    add_column :visitors, :whatsapp_state, :string, default: "start"
    add_column :visitors, :whatsapp_completed_at, :datetime
  end
end
