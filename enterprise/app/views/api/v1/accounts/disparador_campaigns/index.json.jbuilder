json.payload do
  json.array! @campaigns do |campaign|
    json.partial! 'api/v1/accounts/disparador_campaigns/campaign', campaign: campaign
  end
end
json.overview @overview if @overview.present?
