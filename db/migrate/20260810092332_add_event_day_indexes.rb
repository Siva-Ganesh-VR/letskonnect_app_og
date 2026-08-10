# db/migrate/20260810000001_add_event_day_indexes.rb
# Run: rails db:migrate
# Then on server: docker exec -it letskonnect_app_og-web-1 rails db:migrate
class AddEventDayIndexes < ActiveRecord::Migration[7.2]
  def change
    # Speeds up duplicate lead check on scan: Lead.find_by(visitor_id:, stall_owner_id:)
    # Already exists as unique index — just confirming
    # index_leads_on_stall_owner_id_and_visitor_id ✅

    # Speeds up scan log queries during analytics refresh
    unless index_exists?(:visitor_scan_logs, [:event_id, :scanned_at])
      add_index :visitor_scan_logs, [:event_id, :scanned_at],
                name: "index_visitor_scan_logs_on_event_id_and_scanned_at"
    end

    # Speeds up verified visitor lookup for lucky draw
    # Already exists: index_visitors_on_event_id_and_mobile_verified ✅

    # Speeds up notification dedup check
    unless index_exists?(:notifications, [:notifiable_type, :notifiable_id, :notification_type])
      add_index :notifications,
                [:notifiable_type, :notifiable_id, :notification_type],
                name: "index_notifications_on_notifiable_and_type"
    end
  end
end

