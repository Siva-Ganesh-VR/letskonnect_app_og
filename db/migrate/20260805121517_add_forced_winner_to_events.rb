class AddForcedWinnerToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :forced_winner_visitor_id, :uuid
  end
end
