class ConversationRedistributionService
  class ValidationError < StandardError; end

  REDISTRIBUTION_TYPES = %w[unassigned from_agent all_open].freeze
  STRATEGIES = %w[round_robin load_balance].freeze
  VALID_STATUSES = Conversation.statuses.keys.freeze
  MAX_CONVERSATIONS = 500
  DEFAULT_STATUSES = %w[open pending].freeze

  pattr_initialize [:account!, :params!]

  def simulate
    plan
  end

  def execute
    result = plan
    apply_plan!(result[:assignments])
    result
  end

  private

  def plan
    validate!
    conversations = fetch_conversations
    assignments = build_assignments(conversations)

    {
      total_conversations: conversations.size,
      agent_count: agents.size,
      summary: build_summary(assignments),
      assignments: serialize_assignments(assignments)
    }
  end

  def validate!
    raise ValidationError, 'inbox_id is required' if inbox_id.blank?
    raise ValidationError, 'Invalid redistribution type' unless REDISTRIBUTION_TYPES.include?(redistribution_type)
    raise ValidationError, 'Invalid strategy' unless STRATEGIES.include?(strategy)
    raise ValidationError, 'source_agent_id is required' if redistribution_type == 'from_agent' && source_agent_id.blank?
    raise ValidationError, 'At least one status is required' if statuses.blank?
    raise ValidationError, 'Invalid status' if (statuses - VALID_STATUSES).any?
    raise ValidationError, 'Select at least two agents' if agent_ids.size < 2
    raise ValidationError, 'Agents must belong to the inbox' unless agents.size == agent_ids.size

    if redistribution_type == 'from_agent' && !inbox.members.exists?(user_id: source_agent_id)
      raise ValidationError, 'Source agent must belong to the inbox'
    end
  end

  def fetch_conversations
    conversations = conversations_scope.includes(:assignee).order(:id).limit(MAX_CONVERSATIONS + 1).to_a
    if conversations.size > MAX_CONVERSATIONS
      raise ValidationError, "Maximum of #{MAX_CONVERSATIONS} conversations per redistribution"
    end

    conversations
  end

  def conversations_scope
    scope = account.conversations.where(inbox_id: inbox.id, status: statuses)

    case redistribution_type
    when 'unassigned'
      scope.unassigned
    when 'from_agent'
      scope.where(assignee_id: source_agent_id)
    else
      scope
    end
  end

  def build_assignments(conversations)
    case strategy
    when 'round_robin'
      distribute_round_robin(conversations)
    else
      distribute_load_balance(conversations)
    end
  end

  def distribute_round_robin(conversations)
    ordered_agents = agents.sort_by { |agent| agent_ids.index(agent.id) }
    conversations.each_with_index.map do |conversation, index|
      agent = ordered_agents[index % ordered_agents.size]
      [conversation, agent]
    end
  end

  def distribute_load_balance(conversations)
    loads = open_conversation_counts
    conversations.map do |conversation|
      agent = agents.min_by { |member| loads[member.id] }
      loads[agent.id] += 1
      [conversation, agent]
    end
  end

  def open_conversation_counts
    counts = account.conversations
                    .where(inbox_id: inbox.id, status: :open, assignee_id: agent_ids)
                    .group(:assignee_id)
                    .count

    agent_ids.index_with { |agent_id| counts[agent_id] || 0 }
  end

  def build_summary(assignments)
    counts = agent_ids.index_with { |_agent_id| 0 }

    assignments.each do |_conversation, agent|
      counts[agent.id] += 1
    end

    agents.sort_by { |agent| agent_ids.index(agent.id) }.map do |agent|
      {
        agent_id: agent.id,
        name: agent.name,
        count: counts[agent.id]
      }
    end
  end

  def serialize_assignments(assignments)
    assignments.map do |conversation, agent|
      {
        conversation_id: conversation.id,
        display_id: conversation.display_id,
        current_assignee: assignee_payload(conversation.assignee),
        new_assignee: assignee_payload(agent)
      }
    end
  end

  def assignee_payload(user)
    return nil if user.blank?

    { id: user.id, name: user.name }
  end

  def apply_plan!(assignments)
    conversation_ids = assignments.pluck(:conversation_id)
    conversations_by_id = conversations_scope.where(id: conversation_ids).index_by(&:id)
    agents_by_id = agents.index_by(&:id)

    if conversations_by_id.size != assignments.size
      raise ValidationError, 'Conversation set changed. Run simulation again.'
    end

    Conversation.transaction do
      assignments.each do |assignment|
        conversation = conversations_by_id[assignment[:conversation_id]]
        agent = agents_by_id[assignment[:new_assignee][:id]]
        conversation.update!(assignee: agent)
      end
    end
  end

  def inbox
    @inbox ||= account.inboxes.find(inbox_id)
  end

  def agents
    @agents ||= account.users
                       .joins(:inbox_members)
                       .where(inbox_members: { inbox_id: inbox.id }, users: { id: agent_ids })
                       .distinct
                       .to_a
                       .sort_by { |agent| agent_ids.index(agent.id) }
  end

  def inbox_id
    params[:inbox_id]
  end

  def redistribution_type
    params[:redistribution_type].to_s
  end

  def source_agent_id
    params[:source_agent_id].presence&.to_i
  end

  def statuses
    Array(params[:statuses]).presence || DEFAULT_STATUSES
  end

  def agent_ids
    @agent_ids ||= Array(params[:agent_ids]).map(&:to_i).uniq
  end

  def strategy
    params[:strategy].to_s
  end
end
