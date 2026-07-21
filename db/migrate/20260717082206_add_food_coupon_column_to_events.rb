class AddFoodCouponColumnToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :food_coupon, :boolean, default: false, null: false
  end
end
