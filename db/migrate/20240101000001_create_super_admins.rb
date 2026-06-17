class CreateSuperAdmins < ActiveRecord::Migration[7.2]
  def change
    create_table :super_admins, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string :name,            null: false
      t.string :email,           null: false
      t.string :password_digest, null: false
      t.string :jti,             null: false
      t.timestamps
    end
    add_index :super_admins, :email, unique: true
    add_index :super_admins, :jti,   unique: true
  end
end
