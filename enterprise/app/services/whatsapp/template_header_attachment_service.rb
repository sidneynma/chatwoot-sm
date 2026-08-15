class Whatsapp::TemplateHeaderAttachmentService
  FILE_TYPES = {
    'image' => :image,
    'video' => :video,
    'document' => :file
  }.freeze

  pattr_initialize [:message!]

  def perform
    return unless message.outgoing?
    return if message.private? || message.attachments.exists?
    return if media_url.blank? || file_type.blank?

    message.attachments.create!(
      account_id: message.account_id,
      file_type: file_type,
      external_url: media_url
    )
  rescue StandardError => e
    Rails.logger.error("[WhatsAppTemplate] header attachment failed message=#{message.id}: #{e.class}: #{e.message}")
  end

  private

  def header
    @header ||= message.additional_attributes.dig('template_params', 'processed_params', 'header') || {}
  end

  def media_url
    header['media_url']
  end

  def file_type
    FILE_TYPES[header['media_type'].to_s.downcase]
  end
end
