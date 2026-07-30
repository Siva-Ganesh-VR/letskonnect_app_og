class UpdateFeedbackFields < ActiveRecord::Migration[7.2]
  def change
    rename_column :feedbacks, :organization_rating, :stall_rating
    rename_column :feedbacks, :venue_rating, :food_court_rating

    remove_column :feedbacks, :exhibitor_rating, :integer
    remove_column :feedbacks, :liked, :text
    remove_column :feedbacks, :improvements, :text
    remove_column :feedbacks, :recommend, :boolean

    add_column :feedbacks, :expectations, :string, null: false
    add_column :feedbacks, :suggestions, :text
    add_column :feedbacks, :specific_connect, :text
  end
end
