json.payload do
  json.array! @crm_funnels do |crm_funnel|
    json.partial! 'api/v1/accounts/crm_funnels/crm_funnel', crm_funnel: crm_funnel
  end
end
