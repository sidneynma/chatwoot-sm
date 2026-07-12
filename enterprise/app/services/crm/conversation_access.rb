class Crm::ConversationAccess
  pattr_initialize [:user!, :account!, :conversation!]

  def inbox_member?
    user.inboxes.where(account_id: account.id).exists?(id: conversation.inbox_id)
  end

  def team_member?
    return false if conversation.team_id.blank?

    user.teams.where(account_id: account.id).exists?(id: conversation.team_id)
  end

  def team_only?
    team_member? && !inbox_member? && !administrator?
  end

  def can_reply_publicly?
    administrator? || inbox_member?
  end

  def can_create_private_note?
    administrator? || inbox_member? || team_member?
  end

  def can_resolve?
    return true if administrator? || inbox_member?
    return false unless team_member?

    resolvable_stage_for_user.present?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def account_user
    @account_user ||= AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def resolvable_stage_for_user
    titles = conversation.cached_label_list_array
    return if titles.blank? || user_team_ids.blank?

    CrmFunnelStage.joins(:crm_funnel, :label)
                  .where(crm_funnels: { account_id: account.id })
                  .where(can_resolve: true, responsible_team_id: user_team_ids)
                  .where(labels: { title: titles })
                  .exists?
  end

  def user_team_ids
    @user_team_ids ||= user.teams.where(account_id: account.id).pluck(:id)
  end
end
