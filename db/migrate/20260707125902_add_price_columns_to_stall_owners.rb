class AddPriceColumnsToStallOwners < ActiveRecord::Migration[7.2]
  def change
    add_column :stall_owners, :price, :decimal, precision: 10, scale: 2
    add_column :stall_owners, :currency, :string, default: 'INR', null: false
  end
end
