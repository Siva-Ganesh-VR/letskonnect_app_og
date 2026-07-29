class AddBniRegistrationQrTokenToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :bni_registration_qr_token, :string
  end
end
