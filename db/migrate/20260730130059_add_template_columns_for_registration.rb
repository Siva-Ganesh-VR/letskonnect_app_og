class AddTemplateColumnsForRegistration < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :template_id, :uuid

    add_column :templates,
               :is_default,
               :boolean,
               default: false,
               null: false

    add_index :events, :template_id

    add_index :templates,
              :template_type,
              unique: true,
              where: "is_default = true",
              name: "idx_default_template_per_type"
  end
end