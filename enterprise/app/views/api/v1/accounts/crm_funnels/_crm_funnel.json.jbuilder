json.id crm_funnel.id
json.name crm_funnel.name
json.inbox_id crm_funnel.inbox_id
json.active crm_funnel.active
json.stages do
  json.array! crm_funnel.stages do |stage|
    json.id stage.id
    json.position stage.position
    json.responsible_team_id stage.responsible_team_id
    json.can_resolve stage.can_resolve
    json.auto_resolve_on_enter stage.auto_resolve_on_enter
    json.clear_assignment_on_resolve stage.clear_assignment_on_resolve
    json.label do
      json.id stage.label.id
      json.title stage.label.title
      json.color stage.label.color
    end
    if stage.responsible_team
      json.responsible_team do
        json.id stage.responsible_team.id
        json.name stage.responsible_team.name
      end
    else
      json.responsible_team nil
    end
  end
end
