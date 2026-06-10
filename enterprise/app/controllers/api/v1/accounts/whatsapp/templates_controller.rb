class Api::V1::Accounts::Whatsapp::TemplatesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_whatsapp_inbox

  def index
    channel = @inbox.channel

    render json: {
      inbox_id: @inbox.id,
      inbox_name: @inbox.name,
      provider: channel.provider,
      message_templates_last_updated: channel.message_templates_last_updated,
      message_templates: normalize_templates(channel.message_templates)
    }
  end

  def create
    return render_provider_not_supported unless cloud_provider?

    result = templates_service.create(template_params)
    return render_meta_error(result) unless result[:success]

    @inbox.channel.sync_templates
    render json: { message: 'Template created successfully', message_templates: normalize_templates(@inbox.channel.reload.message_templates) }, status: :created
  end

  def destroy
    return render_provider_not_supported unless cloud_provider?

    result = templates_service.delete(params[:id])
    return render_meta_error(result) unless result[:success]

    @inbox.channel.sync_templates
    render json: { message: 'Template deleted successfully', message_templates: normalize_templates(@inbox.channel.reload.message_templates) }
  end

  def upload_media
    return render_provider_not_supported unless cloud_provider?
    return render json: { error: 'file is required' }, status: :bad_request if params[:file].blank?
    return render json: { error: 'header_format is required' }, status: :bad_request if params[:header_format].blank?

    result = media_upload_service.upload(params[:file], params[:header_format])
    return render json: { error: result[:error] }, status: :unprocessable_entity unless result[:success]

    render json: { header_handle: result[:handle] }
  end

  private

  def fetch_whatsapp_inbox
    if params[:inbox_id].blank?
      render json: { error: 'inbox_id is required' }, status: :bad_request
      return
    end

    @inbox = Current.account.inboxes.find(params[:inbox_id])
    return if @inbox.whatsapp?

    render json: { error: 'Templates are only available for WhatsApp inboxes' }, status: :bad_request
  end

  def templates_service
    @templates_service ||= Whatsapp::TemplatesManagementService.new(@inbox.channel)
  end

  def media_upload_service
    @media_upload_service ||= Whatsapp::TemplateMediaUploadService.new(@inbox.channel)
  end

  def cloud_provider?
    @inbox.channel.provider == 'whatsapp_cloud'
  end

  def template_params
    params.require(:template).permit(
      :name, :category, :language, :parameter_format,
      :header_format, :header_handle, :header_text, :body_text, :footer_text,
      body_examples: [],
      variable_examples: {}
    )
  end

  def render_provider_not_supported
    render json: { error: 'Template management is only available for WhatsApp Cloud API inboxes' }, status: :unprocessable_entity
  end

  def render_meta_error(result)
    error = result[:body].is_a?(Hash) ? result[:body]['error'] : nil
    message = error&.dig('error_user_msg') || error&.dig('message') || 'Template operation failed'
    render json: { error: message }, status: :unprocessable_entity
  end

  def normalize_templates(raw)
    return [] if raw.blank?
    return raw if raw.is_a?(Array)

    []
  end
end
