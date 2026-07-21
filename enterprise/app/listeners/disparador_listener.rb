class DisparadorListener < BaseListener
  def message_updated(event)
    message, account = extract_message_and_account(event)
    return unless disparador_enabled?(account)

    changes = event.data[:previous_changes] || {}
    sync_source_id_if_needed(message, account, changes)
    apply_delivery_status_if_needed(message, account, changes)
  rescue StandardError => e
    Rails.logger.error("[DisparadorListener] message_updated failed: #{e.class}: #{e.message}")
  end

  def message_created(event)
    message, account = extract_message_and_account(event)
    return unless disparador_enabled?(account)
    return unless message.incoming?
    return if message.private?

    mark_replied!(message, account)
  rescue StandardError => e
    Rails.logger.error("[DisparadorListener] message_created failed: #{e.class}: #{e.message}")
  end

  private

  def disparador_enabled?(account)
    return false unless account.respond_to?(:chatolhe_module_enabled?)

    account.chatolhe_module_enabled?('disparador') ||
      account.chatolhe_module_enabled?('mensagens_agendadas')
  end

  def sync_source_id_if_needed(message, account, changes)
    return unless changes.key?('source_id')
    return if message.source_id.blank?
    return unless message.outgoing?

    Disparador::ApplyStatusService.new(
      account_id: account.id,
      chatwoot_message_id: message.id,
      meta_message_id: message.source_id,
      conversation_id: message.conversation_id,
      contact_id: message.conversation&.contact_id,
      phone: contact_phone(message),
      status: nil
    ).perform
  end

  def apply_delivery_status_if_needed(message, account, changes)
    return unless changes.key?('status')
    return unless message.outgoing?

    Rails.logger.info(
      "[DisparadorListener] status webhook/update message=#{message.id} " \
      "status=#{message.status} source_id=#{message.source_id} conversation=#{message.conversation_id}"
    )

    Disparador::ApplyStatusService.new(
      account_id: account.id,
      chatwoot_message_id: message.id,
      meta_message_id: message.source_id,
      conversation_id: message.conversation_id,
      contact_id: message.conversation&.contact_id,
      phone: contact_phone(message),
      status: message.status,
      error_message: message.external_error
    ).perform
  end

  def mark_replied!(message, account)
    conversation = message.conversation
    attrs = conversation.additional_attributes || {}
    recipient_id = attrs['disparador_recipient_id'] || attrs[:disparador_recipient_id]

    Rails.logger.info(
      "[DisparadorListener] incoming reply conversation=#{conversation.id} " \
      "recipient_attr=#{recipient_id} contact=#{conversation.contact_id}"
    )

    Disparador::ApplyStatusService.new(
      account_id: account.id,
      recipient_id: recipient_id,
      conversation_id: conversation.id,
      contact_id: conversation.contact_id,
      phone: contact_phone(message),
      status: 'replied'
    ).perform
  end

  def contact_phone(message)
    contact = message.conversation&.contact
    contact&.phone_number.presence || contact&.identifier
  end
end
