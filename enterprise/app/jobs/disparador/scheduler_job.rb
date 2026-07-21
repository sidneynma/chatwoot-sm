class Disparador::SchedulerJob < ApplicationJob
  queue_as :low

  def perform
    return unless Chatolhe::DisparadorConfig.scheduler_enabled?

    dispatch_due_recipients!
    dispatch_due_campaigns!
  end

  private

  def dispatch_due_campaigns!
    limit = Chatolhe::DisparadorConfig.scheduler_batch_campaigns
    DisparadorCampaign.active
                     .where(status: 'scheduled')
                     .where('scheduled_at <= ?', Time.current)
                     .order(:scheduled_at)
                     .limit(limit)
                     .find_each do |campaign|
      Disparador::StartDispatchJob.perform_later(campaign.id)
    end
  end

  def dispatch_due_recipients!
    limit = Chatolhe::DisparadorConfig.scheduler_batch_campaigns * 4
    due = DisparadorRecipient
          .joins(:disparador_campaign)
          .where(status: 'pending')
          .where.not(scheduled_at: nil)
          .where('disparador_recipients.scheduled_at <= ?', Time.current)
          .where.not(disparador_campaigns: { status: %w[completed cancelled failed] })
          .order('disparador_recipients.scheduled_at ASC')
          .limit(limit)

    due.find_each do |recipient|
      campaign = recipient.disparador_campaign
      mode = if campaign.channel == 'evolution'
               'evolution'
             else
               campaign.metadata&.dig('dispatch_mode').presence || 'conversation'
             end
      recipient.update!(status: 'queued', last_event_at: Time.current)
      Disparador::SendRecipientJob.perform_later(recipient.id, mode)
    end
  end
end
