class InternalChat::CreateMessageService
  pattr_initialize [:account!, :room!, :user!, :content, :blob_signed_ids, :is_voice]

  def perform
    raise ArgumentError, 'Cannot send messages in this chat' unless room.can_send_message?(user)

    message = room.messages.new(
      account: account,
      user: user,
      content: content.to_s.strip.presence,
      is_voice: ActiveModel::Type::Boolean.new.cast(is_voice) || false
    )

    # Attach before save so content-or-attachment validation passes for file-only messages.
    attach_blobs(message)
    message.save!

    message = room.messages.includes(:user).with_attached_attachments.find(message.id)

    # Side effects must not fail the request after the message is persisted
    # (otherwise the client shows an error while the message already exists).
    update_room_state!(message)

    begin
      InternalChat::BroadcastService.message_created(message)
    rescue StandardError => e
      Rails.logger.warn("Internal chat broadcast failed: #{e.message}")
    end

    message
  end

  private

  def update_room_state!(message)
    room.update!(last_message_at: message.created_at)
    room.reopen_for_active_members!
    membership = room.memberships.find_by(user_id: user.id)
    membership&.update!(last_read_at: message.created_at, closed_at: nil)
  rescue StandardError => e
    Rails.logger.warn("Internal chat room state update failed: #{e.class}: #{e.message}")
  end

  def attach_blobs(message)
    Array(blob_signed_ids).compact_blank.each do |signed_id|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      message.attachments.attach(blob)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound => e
      Rails.logger.warn("Internal chat blob attach failed: #{e.message}")
    end
  end
end
