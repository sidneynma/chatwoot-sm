module Enterprise::ConversationFinder
  def conversations_base_query
    return super unless current_account.feature_enabled?('sla')

    super.includes(:applied_sla, :sla_events, inbox: :working_hours)
  end

  def set_inboxes
    if conversation_view_all?
      @inbox_ids = if params[:inbox_id]
                     @current_account.inboxes.where(id: params[:inbox_id]).pluck(:id)
                   else
                     @current_account.inboxes.pluck(:id)
                   end
    else
      super
    end
  end

  private

  def conversation_view_all?
    account_user = @current_account.account_users.find_by(user_id: @current_user.id)
    account_user&.custom_role&.permissions&.include?('conversation_view_all')
  end
end
