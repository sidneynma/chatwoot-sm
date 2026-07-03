json.payload do
  json.partial! 'api/v1/accounts/crm_funnels/crm_funnel', crm_funnel: @crm_funnel
end
