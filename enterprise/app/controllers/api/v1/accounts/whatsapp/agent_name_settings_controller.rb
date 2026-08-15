class Api::V1::Accounts::Whatsapp::AgentNameSettingsController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox

  def update
    channel = @inbox.channel
    channel.provider_config = (channel.provider_config || {}).merge(
      'include_agent_name_in_messages' => ActiveModel::Type::Boolean.new.cast(params[:enabled])
    )
    channel.save!(validate: false)
    @inbox.update_account_cache

    render json: { enabled: channel.provider_config['include_agent_name_in_messages'] }
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params.require(:inbox_id))
    authorize @inbox, :update?
    return if @inbox.channel.is_a?(Channel::Whatsapp)

    render json: { error: 'Agent name setting is only available for WhatsApp inboxes' }, status: :unprocessable_entity
  end
end
