class Whatsapp::AgentNamePrefixService
  SETTING_KEY = 'include_agent_name_in_messages'.freeze

  pattr_initialize [:user!, :conversation!, :params!]

  def perform
    return unless eligible?

    params[:content] = "**#{user.available_name}:**\n#{params[:content]}"
  end

  private

  def eligible?
    user.is_a?(User) &&
      whatsapp_inbox? &&
      setting_enabled? &&
      outgoing_public_message? &&
      params[:template_params].blank? &&
      params[:sender_type] != 'AgentBot' &&
      params[:content].present?
  end

  def whatsapp_inbox?
    conversation.inbox.channel.is_a?(Channel::Whatsapp)
  end

  def setting_enabled?
    ActiveModel::Type::Boolean.new.cast(
      conversation.inbox.channel.provider_config&.[](SETTING_KEY)
    )
  end

  def outgoing_public_message?
    (params[:message_type].presence || 'outgoing') == 'outgoing' &&
      !ActiveModel::Type::Boolean.new.cast(params[:private])
  end
end
