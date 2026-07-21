class ChangeActiveStorageAttachmentsRecordIdToUuid < ActiveRecord::Migration[7.2]
  def up
    remove_index :active_storage_attachments,
      name: "index_active_storage_attachments_uniqueness"

    remove_column :active_storage_attachments, :record_id

    add_column :active_storage_attachments, :record_id, :uuid, null: false

    add_index :active_storage_attachments,
      [:record_type, :record_id, :name, :blob_id],
      unique: true,
      name: "index_active_storage_attachments_uniqueness"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end