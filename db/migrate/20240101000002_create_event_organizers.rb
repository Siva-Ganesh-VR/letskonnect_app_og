class CreateEventOrganizers < ActiveRecord::Migration[7.2]
  def change
    create_table :event_organizers, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string  :name,            null: false
      t.string  :email,           null: false
      t.string  :mobile_number,   null: false
      t.string  :password_digest, null: false
      t.string  :jti,             null: false
      t.string  :company_name
      t.string  :logo_url
      t.boolean :active,          default: true, null: false
      t.references :super_admin, type: :uuid, foreign_key: true, null: false
      t.timestamps
    end
    add_index :event_organizers, :email,         unique: true
    add_index :event_organizers, :jti,           unique: true
    add_index :event_organizers, :mobile_number
    add_index :event_organizers, :active
  end
end
