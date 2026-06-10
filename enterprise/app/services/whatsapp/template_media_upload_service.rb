class Whatsapp::TemplateMediaUploadService
  ALLOWED_MIME_TYPES = {
    'IMAGE' => %w[image/jpeg image/jpg image/png],
    'VIDEO' => %w[video/mp4],
    'DOCUMENT' => %w[application/pdf]
  }.freeze

  def initialize(channel)
    @channel = channel
    @access_token = channel.provider_config['api_key']
    @app_id = GlobalConfigService.load('WHATSAPP_APP_ID', '')
    @api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v14.0')
  end

  def upload(uploaded_file, header_format)
    return build_error('WHATSAPP_APP_ID is not configured') if @app_id.blank?
    return build_error('Invalid header format') unless ALLOWED_MIME_TYPES.key?(header_format)

    mime_type = uploaded_file.content_type.to_s
    return build_error('Unsupported file type for this header format') unless ALLOWED_MIME_TYPES[header_format].include?(mime_type)

    file_data = uploaded_file.read
    session_id = create_upload_session(file_data.bytesize, mime_type, uploaded_file.original_filename)
    handle = upload_file_binary(session_id, file_data, mime_type)

    { success: true, handle: handle }
  rescue StandardError => e
    Rails.logger.error "WhatsApp template media upload failed: #{e.message}"
    build_error(e.message)
  end

  private

  def create_upload_session(file_length, file_type, file_name)
    response = HTTParty.post(
      "#{api_base}/#{@app_id}/uploads",
      headers: api_headers,
      body: {
        file_length: file_length.to_s,
        file_type: file_type,
        file_name: file_name
      }.to_json
    )

    parsed = parse_response(response, 'Failed to create upload session')
    parsed['id'] || raise('Upload session id missing from Meta response')
  end

  def upload_file_binary(session_id, file_data, mime_type)
    response = HTTParty.post(
      "#{api_base}/#{session_id}",
      headers: {
        'Authorization' => "OAuth #{@access_token}",
        'file_offset' => '0',
        'Content-Type' => mime_type
      },
      body: file_data
    )

    parsed = parse_response(response, 'Failed to upload media file')
    parsed['h'] || raise('Media handle missing from Meta response')
  end

  def parse_response(response, fallback_message)
    parsed = response.parsed_response
    return parsed if response.success?

    error_message = parsed.is_a?(Hash) ? parsed.dig('error', 'error_user_msg') || parsed.dig('error', 'message') : nil
    raise(error_message.presence || fallback_message)
  end

  def api_base
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    "#{base}/#{@api_version}"
  end

  def api_headers
    {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json'
    }
  end

  def build_error(message)
    { success: false, error: message }
  end
end
