class AddClosedAtToInternalChatMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :internal_chat_memberships, :closed_at, :datetime
    add_index :internal_chat_memberships, [:user_id, :closed_at],
              name: 'index_internal_chat_memberships_on_user_and_closed_at'
  end
end
