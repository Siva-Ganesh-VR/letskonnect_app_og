class CreateTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :templates, id: :uuid do |t|
      t.string  :name, null: false
      t.string :template_type, null: false
      t.boolean :active, null: false, default: true
      t.uuid    :created_by

      t.timestamps
    end

    add_index :templates, :name
    add_index :templates, :template_type

    create_table :template_questions, id: :uuid do |t|
      t.references :template, null: false, foreign_key: true, type: :uuid

      t.string  :question, null: false
      t.string  :field_type, null: false
      t.boolean :required, default: false, null: false

      t.string  :placeholder
      t.string  :help_text
      t.text    :options
      t.integer :display_order, default: 1, null: false

      t.timestamps
    end

    add_index :template_questions, [:template_id, :display_order]

    create_table :template_messages, id: :uuid do |t|
      t.references :template, null: false, foreign_key: true, type: :uuid

      t.text :message, null: false

      t.timestamps
    end
  end
end
