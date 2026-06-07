class Api::V1::Accounts::Whatsapp::TemplatesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_whatsapp_inbox

  def index
    channel = @inbox.channel

    render json: {
      inbox_id: @inbox.id,
      inbox_name: @inbox.name,
      provider: channel.provider,
      message_templates_last_updated: channel.message_templates_last_updated,
      message_templates: normalize_templates(channel.message_templates)
    }
  end

  private

  def fetch_whatsapp_inbox
    if params[:inbox_id].blank?
      render json: { error: 'inbox_id is required' }, status: :bad_request
      return
    end

    @inbox = Current.account.inboxes.find(params[:inbox_id])
    return if @inbox.whatsapp?

    render json: { error: 'Templates are only available for WhatsApp inboxes' }, status: :bad_request
  end

  def normalize_templates(raw)
    return [] if raw.blank?
    return raw if raw.is_a?(Array)

    []
  end
end
