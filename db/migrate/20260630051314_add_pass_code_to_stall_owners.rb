class AddPassCodeToStallOwners < ActiveRecord::Migration[7.2]
  def change
    add_column :stall_owners, :pass_code, :string
    add_index :stall_owners, :pass_code, unique: true
  end
end
