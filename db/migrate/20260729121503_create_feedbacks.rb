class CreateFeedbacks < ActiveRecord::Migration[7.2]
  def change
    create_table :feedbacks do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid
      t.references :visitor, null: false, foreign_key: true, type: :uuid

      t.integer :overall_rating, null: false
      t.integer :organization_rating, null: false
      t.integer :venue_rating, null: false
      t.integer :exhibitor_rating, null: false

      t.text :liked
      t.text :improvements

      t.boolean :recommend, null: false

      t.timestamps
    end

    add_index :feedbacks, [:event_id, :visitor_id], unique: true
  end
end
