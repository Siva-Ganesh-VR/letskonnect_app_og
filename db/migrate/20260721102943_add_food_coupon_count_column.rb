class AddFoodCouponCountColumn < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :food_coupon_count, :string
    add_column :stall_owners, :food_coupon_count, :string
  end
end
