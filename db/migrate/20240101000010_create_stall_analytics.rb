class CreateStallAnalytics < ActiveRecord::Migration[7.2]
  def change
    create_table :stall_analytics, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :stall_owner, type: :uuid, foreign_key: true, null: false
      t.references :event,       type: :uuid, foreign_key: true, null: false
      t.integer :total_leads,      default: 0
      t.integer :hot_leads,        default: 0
      t.integer :warm_leads,       default: 0
      t.integer :cold_leads,       default: 0
      t.integer :converted_leads,  default: 0
      t.jsonb   :leads_by_hour,    default: {}
      t.jsonb   :leads_by_category, default: {}
      t.timestamps
    end
    add_index :stall_analytics, [:stall_owner_id, :event_id], unique: true
  end
end
