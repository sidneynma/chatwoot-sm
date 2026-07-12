class Crm::HandoffService
  pattr_initialize [:conversation!, :target_stage!, :funnel!]

  def perform
    case_state = find_or_build_case_state

    if target_stage.auto_resolve_on_enter?
      apply_auto_resolve!(case_state)
      return
    end

    if target_stage.responsible_team_id.present?
      enter_team_stage!(case_state)
    else
      leave_team_stage!(case_state)
    end
  end

  private

  def find_or_build_case_state
    CrmCaseState.find_or_initialize_by(
      conversation_id: conversation.id,
      crm_funnel_id: funnel.id
    ) do |state|
      state.account_id = funnel.account_id
    end
  end

  def enter_team_stage!(case_state)
    unless case_state.in_handoff?
      case_state.previous_assignee_id = conversation.assignee_id
      case_state.previous_team_id = conversation.team_id
      case_state.in_handoff = true
    end
    case_state.save!

    conversation.update!(team_id: target_stage.responsible_team_id)
  end

  def leave_team_stage!(case_state)
    return unless case_state.persisted? && case_state.in_handoff?

    conversation.update!(team_id: case_state.previous_team_id)
    case_state.update!(
      in_handoff: false,
      previous_assignee_id: nil,
      previous_team_id: nil
    )
  end

  def apply_auto_resolve!(case_state)
    attrs = { status: :resolved }
    if target_stage.clear_assignment_on_resolve?
      attrs[:assignee_id] = nil
      attrs[:team_id] = nil
    end

    conversation.update!(attrs)
    case_state.destroy! if case_state.persisted?
  end
end
