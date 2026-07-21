class Api::V1::Accounts::DisparadorSchedulesController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_schedules_module_enabled!
  before_action :check_authorization

  def index
    result = service.list(
      status: params[:status],
      conversation_id: params[:conversation_id],
      limit: params[:limit],
      offset: params[:offset]
    )
    render json: result
  end

  def create
    payload = service.create!(schedule_params)
    render json: { payload: payload }, status: :created
  rescue Disparador::ScheduleService::Error => e
    render json: { error: e.message }, status: e.status
  end

  def update
    payload = service.update!(params[:id], schedule_update_params)
    render json: { payload: payload }
  rescue Disparador::ScheduleService::Error => e
    render json: { error: e.message }, status: e.status
  end

  def destroy
    payload = service.cancel!(params[:id])
    render json: { payload: payload }
  rescue Disparador::ScheduleService::Error => e
    render json: { error: e.message }, status: e.status
  end

  private

  def service
    @service ||= Disparador::ScheduleService.new(account: Current.account, user: Current.user)
  end

  def schedule_params
    raw = params.to_unsafe_h.with_indifferent_access
    {
      conversation_id: raw[:conversation_id],
      inbox_id: raw[:inbox_id],
      inbox_name: raw[:inbox_name],
      contact_id: raw[:contact_id],
      phone: raw[:phone],
      name: raw[:name],
      scheduled_at: raw[:scheduled_at],
      channel: raw[:channel],
      message_type: raw[:message_type],
      message: raw[:message],
      template_header_url: raw[:template_header_url],
      template_param_values: Array(raw[:template_param_values]),
      template: (raw[:template] || {}).to_h,
      media: (raw[:media] || {}).to_h
    }
  end

  def schedule_update_params
    params.permit(:scheduled_at, :message).to_h.deep_symbolize_keys
  end

  def check_authorization
    authorize(DisparadorCampaign, :index?)
  end

  def ensure_schedules_module_enabled!
    return if Current.account.chatolhe_module_enabled?('mensagens_agendadas')

    render json: { error: 'Mensagens Agendadas module is not enabled for this account' }, status: :forbidden
  end
end
