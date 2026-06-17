class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string  :name,                   null: false
      t.text    :description
      t.string  :venue,                  null: false
      t.string  :city
      t.date    :start_date,             null: false
      t.date    :end_date,               null: false
      t.time    :start_time
      t.time    :end_time
      t.string  :slug,                   null: false
      t.string  :registration_qr_token,  null: false
      t.string  :qr_image_url
      t.string  :banner_url
      t.string  :logo_url
      t.string  :status,                 default: "draft",  null: false
      t.jsonb   :settings,               default: {}
      t.integer :max_visitors
      t.integer :registered_count,       default: 0,        null: false
      t.references :event_organizer, type: :uuid, foreign_key: true, null: false
      t.timestamps
    end
    add_index :events, :slug,                  unique: true
    add_index :events, :registration_qr_token, unique: true
    add_index :events, :status
    add_index :events, :start_date
    add_index :events, :event_organizer_id, if_not_exists: true
  end
end
