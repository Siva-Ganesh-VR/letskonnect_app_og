class CreateVisitors < ActiveRecord::Migration[7.2]
  def change
    create_table :visitors, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string   :full_name,        null: false
      t.string   :mobile_number,    null: false
      t.string   :location
      t.string   :profession
      t.string   :business_category
      t.string   :business_name
      t.string   :designation
      t.string   :email
      t.string   :website
      t.string   :visitor_id_code,  null: false
      t.string   :qr_token,         null: false
      t.string   :qr_image_url
      t.string   :otp_code
      t.datetime :otp_expires_at
      t.boolean  :mobile_verified,  default: false, null: false
      t.boolean  :active,           default: true,  null: false
      t.datetime :checked_in_at
      t.references :event, type: :uuid, foreign_key: true, null: false
      t.timestamps
    end
    add_index :visitors, :qr_token,                       unique: true
    add_index :visitors, :visitor_id_code,                unique: true
    add_index :visitors, [:mobile_number, :event_id],     unique: true
    add_index :visitors, :event_id, if_not_exists: true
    add_index :visitors, :business_category
    add_index :visitors, :created_at
    add_index :visitors, [:event_id, :mobile_verified], where: "mobile_verified = true"
  end
end
