class Disparador::SendRecipientJob < ApplicationJob
  queue_as :medium

  # Soft concurrency: Sidekiq processes jobs in parallel across workers;
  # DISPARADOR_META_CONCURRENCY is honored by batch size in StartDispatchService.
  def perform(recipient_id, dispatch_mode = nil)
    recipient = DisparadorRecipient.find_by(id: recipient_id)
    return if recipient.blank?
    return unless recipient.status == 'queued'

    Disparador::DispatchRecipientService.new(
      recipient: recipient,
      dispatch_mode: dispatch_mode
    ).perform
  rescue StandardError => e
    Rails.logger.error("[Disparador] send recipient #{recipient_id} failed: #{e.message}")
  ensure
    schedule_next_or_complete(recipient_id)
  end

  private

  def schedule_next_or_complete(recipient_id)
    recipient = DisparadorRecipient.find_by(id: recipient_id)
    return if recipient.blank?

    campaign = recipient.disparador_campaign
    return unless campaign.status == 'running'

    if campaign.channel == 'evolution' && campaign.disparador_recipients.where(status: 'pending').exists?
      delay = evolution_delay_seconds(campaign)
      Disparador::StartDispatchJob.set(wait: delay.seconds).perform_later(campaign.id, 'evolution', false)
      return
    end

    return if campaign.disparador_recipients.where(status: %w[pending queued]).exists?

    campaign.update!(status: 'completed', completed_at: Time.current)
  end

  def evolution_delay_seconds(campaign)
    raw = campaign.metadata&.dig('evolution_delay_seconds')
    return 15 if raw.nil? || raw == ''

    sec = raw.to_i
    return 15 if sec.negative?

    [sec, 300].min
  end
end
