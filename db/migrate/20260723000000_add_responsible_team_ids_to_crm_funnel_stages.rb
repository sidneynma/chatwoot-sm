class AddResponsibleTeamIdsToCrmFunnelStages < ActiveRecord::Migration[7.1]
  def up
    add_column :crm_funnel_stages, :responsible_team_ids, :bigint, array: true, null: false, default: []

    execute <<-SQL.squish
      UPDATE crm_funnel_stages
      SET responsible_team_ids = ARRAY[responsible_team_id]
      WHERE responsible_team_id IS NOT NULL
    SQL
  end

  def down
    remove_column :crm_funnel_stages, :responsible_team_ids
  end
end
