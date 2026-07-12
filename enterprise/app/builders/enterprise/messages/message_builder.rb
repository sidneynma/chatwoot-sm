module Enterprise::Messages::MessageBuilder
  def perform
    ensure_crm_reply_allowed!
    super
  end

  private

  def ensure_crm_reply_allowed!
    return unless @user.is_a?(User)
    return if Current.account.blank?

    access = Crm::ConversationAccess.new(
      user: @user,
      account: Current.account,
      conversation: @conversation
    )

    return if @private ? access.can_create_private_note? : access.can_reply_publicly?

    raise StandardError, I18n.t('crm_kanban.errors.read_only_reply', default: 'Read-only access: you cannot reply on this conversation')
  end

  def message_type
    return @message_type if @message_type == 'incoming' && voice_call_inbox? && @params[:content_type] == 'voice_call'

    super
  end

  def voice_call_inbox?
    @conversation.inbox.channel.try(:voice_enabled?)
  end
end
