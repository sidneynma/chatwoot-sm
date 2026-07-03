class Crm::FunnelStagesSyncService
  class ValidationError < StandardError; end

  pattr_initialize [:funnel!, :stages_params!]

  def perform
    validate_stages!
    CrmFunnelStage.transaction do
      funnel.stages.destroy_all
      stages_params.each_with_index do |stage_param, index|
        funnel.stages.create!(
          label_id: stage_param[:label_id],
          position: stage_param[:position].presence || index
        )
      end
    end
    funnel.stages.includes(:label).reload
  end

  private

  def validate_stages!
    label_ids = stages_params.map { |stage| stage[:label_id].to_i }
    raise ValidationError, 'Duplicate labels in funnel stages' if label_ids.uniq.length != label_ids.length

    account_label_ids = funnel.account.labels.where(id: label_ids).pluck(:id)
    raise ValidationError, 'Invalid label for this account' if (label_ids - account_label_ids).any?
  end
end
