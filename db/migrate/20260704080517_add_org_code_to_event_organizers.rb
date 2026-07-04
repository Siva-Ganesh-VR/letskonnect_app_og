# ── 2. MIGRATION: event_organizers ───────────────────────────────────────────
# File: db/migrate/20260704000002_add_org_code_to_event_organizers.rb

class AddOrgCodeToEventOrganizers < ActiveRecord::Migration[7.2]
  def up
    add_column :event_organizers, :org_code, :string, limit: 20

    # Backfill existing organizers
    EventOrganizer.order(:created_at).each do |org|
      year     = org.created_at.year
      sequence = EventOrganizer
                   .where("EXTRACT(YEAR FROM created_at) = ?", year)
                   .where("created_at <= ?", org.created_at)
                   .count
      org.update_column(:org_code, format("ORG-%d-%04d", year, sequence))
    end

    change_column_null :event_organizers, :org_code, false
    add_index :event_organizers, :org_code, unique: true
  end

  def down
    remove_index :event_organizers, :org_code
    remove_column :event_organizers, :org_code
  end
end

