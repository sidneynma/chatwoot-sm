class AddInboxIdToCannedResponses < ActiveRecord::Migration[7.1]
  def change
    add_reference :canned_responses, :inbox, foreign_key: true, null: true
    add_index :canned_responses, [:account_id, :inbox_id]
  end
end
