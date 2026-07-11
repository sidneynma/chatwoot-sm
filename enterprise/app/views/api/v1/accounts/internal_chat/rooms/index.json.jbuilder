json.payload do
  json.array! @rooms do |room|
    membership = room.memberships.find { |item| item.user_id == Current.user.id }
    json.id room.id
    json.room_type room.room_type
    json.name room.display_name_for(Current.user)
    json.last_message_at room.last_message_at&.to_i
    json.unread_count membership&.unread_count.to_i
    json.created_by_id room.created_by_id
    json.peer_inactive room.peer_inactive_for?(Current.user)
    json.can_send room.can_send_message?(Current.user)
    json.closed membership&.closed? || false
    json.members room.members do |user|
      json.id user.id
      json.name user.name
      json.thumbnail user.avatar_url
    end
  end
end
