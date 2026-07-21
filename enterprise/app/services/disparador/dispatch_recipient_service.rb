class Disparador::DispatchRecipientService
  pattr_initialize [:recipient!, :dispatch_mode]

  def perform
    campaign = recipient.disparador_campaign
    inbox = campaign.inbox
    raise 'Campaign inbox is required' if inbox.blank?

    result = if campaign.channel == 'evolution'
               send_via_evolution(campaign, inbox)
             else
               send_via_whatsapp(campaign, inbox)
             end

    recipient.update!(
      status: result[:status],
      conversation_id: result[:conversation_id] || recipient.conversation_id,
      contact_id: result[:contact_id] || recipient.contact_id,
      last_event_at: Time.current,
      error_message: nil,
      metadata: recipient.metadata.merge(result[:metadata] || {})
    )
    result
  rescue StandardError => e
    recipient.update!(
      status: 'failed',
      last_event_at: Time.current,
      error_message: e.message.to_s.truncate(500)
    )
    raise
  end

  private

  def send_via_whatsapp(campaign, inbox)
    raise 'WhatsApp Cloud inbox required' unless inbox.channel.is_a?(Channel::Whatsapp)

    mode = resolve_mode(campaign)
    if mode == 'conversation'
      send_via_conversation(campaign, inbox)
    else
      send_via_meta_direct(campaign, inbox)
    end
  end

  def send_via_evolution(campaign, inbox)
    raise 'Chatolhe API inbox required' unless inbox.channel.is_a?(Channel::Api)

    phone = normalize_phone(recipient.phone)
    raise 'Recipient phone is required' if phone.blank?

    agent_name = campaign.metadata&.dig('agent_name').to_s
    content = Disparador::RenderMessageService.new(
      template: campaign.message_template.to_s,
      recipient: recipient,
      agent_name: agent_name
    ).perform

    media = campaign.metadata&.dig('media') || {}
    media_url = media['media_url'].presence
    raise 'Campaign has no message or media' if content.blank? && media_url.blank?

    contact_inbox = ContactInboxWithContactBuilder.new(
      source_id: phone,
      inbox: inbox,
      contact_attributes: {
        name: recipient.name.presence || phone,
        phone_number: phone_e164(phone)
      }
    ).perform

    conversation = campaign.account.conversations.find_by(id: recipient.conversation_id) if recipient.conversation_id.present?
    conversation ||= Conversation.create!(
      account_id: campaign.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      additional_attributes: {
        'disparador_campaign_id' => campaign.id,
        'disparador_recipient_id' => recipient.id,
        'evolution_instance' => campaign.metadata&.dig('inbox_name') || campaign.metadata&.dig('evolution_instance')
      }
    )

    message_params = {
      content: content.presence || '',
      message_type: 'outgoing',
      private: false
    }

    attachment = build_remote_attachment(media_url, media['filename'])
    message_params[:attachments] = [attachment] if attachment

    message = Messages::MessageBuilder.new(nil, conversation, message_params).perform
    raise 'Chatolhe did not return a message id' if message.blank?

    {
      status: 'sent',
      conversation_id: conversation.id,
      contact_id: contact_inbox.contact_id,
      metadata: {
        'dispatch_mode' => 'evolution',
        'chatwoot_message_id' => message.id,
        'rendered_content' => content
      }
    }
  end

  def build_remote_attachment(media_url, filename)
    return if media_url.blank?

    tempfile, content_type, resolved_name = download_media(media_url, filename)
    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: resolved_name,
      type: content_type
    )
  end

  def download_media(media_url, filename)
    key = Disparador::MediaUploadService.object_key_from_url(media_url)
    if key.present?
      tempfile = Tempfile.new(['disparador-media', File.extname(key)])
      tempfile.binmode
      Disparador::MediaUploadService.client.get_object(
        bucket: Disparador::MediaUploadService.bucket_name,
        key: key,
        response_target: tempfile.path
      )
      tempfile.rewind
      return [tempfile, Marcel::MimeType.for(Pathname.new(tempfile.path)), filename.presence || File.basename(key)]
    end

    result_holder = nil
    SafeFetch.fetch(
      media_url,
      max_bytes: 5.megabytes,
      allowed_content_type_prefixes: %w[image/ video/],
      allowed_content_types: %w[application/pdf]
    ) do |result|
      result_holder = result
    end
    raise 'Failed to download media' if result_holder.blank?

    [
      result_holder.tempfile,
      result_holder.content_type,
      filename.presence || result_holder.filename
    ]
  rescue SafeFetch::Error => e
    raise "Failed to download media: #{e.message}"
  end

  def resolve_mode(campaign)
    override = dispatch_mode.presence
    return override if %w[meta_direct conversation].include?(override)

    stored = campaign.metadata&.dig('dispatch_mode')
    return stored if %w[meta_direct conversation].include?(stored)

    'meta_direct'
  end

  def template_params_for(campaign)
    template = campaign.metadata&.dig('template') || {}
    raise 'Campaign template is not configured' if template['name'].blank? || template['language'].blank?

    body = merge_body_params(template)
    header = template.dig('processed_params', 'header') || {}

    {
      'name' => template['name'],
      'namespace' => template['namespace'].to_s,
      'language' => template['language'],
      'category' => template['category'].presence || 'UTILITY',
      'processed_params' => {
        'body' => body,
        'header' => header
      }.compact
    }
  end

  def merge_body_params(template)
    defaults = (template.dig('processed_params', 'body') || {}).stringify_keys
    overrides = (recipient.metadata&.dig('template_params', 'body') || {}).stringify_keys
    defaults.merge(overrides).tap do |body|
      if Array(template['variable_keys']).include?('nome') || body.key?('nome')
        body['nome'] = recipient.name if body['nome'].blank?
      end
    end
  end

  def send_via_meta_direct(campaign, inbox)
    channel = inbox.channel
    template_params = template_params_for(campaign)
    processor = Whatsapp::TemplateProcessorService.new(channel: channel, template_params: template_params)
    name, namespace, lang_code, processed_parameters = processor.call
    raise 'Template could not be processed' if name.blank?

    phone = normalize_phone(recipient.phone)
    raise 'Recipient phone is required' if phone.blank?

    meta_message_id = channel.send_template(
      phone,
      { name: name, namespace: namespace, lang_code: lang_code, parameters: processed_parameters },
      nil
    )
    raise 'Meta did not return a message id' if meta_message_id.blank?

    {
      status: 'sent',
      metadata: {
        'dispatch_mode' => 'meta_direct',
        'meta_message_id' => meta_message_id,
        'template_params' => template_params
      }
    }
  end

  def send_via_conversation(campaign, inbox)
    phone = normalize_phone(recipient.phone)
    raise 'Recipient phone is required' if phone.blank?

    contact_inbox = ContactInboxWithContactBuilder.new(
      source_id: phone,
      inbox: inbox,
      contact_attributes: {
        name: recipient.name.presence || phone,
        phone_number: phone_e164(phone)
      }
    ).perform

    conversation = campaign.account.conversations.find_by(id: recipient.conversation_id) if recipient.conversation_id.present?
    conversation ||= Conversation.create!(
      account_id: campaign.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      additional_attributes: {
        'disparador_campaign_id' => campaign.id,
        'disparador_recipient_id' => recipient.id
      }
    )

    template_params = template_params_for(campaign)
    message = Messages::MessageBuilder.new(
      nil,
      conversation,
      {
        content: campaign.message_template.presence || template_params['name'],
        message_type: 'outgoing',
        template_params: template_params,
        private: false
      }
    ).perform

    {
      status: 'sent',
      conversation_id: conversation.id,
      contact_id: contact_inbox.contact_id,
      metadata: {
        'dispatch_mode' => 'conversation',
        'chatwoot_message_id' => message.id,
        'template_params' => template_params
      }
    }
  end

  def normalize_phone(phone)
    phone.to_s.gsub(/\D/, '')
  end

  def phone_e164(phone)
    digits = normalize_phone(phone)
    return if digits.blank?

    "+#{digits.delete_prefix('+')}"
  end
end
