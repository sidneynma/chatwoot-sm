module Enterprise::ActionCableListener
  include Events::Types
  def copilot_message_created(event)
    copilot_message = event.data[:copilot_message]
    copilot_thread = copilot_message.copilot_thread
    account = copilot_thread.account
    user = copilot_thread.user

    broadcast(account, [user.pubsub_token], COPILOT_MESSAGE_CREATED, copilot_message.push_event_data)
  end

  private

  def user_tokens(account, agents)
    (super + conversation_view_all_tokens(account)).uniq
  end

  def conversation_view_all_tokens(account)
    User.joins(account_users: :custom_role)
        .where(account_users: { account_id: account.id })
        .where('? = ANY(custom_roles.permissions)', 'conversation_view_all')
        .pluck(:pubsub_token)
  end
end
