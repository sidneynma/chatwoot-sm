class Crm::FunnelStagesSyncService
  class ValidationError < StandardError; end

  pattr_initialize [:funnel!, :stages_params!]

  def perform
    validate_stages!
    CrmFunnelStage.transaction do
      funnel.stages.destroy_all
      stages_params.each_with_index do |stage_param, index|
        funnel.stages.create!(stage_attributes(stage_param, index))
      end
    end
    funnel.stages.includes(:label, :responsible_team).reload
  end

  private

  def stage_attributes(stage_param, index)
    {
      label_id: stage_param[:label_id],
      position: stage_param[:position].presence || index,
      responsible_team_id: stage_param[:responsible_team_id].presence,
      can_resolve: ActiveModel::Type::Boolean.new.cast(stage_param.fetch(:can_resolve, false)),
      auto_resolve_on_enter: ActiveModel::Type::Boolean.new.cast(stage_param.fetch(:auto_resolve_on_enter, false)),
      clear_assignment_on_resolve: ActiveModel::Type::Boolean.new.cast(
        stage_param.fetch(:clear_assignment_on_resolve, true)
      )
    }
  end

  def validate_stages!
    label_ids = stages_params.map { |stage| stage[:label_id].to_i }
    raise ValidationError, 'Duplicate labels in funnel stages' if label_ids.uniq.length != label_ids.length

    account_label_ids = funnel.account.labels.where(id: label_ids).pluck(:id)
    raise ValidationError, 'Invalid label for this account' if (label_ids - account_label_ids).any?

    team_ids = stages_params.filter_map { |stage| stage[:responsible_team_id].presence&.to_i }
    return if team_ids.blank?

    account_team_ids = funnel.account.teams.where(id: team_ids).pluck(:id)
    raise ValidationError, 'Invalid team for this account' if (team_ids - account_team_ids).any?
  end
end
