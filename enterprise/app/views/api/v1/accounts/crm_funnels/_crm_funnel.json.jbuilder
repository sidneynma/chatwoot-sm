teams_by_id = crm_funnel.account.teams
                         .where(id: crm_funnel.stages.flat_map(&:responsible_team_ids_list).uniq)
                         .index_by(&:id)

json.id crm_funnel.id
json.name crm_funnel.name
json.inbox_id crm_funnel.inbox_id
json.active crm_funnel.active
json.stages do
  json.array! crm_funnel.stages do |stage|
    team_ids = stage.responsible_team_ids_list
    json.id stage.id
    json.position stage.position
    json.responsible_team_id stage.primary_responsible_team_id
    json.responsible_team_ids team_ids
    json.can_resolve stage.can_resolve
    json.auto_resolve_on_enter stage.auto_resolve_on_enter
    json.clear_assignment_on_resolve stage.clear_assignment_on_resolve
    json.label do
      json.id stage.label.id
      json.title stage.label.title
      json.color stage.label.color
    end
    primary = teams_by_id[stage.primary_responsible_team_id]
    if primary
      json.responsible_team do
        json.id primary.id
        json.name primary.name
      end
    else
      json.responsible_team nil
    end
    json.responsible_teams do
      json.array! team_ids.filter_map { |id| teams_by_id[id] } do |team|
        json.id team.id
        json.name team.name
      end
    end
  end
end
