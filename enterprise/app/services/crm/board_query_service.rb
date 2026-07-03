class Crm::BoardQueryService
  PER_PAGE = 20

  pattr_initialize [:funnel!, :user!, :account!, :params]

  def perform
    {
      funnel: funnel_payload,
      stages: stages_payload
    }
  end

  private

  def funnel_payload
    {
      id: funnel.id,
      name: funnel.name,
      inbox_id: funnel.inbox_id,
      active: funnel.active
    }
  end

  def stages_payload
    funnel.stages.includes(:label).map do |stage|
      conversations, total_count = stage_conversations(stage)
      {
        id: stage.id,
        position: stage.position,
        label: label_payload(stage.label),
        total_count: total_count,
        conversations: conversations
      }
    end
  end

  def stage_conversations(stage)
    scope = base_scope.tagged_with(stage.label.title, any: true)
    total_count = scope.count
    paginated = scope.sort_on_last_activity_at.page(page).per(PER_PAGE)

    [serialize_conversations(paginated), total_count]
  end

  def base_scope
    scope = account.conversations.includes(
      :taggings, :inbox,
      { assignee: { avatar_attachment: [:blob] } },
      { contact: { avatar_attachment: [:blob] } }
    )
    scope = scope.where(inbox_id: funnel.inbox_id) if funnel.inbox_id.present?
    scope = Conversations::PermissionFilterService.new(scope, user, account).perform
    scope = scope.assigned_to(user) unless administrator? && assignee_type == 'all'
    scope = scope.where(status: status) if status.present? && status != 'all'
    scope
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
        last_message: last_message_payload(conversation)
      }
    end
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
