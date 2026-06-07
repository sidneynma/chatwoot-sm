class Whatsapp::TemplatesManagementService
  WHATSAPP_API_VERSION = 'v14.0'.freeze
  DEFAULT_CATEGORY = 'UTILITY'.freeze
  DEFAULT_LANGUAGE = 'pt_BR'.freeze

  def initialize(channel)
    @channel = channel
  end

  def create(params)
    request_body = {
      name: params[:name],
      category: params[:category].presence || DEFAULT_CATEGORY,
      language: params[:language].presence || DEFAULT_LANGUAGE,
      components: build_components(params)
    }

    response = HTTParty.post(
      "#{business_account_path}/message_templates",
      headers: api_headers,
      body: request_body.to_json
    )
    build_result(response)
  end

  def delete(name)
    response = HTTParty.delete(
      "#{business_account_path}/message_templates?name=#{name}",
      headers: api_headers
    )
    build_result(response)
  end

  private

  def build_components(params)
    components = []
    components << { type: 'HEADER', format: 'TEXT', text: params[:header_text] } if params[:header_text].present?
    components << build_body_component(params)
    components << { type: 'FOOTER', text: params[:footer_text] } if params[:footer_text].present?
    components
  end

  def build_body_component(params)
    body = { type: 'BODY', text: params[:body_text] }
    examples = Array(params[:body_examples]).map(&:to_s).reject(&:blank?)
    body[:example] = { body_text: [examples] } if examples.present?
    body
  end

  def build_result(response)
    { success: response.success?, body: response.parsed_response }
  end

  def business_account_path
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    "#{base}/#{WHATSAPP_API_VERSION}/#{@channel.provider_config['business_account_id']}"
  end

  def api_headers
    {
      'Authorization' => "Bearer #{@channel.provider_config['api_key']}",
      'Content-Type' => 'application/json'
    }
  end
end
