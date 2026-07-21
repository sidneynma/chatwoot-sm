class Api::V1::Accounts::DisparadorMediaController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_disparador_module_enabled!

  def create
    authorize(DisparadorCampaign, :create?)

    result = Disparador::MediaUploadService.new(
      account: Current.account,
      file: params[:file] || params[:attachment]
    ).perform

    render json: result, status: :created
  rescue Disparador::MediaUploadService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error("[Disparador] media upload S3 error: #{e.message}")
    render json: { error: 'Media upload failed' }, status: :bad_gateway
  end

  private

  def ensure_disparador_module_enabled!
    return if Current.account.chatolhe_module_enabled?('disparador')

    render json: { error: 'Disparador module is not enabled for this account' }, status: :forbidden
  end
end
