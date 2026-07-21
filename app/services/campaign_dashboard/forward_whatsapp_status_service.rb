# Encaminha status da Meta (delivered/read/failed) para o Campaign Dashboard
# quando nao existe Message no Chatwoot (envio rapido meta_direct sem conversa).
# Tambem atualiza destinatarios nativos do modulo Disparador.
class CampaignDashboard::ForwardWhatsappStatusService
  pattr_initialize [:inbox!, :status!]

  def perform
    apply_native_disparador_status
    forward_to_external_dashboard
  rescue StandardError => e
    Rails.logger.error("[CampaignDashboard] forward status failed: #{e.message}")
  end

  private

  def apply_native_disparador_status
    error = status[:errors]&.first
    error_message = error.present? ? "#{error[:code]}: #{error[:title]}" : nil

    Disparador::ApplyStatusService.new(
      meta_message_id: status[:id],
      status: status[:status],
      phone: status[:recipient_id],
      error_message: error_message,
      account_id: inbox.account_id
    ).perform
  end

  def forward_to_external_dashboard
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
  end
end
