class Crm::BoardQueryService
  PER_PAGE = 20

  pattr_initialize [:funnel!, :user!, :account!, :params]

  def perform
    return stage_page_payload if params[:stage_id].present?

    {
      funnel: funnel_payload,
      stages: stages_payload
    }
  end

  private

  def stage_page_payload
    stage = funnel.stages.find_by(id: params[:stage_id])
    raise ActiveRecord::RecordNotFound, 'Stage not found' if stage.blank?

    conversations, total_count = stage_conversations(stage)
    current_page = page.to_i

    {
      stage_id: stage.id,
      conversations: conversations,
      total_count: total_count,
      page: current_page,
      has_more: total_count > (current_page * PER_PAGE)
    }
  end

  def funnel_payload
    {
      id: funnel.id,
      name: funnel.name,
      inbox_id: funnel.inbox_id,
      active: funnel.active
    }
  end

  def stages_payload
    team_map = responsible_teams_by_id

    funnel.stages.includes(:label, :responsible_team).map do |stage|
      conversations, total_count = stage_conversations(stage, page: 1)
      team_ids = stage.responsible_team_ids_list
      {
        id: stage.id,
        position: stage.position,
        label: label_payload(stage.label),
        responsible_team_id: stage.primary_responsible_team_id,
        responsible_team_ids: team_ids,
        responsible_team: team_payload(team_map[stage.primary_responsible_team_id]),
        responsible_teams: team_ids.filter_map { |id| team_payload(team_map[id]) },
        can_resolve: stage.can_resolve,
        auto_resolve_on_enter: stage.auto_resolve_on_enter,
        clear_assignment_on_resolve: stage.clear_assignment_on_resolve,
        total_count: total_count,
        conversations: conversations,
        has_more: total_count > conversations.length
      }
    end
  end

  def stage_conversations(stage, page: nil)
    scope = base_scope.tagged_with(stage.label.title, any: true)
    total_count = scope.count
    current_page = page || self.page
    paginated = scope.sort_on_last_activity_at.page(current_page).per(PER_PAGE)

    [serialize_conversations(paginated), total_count]
  end

  def base_scope
    scope = account.conversations.includes(
      :taggings, :inbox, :team,
      { assignee: { avatar_attachment: [:blob] } },
      { contact: { avatar_attachment: [:blob] } }
    )
    scope = scope.where(inbox_id: funnel.inbox_id) if funnel.inbox_id.present?
    scope = apply_visibility(scope)
    scope = scope.where(status: status) if status.present? && status != 'all'
    scope
  end

  def apply_visibility(scope)
    return apply_admin_filter(scope) if administrator?
    return apply_custom_role_filter(scope) if custom_role_agent?

    apply_agent_filter(scope)
  end

  def apply_admin_filter(scope)
    case assignee_type
    when 'me'
      scope.assigned_to(user)
    when 'my_team'
      return scope.none if user_team_ids.blank?

      team_or_stage_handoff_scope(scope)
    else
      scope
    end
  end

  # Custom roles reuse inbox PermissionFilterService, then keep CRM team handoff (OR).
  # Only conversation_manage may use assignee_type=all; others fall back to me + team.
  def apply_custom_role_filter(scope)
    filtered = Conversations::PermissionFilterService.new(scope, user, account).perform
    combined = union_with_team_handoff(scope, filtered)

    case assignee_type
    when 'my_team'
      return scope.none if user_team_ids.blank?

      team_or_stage_handoff_scope(combined)
    when 'all'
      return combined if conversation_manage?

      me_or_team_scope(combined)
    else
      me_or_team_scope(combined)
    end
  end

  def apply_agent_filter(scope)
    inbox_ids = user.inboxes.where(account_id: account.id).pluck(:id)

    # Inbox membership OR CRM handoff (assigned team_id OR stage multi-team labels).
    scope = if inbox_ids.present? && user_team_ids.present?
              inbox_scope = scope.where(inbox_id: inbox_ids)
              handoff_scope = team_or_stage_handoff_scope(scope)
              union_scopes(scope, inbox_scope, handoff_scope)
            elsif inbox_ids.present?
              scope.where(inbox_id: inbox_ids)
            elsif user_team_ids.present?
              team_or_stage_handoff_scope(scope)
            else
              scope.none
            end

    case assignee_type
    when 'my_team'
      return scope.none if user_team_ids.blank?

      team_or_stage_handoff_scope(scope)
    when 'all'
      # Agents must not use "all". Fall back to own + team queue.
      me_or_team_scope(scope)
    else
      # Default "me": assigned to me OR currently handed to one of my teams.
      me_or_team_scope(scope)
    end
  end

  def union_with_team_handoff(original_scope, filtered)
    return filtered if user_team_ids.blank?

    union_scopes(original_scope, filtered, team_or_stage_handoff_scope(original_scope))
  end

  def me_or_team_scope(scope)
    if user_team_ids.present?
      union_scopes(scope, scope.assigned_to(user), team_or_stage_handoff_scope(scope))
    else
      scope.assigned_to(user)
    end
  end

  # Conversations with team_id in my teams OR tagged with a funnel stage where I am a responsible team.
  def team_or_stage_handoff_scope(scope)
    return scope.none if user_team_ids.blank?

    by_team = scope.where(team_id: user_team_ids)
    titles = stage_handoff_label_titles
    return by_team if titles.blank?

    union_scopes(scope, by_team, scope.tagged_with(titles, any: true))
  end

  def stage_handoff_label_titles
    @stage_handoff_label_titles ||= funnel.stages
                                         .select { |stage| stage.responsible_team_ids_include_any?(user_team_ids) }
                                         .filter_map { |stage| stage.label&.title }
  end

  def union_scopes(base_scope, *scopes)
    id_union = scopes.map { |relation| "(#{relation.reselect('conversations.id').to_sql})" }.join(' UNION ')
    base_scope.where(
      "conversations.id IN (SELECT id FROM (#{id_union}) AS crm_union_ids)"
    )
  end

  def responsible_teams_by_id
    ids = funnel.stages.flat_map(&:responsible_team_ids_list).uniq
    return {} if ids.blank?

    account.teams.where(id: ids).index_by(&:id)
  end

  def serialize_conversations(conversations)
    conversations.map do |conversation|
      {
        id: conversation.display_id,
        inbox_id: conversation.inbox_id,
        status: conversation.status,
        labels: conversation.cached_label_list_array,
        timestamp: conversation.last_activity_at.to_i,
        unread_count: conversation.unread_incoming_messages.count,
        contact: contact_payload(conversation),
        assignee: assignee_payload(conversation),
        team: team_payload(conversation.team),
        last_message: last_message_payload(conversation),
        read_only: read_only_for?(conversation)
      }
    end
  end

  def read_only_for?(conversation)
    Crm::ConversationAccess.new(
      user: user,
      account: account,
      conversation: conversation
    ).team_only?
  end

  def contact_payload(conversation)
    contact = conversation.contact
    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number,
      thumbnail: contact.avatar_url
    }
  end

  def assignee_payload(conversation)
    assignee = conversation.assignee
    return nil if assignee.blank?

    {
      id: assignee.id,
      name: assignee.name,
      thumbnail: assignee.avatar_url
    }
  end

  def team_payload(team)
    return nil if team.blank?

    { id: team.id, name: team.name }
  end

  def last_message_payload(conversation)
    message = conversation.messages.where(account_id: account.id).non_activity_messages.last
    return nil if message.blank?

    {
      content: message.content,
      created_at: message.created_at.to_i
    }
  end

  def label_payload(label)
    {
      id: label.id,
      title: label.title,
      color: label.color
    }
  end

  def user_team_ids
    @user_team_ids ||= user.teams.where(account_id: account.id).pluck(:id)
  end

  def assignee_type
    params[:assignee_type].presence || 'me'
  end

  def administrator?
    account_user&.administrator?
  end

  def custom_role_agent?
    account_user&.agent? && account_user.custom_role_id.present?
  end

  def conversation_manage?
    account_user&.permissions&.include?('conversation_manage')
  end

  def account_user
    @account_user ||= AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def status
    params[:status].presence || 'open'
  end

  def page
    params[:page] || 1
  end
end
