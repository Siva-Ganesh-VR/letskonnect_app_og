class CreateLuckyDrawResults < ActiveRecord::Migration[7.2]
  def change
    create_table :lucky_draw_results, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid    :event_id,    null: false
      t.uuid    :visitor_id,  null: false
      t.integer :round,       null: false, default: 1
      t.string  :drawn_by_type                      # "EventOrganizer" or "SuperAdmin"
      t.uuid    :drawn_by_id
      t.timestamps
    end

    add_index :lucky_draw_results, :event_id
    add_index :lucky_draw_results, :visitor_id
    add_index :lucky_draw_results, [:event_id, :visitor_id]
    add_foreign_key :lucky_draw_results, :events
    add_foreign_key :lucky_draw_results, :visitors
  end
end
