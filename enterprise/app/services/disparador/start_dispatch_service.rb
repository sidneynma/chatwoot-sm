class Disparador::StartDispatchService
  pattr_initialize [:campaign!, :dispatch_mode, :retry_failed]

  def perform
    raise 'Campaign is archived' if campaign.archived?
    raise 'Campaign inbox is required' if campaign.inbox_id.blank?

    campaign.update!(
      status: 'running',
      started_at: campaign.started_at || Time.current,
      scheduled_at: nil,
      metadata: campaign.metadata.merge(
        'dispatch_mode' => resolved_mode,
        'dispatch_started_at' => Time.current.iso8601
      )
    )

    reset_failed! if retry_failed

    if evolution_channel?
      dispatch_evolution_next!
    else
      dispatch_whatsapp_batch!
    end
  end

  private

  def evolution_channel?
    campaign.channel == 'evolution'
  end

  def resolved_mode
    @resolved_mode ||= begin
      return 'evolution' if evolution_channel?

      mode = dispatch_mode.presence || campaign.metadata&.dig('dispatch_mode')
      %w[meta_direct conversation].include?(mode) ? mode : 'meta_direct'
    end
  end

  def reset_failed!
    campaign.disparador_recipients.where(status: 'failed').find_each do |recipient|
      recipient.update!(
        status: 'pending',
        error_message: nil,
        metadata: recipient.metadata.except('meta_message_id', 'chatwoot_message_id', 'rendered_content')
      )
    end
  end

  def dispatch_whatsapp_batch!
    batch_size = Chatolhe::DisparadorConfig.batch_size
    ids = claim_recipient_ids(batch_size)
    return complete_if_idle! if ids.empty?

    ids.each do |id|
      Disparador::SendRecipientJob.perform_later(id, resolved_mode)
    end

    Disparador::StartDispatchJob.perform_later(campaign.id, resolved_mode, false) if pending_remaining?

    { claimed: ids.size, mode: resolved_mode }
  end

  # Sequential sends with delay between recipients (matches dashord Evolution behaviour).
  def dispatch_evolution_next!
    return complete_if_idle! if campaign.disparador_recipients.where(status: 'queued').exists?

    ids = claim_recipient_ids(1)
    return complete_if_idle! if ids.empty?

    Disparador::SendRecipientJob.perform_later(ids.first, 'evolution')
    { claimed: 1, mode: 'evolution' }
  end

  def claim_recipient_ids(limit)
    ids = []
    DisparadorRecipient.transaction do
      scope = campaign.disparador_recipients
                     .where(status: 'pending')
                     .where('scheduled_at IS NULL OR scheduled_at <= ?', Time.current)
                     .order(:id)
                     .limit(limit)
                     .lock('FOR UPDATE SKIP LOCKED')
      scope.each do |recipient|
        recipient.update!(status: 'queued', last_event_at: Time.current)
        ids << recipient.id
      end
    end
    ids
  end

  def pending_remaining?
    campaign.disparador_recipients.where(status: 'pending').exists?
  end

  def complete_if_idle!
    return { claimed: 0, mode: resolved_mode } if campaign.disparador_recipients.where(status: %w[pending queued]).exists?

    campaign.update!(status: 'completed', completed_at: Time.current)
    { claimed: 0, mode: resolved_mode, completed: true }
  end
end
