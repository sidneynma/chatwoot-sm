class AddCrmTeamHandoff < ActiveRecord::Migration[7.1]
  def change
    change_table :crm_funnel_stages, bulk: true do |t|
      t.references :responsible_team, foreign_key: { to_table: :teams }
      t.boolean :can_resolve, null: false, default: false
      t.boolean :auto_resolve_on_enter, null: false, default: false
      t.boolean :clear_assignment_on_resolve, null: false, default: true
    end

    create_table :crm_case_states do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :crm_funnel, null: false, foreign_key: true
      t.bigint :previous_assignee_id
      t.bigint :previous_team_id
      t.boolean :in_handoff, null: false, default: false

      t.timestamps
    end

    add_index :crm_case_states, [:conversation_id, :crm_funnel_id], unique: true
  end
end
