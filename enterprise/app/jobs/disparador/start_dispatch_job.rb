class Disparador::StartDispatchJob < ApplicationJob
  queue_as :medium

  def perform(campaign_id, dispatch_mode = nil, retry_failed = false)
    campaign = DisparadorCampaign.find_by(id: campaign_id)
    return if campaign.blank?

    Disparador::StartDispatchService.new(
      campaign: campaign,
      dispatch_mode: dispatch_mode,
      retry_failed: retry_failed
    ).perform
  end
end
