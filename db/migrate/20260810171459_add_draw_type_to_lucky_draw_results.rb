# db/migrate/20260810000002_add_draw_type_to_lucky_draw_results.rb
class AddDrawTypeToLuckyDrawResults < ActiveRecord::Migration[7.2]
  def change
    # regular = time-window draw, bumper = all-time pool draw
    add_column :lucky_draw_results, :draw_type,    :string,   default: "regular", null: false
    # window_start and window_end define the registration window for regular draws
    add_column :lucky_draw_results, :window_start, :datetime
    add_column :lucky_draw_results, :window_end,   :datetime

    add_index :lucky_draw_results, [:event_id, :draw_type]
  end
end

