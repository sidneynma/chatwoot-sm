json.payload do
  json.array! @recipients do |recipient|
    json.id recipient.id
    json.uuid recipient.uuid
    json.disparador_campaign_id recipient.disparador_campaign_id
    json.contact_id recipient.contact_id
    json.conversation_id recipient.conversation_id
    json.name recipient.name
    json.phone recipient.phone
    json.email recipient.email
    json.status recipient.status
    json.last_event_at recipient.last_event_at
    json.scheduled_at recipient.scheduled_at
    json.error_message recipient.error_message
    json.created_at recipient.created_at
    json.updated_at recipient.updated_at
  end
end
