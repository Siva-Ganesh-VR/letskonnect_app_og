# File: db/migrate/20260704000003_add_stall_code_to_stall_owners.rb

class AddStallCodeToStallOwners < ActiveRecord::Migration[7.2]
  def up
    add_column :stall_owners, :stall_code, :string, limit: 30

    # Backfill: for each event, number stall owners in created_at order
    Event.find_each do |event|
      event.stall_owners.order(:created_at).each_with_index do |stall, idx|
        # event.event_code may be nil if events migration hasn't run yet —
        # use a fallback placeholder; re-run after event migration if needed
        event_code = event.event_code || format("EXP-%d-%04d", event.created_at.year, 0)
        stall.update_column(:stall_code, format("STL-%s-%04d", event_code, idx + 1))
      end
    end

    change_column_null :stall_owners, :stall_code, false
    add_index :stall_owners, :stall_code, unique: true
  end

  def down
    remove_index :stall_owners, :stall_code
    remove_column :stall_owners, :stall_code
  end
end

