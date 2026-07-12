module Enterprise::Api::V1::Accounts::ConversationsController
  extend ActiveSupport::Concern

  def inbox_assistant
    assistant = @conversation.inbox.captain_assistant

    if assistant
      render json: { assistant: { id: assistant.id, name: assistant.name } }
    else
      render json: { assistant: nil }
    end
  end

  def reporting_events
    @reporting_events = @conversation.reporting_events.order(created_at: :asc)
  end

  def toggle_status
    if resolving_conversation?
      ensure_crm_resolve_allowed!
      return if performed?
    end
    super
  end

  def permitted_update_params
    super.merge(params.permit(:sla_policy_id))
  end

  private

  def resolving_conversation?
    return true if params[:status].blank? && @conversation.open?

    params[:status].to_s == 'resolved'
  end

  def ensure_crm_resolve_allowed!
    return unless Current.user.is_a?(User)

    access = Crm::ConversationAccess.new(
      user: Current.user,
      account: Current.account,
      conversation: @conversation
    )
    return if access.can_resolve?

    render json: {
      error: I18n.t('crm_kanban.errors.read_only_resolve', default: 'Read-only access: you cannot resolve this conversation')
    }, status: :forbidden
  end

  def copilot_params
    params.permit(:previous_history, :message, :assistant_id)
  end
end
