class CreateLeads < ActiveRecord::Migration[7.2]
  def change
    create_table :leads, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :visitor,     type: :uuid, foreign_key: true, null: false
      t.references :stall_owner, type: :uuid, foreign_key: true, null: false
      t.references :event,       type: :uuid, foreign_key: true, null: false
      t.string     :temperature,       default: "warm", null: false
      t.integer    :interest_rating,   default: 3,      null: false
      t.string     :status,            default: "new",  null: false
      t.text       :notes
      t.string     :requirements
      t.decimal    :budget, precision: 15, scale: 2
      t.date       :follow_up_date
      t.text       :remarks
      t.datetime   :scanned_at,                         null: false
      t.string     :scan_location
      t.timestamps
    end
    add_index :leads, [:stall_owner_id, :visitor_id], unique: true
    add_index :leads, :event_id, if_not_exists: true
    add_index :leads, :stall_owner_id, if_not_exists: true
    add_index :leads, :visitor_id, if_not_exists: true
    add_index :leads, :status, if_not_exists: true
    add_index :leads, :temperature, if_not_exists: true
    add_index :leads, :follow_up_date, if_not_exists: true
    add_index :leads, :scanned_at, if_not_exists: true
    add_index :leads, [:stall_owner_id, :status]
    add_index :leads, [:stall_owner_id, :temperature]
    add_index :leads, [:event_id, :created_at]
  end
end
