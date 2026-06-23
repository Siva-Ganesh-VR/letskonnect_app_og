class UpdateVisitorColumns < ActiveRecord::Migration[7.2]
  def change
    change_column_null :visitors, :full_name, true
    change_column_null :visitors, :visitor_id_code, true
    change_column_null :visitors, :qr_token, true
  end
end
