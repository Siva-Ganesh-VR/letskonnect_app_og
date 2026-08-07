class CreateVisitorMessageDeliveries < ActiveRecord::Migration[7.2]
  def change
    create_table :visitor_message_deliveries, id: :uuid do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid
      t.references :visitor, null: false, foreign_key: true, type: :uuid

      t.references :template, foreign_key: { to_table: :templates }, type: :uuid

      t.string :twilio_message_sid
      t.string :status, null: false, default: "pending"
      t.string :message_type, null: false

      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at
      t.datetime :failed_at

      t.text :error_message

      t.timestamps
    end

    add_index :visitor_message_deliveries, [:event_id, :visitor_id], unique: true
    add_index :visitor_message_deliveries, :twilio_message_sid, unique: true
    add_index :visitor_message_deliveries, [:event_id, :status]
    add_index :visitor_message_deliveries, :status
    add_index :visitor_message_deliveries, :message_type
  end
end
