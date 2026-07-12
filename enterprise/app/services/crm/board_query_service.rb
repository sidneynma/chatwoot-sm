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
    funnel.stages.includes(:label, :responsible_team).map do |stage|
      conversations, total_count = stage_conversations(stage, page: 1)
      {
        id: stage.id,
        position: stage.position,
        label: label_payload(stage.label),
        responsible_team: team_payload(stage.responsible_team),
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

    apply_agent_filter(scope)
  end

  def apply_admin_filter(scope)
    case assignee_type
    when 'me'
      scope.assigned_to(user)
    when 'my_team'
      return scope.none if user_team_ids.blank?

      scope.where(team_id: user_team_ids)
    else
      scope
    end
  end

  def apply_agent_filter(scope)
    inbox_ids = user.inboxes.where(account_id: account.id).pluck(:id)

    # Inbox membership OR CRM handoff team — without requiring inbox for back-office teams.
    scope = if inbox_ids.present? && user_team_ids.present?
              scope.where('inbox_id IN (:inbox_ids) OR team_id IN (:team_ids)',
                          inbox_ids: inbox_ids, team_ids: user_team_ids)
            elsif inbox_ids.present?
              scope.where(inbox_id: inbox_ids)
            elsif user_team_ids.present?
              scope.where(team_id: user_team_ids)
            else
              scope.none
            end

    case assignee_type
    when 'my_team'
      return scope.none if user_team_ids.blank?

      scope.where(team_id: user_team_ids)
    when 'all'
      # Agents must not use "all". Fall back to own + team queue.
      if user_team_ids.present?
        scope.where('assignee_id = :uid OR team_id IN (:team_ids)', uid: user.id, team_ids: user_team_ids)
      else
        scope.assigned_to(user)
      end
    else
      # Default "me": assigned to me OR currently handed to one of my teams.
      if user_team_ids.present?
        scope.where('assignee_id = :uid OR team_id IN (:team_ids)', uid: user.id, team_ids: user_team_ids)
      else
        scope.assigned_to(user)
      end
    end
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
