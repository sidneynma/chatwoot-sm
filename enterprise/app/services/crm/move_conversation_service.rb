class Crm::MoveConversationService
  class ValidationError < StandardError; end

  pattr_initialize [:funnel!, :user!, :account!, :params]

  def perform
    validate_params!
    authorize_conversation!
    validate_assignee!

    conversation.update!(label_list: updated_labels)

    {
      conversation_id: conversation.display_id,
      labels: conversation.cached_label_list_array
    }
  end

  private

  def validate_params!
    raise ValidationError, 'Conversation is required' if conversation.blank?
    raise ValidationError, 'Target stage is required' if target_stage.blank?
    raise ValidationError, 'Target stage does not belong to this funnel' if target_stage.crm_funnel_id != funnel.id
  end

  def authorize_conversation!
    Pundit.authorize(pundit_user, conversation, :show?, policy_class: ConversationPolicy)
  end

  def validate_assignee!
    return if account_user&.administrator?
    return if conversation.assignee_id == user.id

    raise ValidationError, 'You can only move conversations assigned to you'
  end

  def pundit_user
    {
      user: user,
      account: account,
      account_user: account_user
    }
  end

  def account_user
    @account_user ||= AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def updated_labels
    funnel_label_titles = funnel.stage_label_titles
    remaining_labels = conversation.cached_label_list_array - funnel_label_titles
    remaining_labels + [target_stage.label.title]
  end

  def conversation
    @conversation ||= account.conversations.find_by(display_id: params[:conversation_id])
  end

  def target_stage
    @target_stage ||= funnel.stages.find_by(id: params[:stage_id])
  end
end
