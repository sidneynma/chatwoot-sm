class InternalChat::HandleAgentRemovedService
  pattr_initialize [:account!, :user!]

  # Keeps DM history for remaining agents (memberships + messages stay).
  # Closes the removed agent's membership; peers keep the room open and see peer_inactive.
  # Group memberships are removed (messages remain for other members).
  def perform
    memberships = InternalChatMembership
                  .joins(:internal_chat_room)
                  .where(user_id: user.id, internal_chat_rooms: { account_id: account.id })
                  .includes(:internal_chat_room)

    memberships.find_each do |membership|
      room = membership.internal_chat_room

      if room.room_type_direct?
        membership.close!
      else
        membership.destroy!
      end
    end
  end
end
