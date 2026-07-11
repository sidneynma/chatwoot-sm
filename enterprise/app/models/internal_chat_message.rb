class InternalChatMessage < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :account
  belongs_to :internal_chat_room
  belongs_to :user

  has_many_attached :attachments

  validate :must_have_content_or_attachment

  def push_event_data
    {
      id: id,
      content: content,
      is_voice: is_voice,
      created_at: created_at.to_i,
      room_id: internal_chat_room_id,
      account_id: account_id,
      sender: {
        id: user.id,
        name: user.name,
        available_name: user.available_name,
        thumbnail: user.try(:avatar_url)
      },
      attachments: attachment_payloads
    }
  end

  def attachment_payloads
    return [] unless attachments.attached?

    attachments.map do |attachment|
      {
        id: attachment.id,
        file_type: file_type_for(attachment),
        data_url: safe_attachment_url(attachment),
        thumb_url: safe_attachment_url(attachment),
        file_name: attachment.filename.to_s,
        file_size: attachment.byte_size,
        extension: attachment.filename.extension
      }
    end
  end

  private

  def must_have_content_or_attachment
    return if content.present? || attachments.attached?

    errors.add(:base, 'Message must have text or an attachment')
  end

  def safe_attachment_url(attachment)
    url_for(attachment)
  rescue StandardError
    Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
  end

  def file_type_for(attachment)
    content_type = attachment.content_type.to_s
    return 'image' if content_type.start_with?('image/')
    return 'audio' if content_type.start_with?('audio/') || is_voice
    return 'video' if content_type.start_with?('video/')

    'file'
  end
end
