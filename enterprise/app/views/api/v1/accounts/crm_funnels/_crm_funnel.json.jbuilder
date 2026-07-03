json.id crm_funnel.id
json.name crm_funnel.name
json.inbox_id crm_funnel.inbox_id
json.active crm_funnel.active
json.stages do
  json.array! crm_funnel.stages do |stage|
    json.id stage.id
    json.position stage.position
    json.label do
      json.id stage.label.id
      json.title stage.label.title
      json.color stage.label.color
    end
  end
end
