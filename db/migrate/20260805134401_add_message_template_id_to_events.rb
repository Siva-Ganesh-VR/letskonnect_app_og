class AddMessageTemplateIdToEvents < ActiveRecord::Migration[7.2]
  def change
    rename_column :events, :template_id, :question_template_id

    add_column :events, :message_template_id, :uuid, null: true
    add_index :events, :message_template_id
  end
end
