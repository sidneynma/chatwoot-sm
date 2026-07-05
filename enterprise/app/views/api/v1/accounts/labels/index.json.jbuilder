json.payload do
  json.array! @labels, partial: 'api/v1/accounts/labels/label', as: :label
end
