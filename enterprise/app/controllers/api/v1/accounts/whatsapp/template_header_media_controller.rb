class Api::V1::Accounts::Whatsapp::TemplateHeaderMediaController < Api::V1::Accounts::BaseController
  def create
    result = Disparador::MediaUploadService.new(
      account: Current.account,
      file: params[:file]
    ).perform

    render json: result, status: :created
  rescue Disparador::MediaUploadService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error("[WhatsAppTemplate] header media upload S3 error: #{e.message}")
    render json: { error: 'Media upload failed' }, status: :bad_gateway
  end
end
