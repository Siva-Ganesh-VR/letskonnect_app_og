class CreateEventAnalytics < ActiveRecord::Migration[7.2]
  def change
    create_table :event_analytics, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :event, type: :uuid, foreign_key: true, null: false, index: { unique: true }
      t.integer :total_visitors,          default: 0
      t.integer :total_leads,             default: 0
      t.integer :total_scans,             default: 0
      t.integer :hot_leads,               default: 0
      t.integer :warm_leads,              default: 0
      t.integer :cold_leads,              default: 0
      t.jsonb   :visitors_by_category,    default: {}
      t.jsonb   :visitors_by_location,    default: {}
      t.jsonb   :visitors_by_profession,  default: {}
      t.jsonb   :hourly_registrations,    default: {}
      t.jsonb   :stall_performance,       default: {}
      t.timestamps
    end
  end
end
