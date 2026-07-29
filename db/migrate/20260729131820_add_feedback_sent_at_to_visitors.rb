class AddFeedbackSentAtToVisitors < ActiveRecord::Migration[7.2]
  def change
    add_column :visitors, :feedback_sent_at, :datetime
    add_index :visitors, :feedback_sent_at
  end
end
