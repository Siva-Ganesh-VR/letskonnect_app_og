class AddFeedbackReminderCountToVisitors < ActiveRecord::Migration[7.2]
  def change
    add_column :visitors, :feedback_reminder_count, :integer, default: 0, null: false
  end
end
