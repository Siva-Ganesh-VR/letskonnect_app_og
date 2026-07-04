# ─────────────────────────────────────────────────────────────────────────────
#  ISSUE: Human-readable Event ID  →  EXP-2026-0001, EXP-2026-0002, etc.
#
#  Files to change:
#    1. db/migrate/YYYYMMDDXXXXXX_add_event_code_to_events.rb  (new file)
#    2. app/models/event.rb                                     (add callback + method)
#
#  After dropping these files:
#    bin/rails db:migrate
# ─────────────────────────────────────────────────────────────────────────────


# ─── 1. MIGRATION ────────────────────────────────────────────────────────────
# File: db/migrate/20260704000001_add_event_code_to_events.rb

class AddEventCodeToEvents < ActiveRecord::Migration[7.2]
  def up
    # Add the column — nullable first so existing rows don't violate NOT NULL
    add_column :events, :event_code, :string, limit: 20

    # Backfill existing events in chronological order
    # Each gets a code based on the year it was created
    Event.order(:created_at).each do |event|
      year     = event.created_at.year
      sequence = Event
                   .where("EXTRACT(YEAR FROM created_at) = ?", year)
                   .where("created_at <= ?", event.created_at)
                   .count
      event.update_column(:event_code, format("EXP-%d-%04d", year, sequence))
    end

    # Now lock it down
    change_column_null :events, :event_code, false
    add_index :events, :event_code, unique: true
  end

  def down
    remove_index :events, :event_code
    remove_column :events, :event_code
  end
end
