class CreateStallMetadataAndAddColumns < ActiveRecord::Migration[7.2]
  def change
    create_table :stall_types, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    create_table :stall_sizes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    create_table :stall_categories, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_column :stall_owners, :stall_type, :string
    add_column :stall_owners, :stall_size, :string
    add_index :stall_types, :name, unique: true
    add_index :stall_sizes, :name, unique: true
    add_index :stall_categories, :name, unique: true
  end
end
