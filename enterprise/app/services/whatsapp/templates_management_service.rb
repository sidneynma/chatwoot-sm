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
    request_body[:parameter_format] = params[:parameter_format] if params[:parameter_format].present?

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
    components << build_header_component(params) if header_component?(params)
    components << build_body_component(params)
    components << { type: 'FOOTER', text: params[:footer_text] } if params[:footer_text].present?
    components << build_buttons_component(params) if buttons_component?(params)
    components
  end

  def header_component?(params)
    location_header_format?(params) || media_header_format?(params) || params[:header_text].present?
  end

  def location_header_format?(params)
    params[:header_format].to_s == 'LOCATION'
  end

  def media_header_format?(params)
    %w[IMAGE VIDEO DOCUMENT].include?(params[:header_format].to_s)
  end

  def build_header_component(params)
    return { type: 'HEADER', format: 'LOCATION' } if location_header_format?(params)
    return build_media_header_component(params) if media_header_format?(params)

    header = { type: 'HEADER', format: 'TEXT', text: params[:header_text] }
    attach_component_examples(header, params[:header_text], params, :header)
    header
  end

  def build_media_header_component(params)
    {
      type: 'HEADER',
      format: params[:header_format],
      example: { header_handle: [params[:header_handle]] }
    }
  end

  def build_body_component(params)
    body = { type: 'BODY', text: params[:body_text] }
    attach_component_examples(body, params[:body_text], params, :body)
    body
  end

  def buttons_component?(params)
    Array(params[:buttons]).any?
  end

  def build_buttons_component(params)
    buttons = Array(params[:buttons]).filter_map { |button| build_button(button) }
    return if buttons.blank?

    { type: 'BUTTONS', buttons: buttons }
  end

  def build_button(button)
    button = button.to_h.with_indifferent_access
    case button[:type].to_s
    when 'QUICK_REPLY'
      { type: 'QUICK_REPLY', text: button[:text] }
    when 'URL'
      build_url_button(button)
    when 'PHONE_NUMBER'
      { type: 'PHONE_NUMBER', text: button[:text], phone_number: button[:phone_number] }
    end
  end

  def build_url_button(button)
    url_button = {
      type: 'URL',
      text: button[:text],
      url: button[:url]
    }
    return url_button unless button[:url].to_s.match?(/\{\{[^}]+\}\}/)

    examples = Array(button[:example]).presence || Array(button[:url_example]).presence
    url_button[:example] = examples.map(&:to_s) if examples.present?
    url_button
  end

  def attach_component_examples(component, text, params, component_type)
    variables = extract_variables(text)
    return if variables.blank?

    examples = variable_examples_map(params)
    return if examples.blank?

    if params[:parameter_format] == 'NAMED'
      named_params = variables.map do |variable|
        { param_name: variable, example: examples[variable] }
      end
      example_key = component_type == :header ? :header_text_named_params : :body_text_named_params
      component[:example] = { example_key => named_params }
    else
      positional_examples = variables.map { |variable| examples[variable] }
      example_key = component_type == :header ? :header_text : :body_text
      value = component_type == :body ? [positional_examples] : positional_examples
      component[:example] = { example_key => value }
    end
  end

  def extract_variables(text)
    text.to_s.scan(/\{\{([^}]+)\}\}/).flatten.map(&:strip).uniq
  end

  def variable_examples_map(params)
    examples = (params[:variable_examples] || {}).to_h.transform_keys(&:to_s)
    return examples.reject { |_, value| value.blank? } if examples.present?

    Array(params[:body_examples]).each_with_index.to_h { |example, index| [(index + 1).to_s, example.to_s] }
      .reject { |_, value| value.blank? }
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
