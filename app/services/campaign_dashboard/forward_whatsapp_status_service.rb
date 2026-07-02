# frozen_string_literal: true

# Encaminha status da Meta (delivered/read/failed) para o Campaign Dashboard
# quando nao existe Message no Chatwoot (envio rapido meta_direct sem conversa).
class CampaignDashboard::ForwardWhatsappStatusService
  pattr_initialize [:inbox!, :status!]

  def perform
    webhook_url = InstallationConfig.find_by(name: 'CAMPAIGN_DASHBOARD_STATUS_WEBHOOK_URL')&.value
    return if webhook_url.blank?

    payload = {
      event: 'whatsapp_status',
      meta_message_id: status[:id],
      status: status[:status],
      recipient_phone: status[:recipient_id],
      phone_number_id: status[:phone_number_id] || inbox.channel.try(:provider_config)&.dig('phone_number_id'),
      timestamp: status[:timestamp],
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      errors: status[:errors]
    }

    WebhookJob.perform_later(webhook_url, payload)
  rescue StandardError => e
    Rails.logger.error("[CampaignDashboard] forward status failed: #{e.message}")
  end
end
