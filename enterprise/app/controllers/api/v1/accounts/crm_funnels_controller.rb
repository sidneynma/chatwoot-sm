class Api::V1::Accounts::CrmFunnelsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :fetch_funnel, only: [:show, :update, :destroy, :board, :move]
  before_action :ensure_funnel_accessible!, only: [:board, :move]
  before_action :check_authorization

  def index
    @crm_funnels = Current.account.crm_funnels.includes(stages: :label).order(:name)
    @crm_funnels = @crm_funnels.active unless include_inactive?
  end

  def show; end

  def create
    @crm_funnel = Current.account.crm_funnels.create!(funnel_params)
    sync_stages if stages_params.present?
    reload_funnel
  end

  def update
    @crm_funnel.update!(funnel_params)
    sync_stages if stages_params.present?
    reload_funnel
  end

  def destroy
    # Removes funnel configuration only. Conversations, contacts and labels are kept.
    @crm_funnel.destroy!
    head :ok
  end

  def board
    render json: { payload: board_service.perform }
  end

  def move
    render json: { payload: move_service.perform }
  rescue Crm::MoveConversationService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue Pundit::NotAuthorizedError
    render json: { error: 'You are not authorized to move this conversation' }, status: :forbidden
  end

  private

  def fetch_funnel
    @crm_funnel = Current.account.crm_funnels.includes(stages: :label).find(params[:id])
  end

  def funnel_params
    params.require(:crm_funnel).permit(:name, :inbox_id, :active)
  end

  def stages_params
    params.dig(:crm_funnel, :stages)
  end

  def sync_stages
    permitted_stages = stages_params.map do |stage|
      stage.permit(:label_id, :position).to_h.symbolize_keys
    end

    Crm::FunnelStagesSyncService.new(
      funnel: @crm_funnel,
      stages_params: permitted_stages
    ).perform
  rescue Crm::FunnelStagesSyncService::ValidationError => e
    raise ActiveRecord::RecordInvalid.new(@crm_funnel.tap { |f| f.errors.add(:base, e.message) })
  end

  def reload_funnel
    @crm_funnel = Current.account.crm_funnels.includes(stages: :label).find(@crm_funnel.id)
  end

  def board_service
    Crm::BoardQueryService.new(
      funnel: @crm_funnel,
      user: Current.user,
      account: Current.account,
      params: board_params
    )
  end

  def move_service
    Crm::MoveConversationService.new(
      funnel: @crm_funnel,
      user: Current.user,
      account: Current.account,
      params: move_params
    )
  end

  def board_params
    params.permit(:assignee_type, :status, :page)
  end

  def move_params
    params.permit(:conversation_id, :stage_id)
  end

  def include_inactive?
    Current.account_user.administrator? && params[:include_inactive] == 'true'
  end

  def ensure_funnel_accessible!
    return if @crm_funnel.active? || Current.account_user.administrator?

    render json: { error: 'Funnel is inactive' }, status: :forbidden
  end
end
