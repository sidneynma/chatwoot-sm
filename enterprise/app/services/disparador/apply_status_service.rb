class Disparador::ApplyStatusService
  STATUS_RANK = {
    'pending' => 0,
    'queued' => 1,
    'sent' => 2,
    'delivered' => 3,
    'read' => 4,
    'replied' => 5,
    'failed' => 2,
    'opted_out' => 6,
    'bounced' => 6,
    'cancelled' => 6
  }.freeze

  TRACKABLE_STATUSES = %w[queued sent delivered read].freeze

  pattr_initialize [
    :meta_message_id,
    :status,
    :phone,
    :error_message,
    :account_id,
    :chatwoot_message_id,
    :conversation_id,
    :contact_id,
    :recipient_id
  ]

  def perform
    recipient = find_recipient
    if recipient.blank?
      Rails.logger.info(
        "[Disparador::ApplyStatus] skip status=#{status} " \
        "meta_id=#{meta_message_id} message_id=#{chatwoot_message_id} " \
        "conversation_id=#{conversation_id} contact_id=#{contact_id} " \
        "phone=#{phone} reason=recipient_not_found"
      )
      return
    end

    sync_message_ids!(recipient)
    return if status.blank?

    unless should_upgrade?(recipient.status, normalized_status)
      Rails.logger.info(
        "[Disparador::ApplyStatus] skip recipient=#{recipient.id} " \
        "current=#{recipient.status} incoming=#{normalized_status} reason=no_upgrade"
      )
      return
    end

    attrs = {
      status: normalized_status,
      last_event_at: Time.current
    }
    attrs[:error_message] = error_message if normalized_status == 'failed' && error_message.present?

    previous_status = recipient.status
    recipient.update!(attrs)

    Rails.logger.info(
      "[Disparador::ApplyStatus] ok recipient=#{recipient.id} " \
      "campaign=#{recipient.disparador_campaign_id} #{previous_status}->#{normalized_status}"
    )

    maybe_complete_campaign!(recipient.disparador_campaign)
    recipient
  end

  private

  def normalized_status
    @normalized_status ||= begin
      raw = status.to_s.downcase
      case raw
      when 'failed', 'undeliverable' then 'failed'
      when 'delivered' then 'delivered'
      when 'read' then 'read'
      when 'sent' then 'sent'
      when 'replied' then 'replied'
      else raw
      end
    end
  end

  def find_recipient
    scope = DisparadorRecipient.joins(:disparador_campaign)
    scope = scope.where(disparador_campaigns: { account_id: account_id }) if account_id.present?

    if recipient_id.present?
      found = scope.find_by(id: recipient_id)
      return found if found
    end

    if meta_message_id.present?
      found = scope.where("disparador_recipients.metadata->>'meta_message_id' = ?", meta_message_id.to_s).first
      return found if found
    end

    if chatwoot_message_id.present?
      found = scope.where(
        "disparador_recipients.metadata->>'chatwoot_message_id' = ?",
        chatwoot_message_id.to_s
      ).first
      return found if found
    end

    if conversation_id.present?
      found = trackable_scope(scope).where(conversation_id: conversation_id)
                                   .order(updated_at: :desc)
                                   .first
      return found if found
    end

    if contact_id.present?
      found = trackable_scope(scope).where(contact_id: contact_id)
                                   .order(updated_at: :desc)
                                   .first
      return found if found
    end

    return if phone.blank?

    digits = phone.to_s.gsub(/\D/, '')
    return if digits.blank?

    trackable_scope(scope).order(updated_at: :desc).find do |r|
      r_digits = r.phone.to_s.gsub(/\D/, '')
      next if r_digits.blank?

      r_digits.end_with?(digits.last(10)) || digits.end_with?(r_digits.last(10))
    end
  end

  def trackable_scope(scope)
    scope.where(status: TRACKABLE_STATUSES)
  end

  def sync_message_ids!(recipient)
    meta = (recipient.metadata || {}).stringify_keys
    changed = false

    if meta_message_id.present? && meta['meta_message_id'].blank?
      meta['meta_message_id'] = meta_message_id.to_s
      changed = true
    end

    if chatwoot_message_id.present? && meta['chatwoot_message_id'].blank?
      meta['chatwoot_message_id'] = chatwoot_message_id.to_i
      changed = true
    end

    recipient.update_column(:metadata, meta) if changed # rubocop:disable Rails/SkipsModelValidations
  end

  def should_upgrade?(current, incoming)
    return true if incoming == 'failed' && STATUS_RANK.fetch(current.to_s, 0) < STATUS_RANK['sent']
    return false if incoming == 'failed'

    STATUS_RANK.fetch(incoming, 0) > STATUS_RANK.fetch(current.to_s, 0)
  end

  def maybe_complete_campaign!(campaign)
    return unless campaign.status == 'running'
    return if campaign.disparador_recipients.where(status: %w[pending queued]).exists?

    campaign.update!(status: 'completed', completed_at: Time.current)
  end
end
