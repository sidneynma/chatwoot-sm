class Api::V1::Accounts::ConversationRedistributionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def simulate
    render json: service.simulate
  rescue ConversationRedistributionService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def execute
    render json: service.execute.merge(success: true)
  rescue ConversationRedistributionService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def service
    @service ||= ConversationRedistributionService.new(
      account: Current.account,
      params: redistribution_params
    )
  end

  def redistribution_params
    params.permit(
      :inbox_id,
      :redistribution_type,
      :source_agent_id,
      :strategy,
      statuses: [],
      agent_ids: []
    )
  end
end
