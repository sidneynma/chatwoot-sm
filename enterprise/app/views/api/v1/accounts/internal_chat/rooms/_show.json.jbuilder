json.payload do
  json.id @room.id
  json.room_type @room.room_type
  json.name @room.display_name_for(Current.user)
  json.last_message_at @room.last_message_at&.to_i
  json.created_by_id @room.created_by_id
  json.peer_inactive @room.peer_inactive_for?(Current.user)
  json.can_send @room.can_send_message?(Current.user)
  json.closed @room.closed_for?(Current.user)
  json.members @room.members do |user|
    json.id user.id
    json.name user.name
    json.available_name user.available_name
    json.thumbnail user.avatar_url
  end
end
