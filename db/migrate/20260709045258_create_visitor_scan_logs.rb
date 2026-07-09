class CreateVisitorScanLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :visitor_scan_logs, id: :uuid do |t|
      t.references :event, type: :uuid, null: false, foreign_key: true
      t.references :visitor, type: :uuid, null: false, foreign_key: true
      t.references :stall_owner, type: :uuid, null: false, foreign_key: true

      t.string :pass_code, null: false
      t.string :scan_type, default: "qr"      # qr, manual, etc.
      t.string :status, default: "success"    # success, duplicate
      t.string :device_info                  # Optional (browser/device)
      t.string :ip_address                   # Optional

      t.datetime :scanned_at, null: false

      t.timestamps
    end
  end
end
