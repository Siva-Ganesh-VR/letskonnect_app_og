class CreateExportJobs < ActiveRecord::Migration[7.2]
  def change
    create_table :export_jobs, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string  :exportable_type,     null: false
      t.uuid    :exportable_id,       null: false
      t.string  :export_type,         null: false
      t.string  :status,              null: false, default: "pending"
      t.string  :file_url
      t.text    :error_message
      t.jsonb   :filters,             default: {}
      t.string  :requested_by_type
      t.uuid    :requested_by_id
      t.datetime :completed_at
      t.datetime :expires_at
      t.timestamps
    end
    add_index :export_jobs, [:exportable_type, :exportable_id]
    add_index :export_jobs, :status
    add_index :export_jobs, :expires_at
  end
end
