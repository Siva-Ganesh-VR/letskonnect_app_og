class RemoveUniqueIndexFromPassCode < ActiveRecord::Migration[7.2]
  def change
    remove_index :stall_owners, :pass_code
  end
end
