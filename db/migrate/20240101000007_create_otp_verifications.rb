class CreateOtpVerifications < ActiveRecord::Migration[7.2]
  def change
    create_table :otp_verifications, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string   :mobile_number, null: false
      t.string   :otp_code,      null: false
      t.string   :purpose,       null: false
      t.boolean  :used,          default: false, null: false
      t.datetime :expires_at,    null: false
      t.integer  :attempts,      default: 0,     null: false
      t.string   :ip_address
      t.timestamps
    end
    add_index :otp_verifications, :mobile_number
    add_index :otp_verifications, [:mobile_number, :purpose]
    add_index :otp_verifications, :expires_at
    add_index :otp_verifications, [:used, :expires_at]
  end
end
