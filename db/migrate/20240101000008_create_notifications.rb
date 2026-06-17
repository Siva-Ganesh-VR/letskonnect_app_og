class CreateNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :notifications, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string   :notifiable_type,    null: false
      t.uuid     :notifiable_id,      null: false
      t.string   :notification_type,  null: false
      t.string   :channel,            null: false, default: "whatsapp"
      t.string   :status,             null: false, default: "pending"
      t.jsonb    :payload,            default: {}
      t.string   :external_message_id
      t.text     :error_message
      t.integer  :retry_count,        default: 0
      t.datetime :sent_at
      t.datetime :delivered_at
      t.references :event, type: :uuid, foreign_key: true
      t.timestamps
    end
    add_index :notifications, [:notifiable_type, :notifiable_id]
    add_index :notifications, :status
    add_index :notifications, :notification_type
    add_index :notifications, :created_at
    add_index :notifications, [:status, :retry_count], where: "status = 'failed'"
  end
end
