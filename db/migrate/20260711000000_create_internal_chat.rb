class CreateInternalChat < ActiveRecord::Migration[7.1]
  def change
    create_table :internal_chat_rooms do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :room_type, null: false, default: 0
      t.string :name
      t.string :direct_key
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :last_message_at

      t.timestamps
    end

    add_index :internal_chat_rooms, [:account_id, :direct_key],
              unique: true,
              where: 'direct_key IS NOT NULL',
              name: 'index_internal_chat_rooms_on_account_direct_key'

    create_table :internal_chat_memberships do |t|
      t.references :internal_chat_room, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :last_read_at

      t.timestamps
    end

    add_index :internal_chat_memberships, [:internal_chat_room_id, :user_id],
              unique: true,
              name: 'index_internal_chat_memberships_on_room_and_user'

    create_table :internal_chat_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :internal_chat_room, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.boolean :is_voice, null: false, default: false

      t.timestamps
    end

    add_index :internal_chat_messages, [:internal_chat_room_id, :id]
  end
end
