class InternalChat::CreateDirectService
  pattr_initialize [:account!, :current_user!, :peer_user_id!]

  def perform
    raise ArgumentError, 'Cannot chat with yourself' if peer_user_id.to_i == current_user.id

    key = InternalChatRoom.direct_key_for(current_user.id, peer_user_id)
    room = account.internal_chat_rooms.find_by(room_type: :direct, direct_key: key)

    if room
      # Reopen for the current user only (inactive peers stay closed / blocked from send).
      room.memberships.find_by(user_id: current_user.id)&.reopen!
      return room
    end

    peer = account.users.find(peer_user_id)

    account.internal_chat_rooms.create!(
      room_type: :direct,
      direct_key: key,
      created_by: current_user,
      memberships_attributes: [
        { user: current_user },
        { user: peer }
      ]
    )
  end
end
