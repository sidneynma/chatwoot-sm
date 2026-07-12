class InternalChat::UnreadCountService
  pattr_initialize [:account!, :user!]

  def perform
    memberships = InternalChatMembership.open
                                       .joins(:internal_chat_room)
                                       .where(
                                         user_id: user.id,
                                         internal_chat_rooms: { account_id: account.id }
                                       )

    memberships.sum(&:unread_count)
  end
end
