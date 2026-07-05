class AddInboxIdToLabels < ActiveRecord::Migration[7.1]
  def change
    add_reference :labels, :inbox, foreign_key: true, null: true
    add_index :labels, [:account_id, :inbox_id]
  end
end
