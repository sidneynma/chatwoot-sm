# Renders session message text with {{vars}} for Chatolhe API (Evolution) campaigns.
class Disparador::RenderMessageService
  pattr_initialize [:template!, :recipient!, :agent_name]

  def perform
    vars = build_vars
    template.to_s.gsub(/\{\{\s*([^}]+)\s*\}\}/) do |match|
      key = Regexp.last_match(1).to_s.strip
      value = vars[key]
      value.present? ? value.to_s : match
    end
  end

  private

  def build_vars
    body_params = (recipient.metadata&.dig('template_params', 'body') || {}).stringify_keys
    extra_vars = (recipient.metadata&.dig('vars') || {}).stringify_keys
    first_name = recipient.name.to_s.strip.split(/\s+/).first.to_s

    {
      'name' => recipient.name.to_s,
      'nome' => recipient.name.to_s,
      'phone' => recipient.phone.to_s,
      'email' => recipient.email.to_s,
      'agent' => agent_name.to_s,
      'agente' => agent_name.to_s,
      'agent_name' => agent_name.to_s,
      '1' => first_name
    }.merge(body_params).merge(extra_vars)
  end
end
