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
    sync_links!(recipient)
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

    phone_keys = phone_match_keys(phone)
    return if phone_keys.empty?

    trackable_scope(scope).order(updated_at: :desc).find do |r|
      (phone_match_keys(r.phone) & phone_keys).any?
    end
  end

  # BR mobiles often differ by the 9th digit (55 43 98823-5592 vs 55 43 8823-5592).
  # Build comparable keys so webhook contact phones still match campaign CSV phones.
  def phone_match_keys(value)
    digits = value.to_s.gsub(/\D/, '')
    return [] if digits.blank?

    keys = [digits]
    national = digits.start_with?('55') && digits.length >= 12 ? digits[2..] : digits
    keys << national
    keys << "55#{national}" unless national.start_with?('55')

    body = national
    if body.length == 11 && body[2] == '9'
      without_nine = "#{body[0, 2]}#{body[3..]}"
      keys.push(without_nine, "55#{without_nine}")
    elsif body.length == 10
      with_nine = "#{body[0, 2]}9#{body[2..]}"
      keys.push(with_nine, "55#{with_nine}")
    end

    keys.uniq
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

  def sync_links!(recipient)
    attrs = {}
    attrs[:contact_id] = contact_id if contact_id.present? && recipient.contact_id.blank?
    attrs[:conversation_id] = conversation_id if conversation_id.present? && recipient.conversation_id.blank?
    recipient.update_columns(attrs.merge(updated_at: Time.current)) if attrs.present? # rubocop:disable Rails/SkipsModelValidations

    return if conversation_id.blank? || normalized_status != 'replied'

    conversation = Conversation.find_by(id: conversation_id, account_id: account_id)
    return if conversation.blank?

    ca = (conversation.additional_attributes || {}).stringify_keys
    return if ca['disparador_recipient_id'].to_s == recipient.id.to_s

    conversation.update!(
      additional_attributes: ca.merge(
        'disparador_campaign_id' => recipient.disparador_campaign_id,
        'disparador_recipient_id' => recipient.id
      )
    )
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
