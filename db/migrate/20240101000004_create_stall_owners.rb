class CreateStallOwners < ActiveRecord::Migration[7.2]
  def change
    create_table :stall_owners, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string  :name,            null: false
      t.string  :email
      t.string  :mobile_number,   null: false
      t.string  :password_digest, null: false
      t.string  :jti,             null: false
      t.string  :company_name,    null: false
      t.string  :stall_number
      t.string  :stall_category
      t.text    :description
      t.string  :logo_url
      t.string  :website
      t.boolean :active,          default: true, null: false
      t.integer :total_leads_count, default: 0,  null: false
      t.references :event,           type: :uuid, foreign_key: true, null: false
      t.references :event_organizer, type: :uuid, foreign_key: true
      t.timestamps
    end
    add_index :stall_owners, :jti,                       unique: true
    add_index :stall_owners, :mobile_number
    add_index :stall_owners, [:event_id, :stall_number], unique: true, where: "stall_number IS NOT NULL"
    add_index :stall_owners, [:event_id, :active]
  end
end
