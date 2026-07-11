class InternalChat::SearchRoomsService
  pattr_initialize [:account!, :user!, :query!]

  def perform
    q = query.to_s.strip.downcase
    return [] if q.blank?

    rooms = account.internal_chat_rooms
                   .for_user(user)
                   .includes(:members, memberships: :user)

    rooms.select { |room| matches?(room, q) }.first(15)
  end

  private

  def matches?(room, q)
    name = room.display_name_for(user).to_s.downcase
    return true if name.include?(q)

    room.members.any? do |member|
      next if member.id == user.id

      [member.name, member.available_name, member.email]
        .compact
        .any? { |value| value.downcase.include?(q) }
    end
  end
end
