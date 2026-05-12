class CreateUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :uploads do |t|
      t.string :slug, null: false
      t.bigint :byte_size, null: false
      t.string :sha256, null: false
      t.datetime :expires_at, null: false
      t.string :uploader_ip
      t.string :user_agent
      t.string :moderation_status, null: false, default: "active"
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :uploads, :slug, unique: true
    add_index :uploads, :expires_at
    add_index :uploads, :moderation_status
  end
end
