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

  pattr_initialize [:meta_message_id, :status, :phone, :error_message, :account_id]

  def perform
    recipient = find_recipient
    return if recipient.blank?
    return unless should_upgrade?(recipient.status, normalized_status)

    attrs = {
      status: normalized_status,
      last_event_at: Time.current
    }
    attrs[:error_message] = error_message if normalized_status == 'failed' && error_message.present?
    recipient.update!(attrs)
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

    if meta_message_id.present?
      found = scope.where("disparador_recipients.metadata->>'meta_message_id' = ?", meta_message_id).first
      return found if found
    end

    return if phone.blank?

    digits = phone.to_s.gsub(/\D/, '')
    scope.where(status: %w[queued sent delivered read]).find do |r|
      r.phone.to_s.gsub(/\D/, '').end_with?(digits.last(10)) || digits.end_with?(r.phone.to_s.gsub(/\D/, '').last(10))
    end
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
