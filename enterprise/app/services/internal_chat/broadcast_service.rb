class InternalChat::BroadcastService
  class << self
    def message_created(message)
      broadcast(message.internal_chat_room, 'internal_chat.message_created', message.push_event_data)
    end

    def room_updated(room, event_name = 'internal_chat.room_updated')
      broadcast(room, event_name, room_payload(room))
    end

    private

    def broadcast(room, event_name, data)
      tokens = room.members.filter_map(&:pubsub_token)
      return if tokens.blank?

      ActionCableBroadcastJob.perform_later(
        tokens,
        event_name,
        data.merge(account_id: room.account_id)
      )
    end

    def room_payload(room)
      {
        id: room.id,
        room_type: room.room_type,
        name: room.name,
        last_message_at: room.last_message_at&.to_i,
        account_id: room.account_id
      }
    end
  end
end
