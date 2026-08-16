class Disparador::ScheduleService
  SOURCE = 'conversation_schedule'

  class Error < StandardError
    attr_reader :status

    def initialize(message, status: 400)
      super(message)
      @status = status
    end
  end

  pattr_initialize [:account!, :user!]

  def list(status: nil, conversation_id: nil, limit: 100, offset: 0)
    scope = base_scope
    scope = scope.where(conversation_id: conversation_id) if conversation_id.present?
    scope = filter_own(scope)
    scope = filter_status(scope, status)
    scope = scope.order(Arel.sql('COALESCE(disparador_recipients.scheduled_at, disparador_recipients.created_at) DESC'))
                 .limit([limit.to_i, 200].min)
                 .offset(offset.to_i)

    {
      payload: scope.map { |recipient| serialize(recipient) },
      scope: filter_to_own? ? 'mine' : 'all'
    }
  end

  def create!(params)
    conversation_ref = params[:conversation_id].presence
    inbox_id = params[:inbox_id].presence
    phone = params[:phone].to_s.strip
    raise Error.new('conversation_id, inbox_id e phone são obrigatórios', status: 400) if conversation_ref.blank? || inbox_id.blank? || phone.blank?

    conversation = find_conversation(conversation_ref)
    raise Error.new('Conversa não encontrada', status: 404) if conversation.blank?

    # UI sends Chatwoot display_id; keep that value so schedules list/links stay consistent.
    conversation_id = conversation.display_id

    scheduled_at = parse_scheduled_at(params[:scheduled_at])
    raise Error.new('scheduled_at é obrigatório', status: 400) if scheduled_at.blank?

    channel = params[:channel].to_s.downcase == 'evolution' ? 'evolution' : 'whatsapp'
    is_evolution = channel == 'evolution'
    message_type = params[:message_type].presence || (is_evolution ? 'text' : 'template')
    message = params[:message].to_s
    media = params[:media].presence || {}

    if is_evolution
      media_url = media['media_url'] || media[:media_url]
      raise Error.new('Informe a mensagem ou anexe uma mídia', status: 400) if message.blank? && media_url.blank?
    elsif message_type == 'template'
      template = params[:template].presence || {}
      raise Error.new('template.name e template.language são obrigatórios', status: 400) if template['name'].blank? && template[:name].blank?
    end

    name = params[:name].presence || phone
    campaign_name = "Agendamento · #{name}"
    inbox = account.inboxes.find(inbox_id)
    agent_name = user.name

    campaign_metadata = {
      'source' => SOURCE,
      'agent_name' => agent_name,
      'conversation_id' => conversation_id,
      'inbox_name' => params[:inbox_name].presence || inbox.name,
      'dispatch_mode' => is_evolution ? 'evolution' : 'conversation'
    }

    message_template = message
    if is_evolution
      campaign_metadata['evolution_instance'] = campaign_metadata['inbox_name']
      if media['media_url'] || media[:media_url]
        campaign_metadata['media'] = {
          'media_url' => media['media_url'] || media[:media_url],
          'media_type' => media['media_type'] || media[:media_type] || 'image',
          'filename' => media['filename'] || media[:filename]
        }.compact
      end
    else
      template_snapshot = build_template_snapshot(params)
      campaign_metadata['template'] = template_snapshot
      message_template = message.presence || template_snapshot['body_text'].to_s
    end

    body_params = is_evolution ? {} : build_template_params_body(params[:template_param_values])
    contact_first = name.to_s.strip.split(/\s+/).first
    body_params['1'] = contact_first if contact_first.present? && body_params['1'].blank?

    recipient = nil
    campaign = nil
    ActiveRecord::Base.transaction do
      campaign = account.disparador_campaigns.create!(
        inbox_id: inbox.id,
        name: campaign_name,
        channel: channel,
        status: 'scheduled',
        scheduled_at: scheduled_at,
        message_template: message_template,
        created_by_id: user.id,
        created_by_email: user.email,
        metadata: campaign_metadata
      )

      recipient_meta = {
        'message_type' => is_evolution ? 'text' : message_type,
        'template_params' => { 'body' => body_params },
        'message_preview' => message.presence,
        'use_existing_conversation' => true
      }
      recipient_meta['template_name'] = campaign_metadata.dig('template', 'name') if campaign_metadata.dig('template', 'name').present?

      recipient = campaign.disparador_recipients.create!(
        contact_id: params[:contact_id],
        conversation_id: conversation_id,
        name: params[:name],
        phone: normalize_phone(phone),
        status: 'pending',
        scheduled_at: scheduled_at,
        metadata: recipient_meta
      )

      link_schedule_conversation!(conversation, campaign, recipient)
    end

    if scheduled_at <= Time.current
      mode = channel == 'evolution' ? 'evolution' : 'conversation'
      campaign.update!(status: 'running', started_at: Time.current)
      recipient.update!(status: 'queued', last_event_at: Time.current)
      Disparador::SendRecipientJob.perform_later(recipient.id, mode)
    end

    serialize(recipient.reload)
  end

  def update!(recipient_id, params)
    recipient = manageable_recipient!(recipient_id)
    raise Error.new('Agendamento não pode ser editado', status: 404) unless %w[pending queued].include?(recipient.status)

    updates = {}
    if params.key?(:scheduled_at)
      updates[:scheduled_at] = parse_scheduled_at(params[:scheduled_at])
      raise Error.new('scheduled_at é obrigatório', status: 400) if updates[:scheduled_at].blank?
    end

    if params.key?(:message) && recipient.metadata['message_type'] != 'template'
      message = params[:message].to_s.strip
      raise Error.new('Informe a mensagem', status: 400) if message.blank?

      updates[:metadata] = recipient.metadata.merge('message_preview' => message)
      recipient.disparador_campaign.update!(message_template: message)
    end

    raise Error.new('Nenhum campo para atualizar', status: 400) if updates.empty?

    recipient.update!(updates)
    sync_campaign_schedule!(recipient) if updates.key?(:scheduled_at)
    serialize(recipient.reload)
  end

  def cancel!(recipient_id)
    recipient = manageable_recipient!(recipient_id)
    raise Error.new('Agendamento não pode ser cancelado', status: 404) unless %w[pending queued].include?(recipient.status)

    campaign = recipient.disparador_campaign
    recipient.update!(status: 'cancelled')
    campaign.update!(status: 'cancelled')
    Disparador::PurgeCampaignMediaService.new(campaign: campaign).perform
    serialize(recipient.reload)
  end

  private

  def base_scope
    DisparadorRecipient
      .joins(:disparador_campaign)
      .includes(:disparador_campaign)
      .where(disparador_campaigns: { account_id: account.id })
      .where("disparador_campaigns.metadata->>'source' = ?", SOURCE)
      .where.not(status: 'cancelled')
  end

  def filter_own(scope)
    return scope unless filter_to_own?

    scope.where(disparador_campaigns: { created_by_id: user.id })
  end

  def filter_status(scope, status)
    return scope if status.blank?

    case status.to_s
    when 'pending'
      scope.where(status: %w[pending queued])
    when 'sent'
      # "Enviados" includes the full delivery funnel after send
      scope.where(status: %w[sent delivered read replied])
    else
      scope.where(status: status)
    end
  end

  def filter_to_own?
    return false if account_user&.administrator?
    return true if account_user&.agent?

    false
  end

  def account_user
    @account_user ||= AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def manageable_recipient!(recipient_id)
    recipient = base_scope.find_by(id: recipient_id)
    raise Error.new('Agendamento não encontrado', status: 404) if recipient.blank?

    if filter_to_own? && recipient.disparador_campaign.created_by_id != user.id
      raise Error.new('Você só pode alterar agendamentos criados por você', status: 403)
    end

    recipient
  end

  def serialize(recipient)
    campaign = recipient.disparador_campaign
    meta = recipient.metadata || {}
    campaign_meta = campaign.metadata || {}
    tpl = campaign_meta['template'] || {}
    message_type = meta['message_type'] || (tpl['name'].present? ? 'template' : 'text')
    status = %w[pending queued].include?(recipient.status) ? 'pending' : recipient.status

    {
      id: recipient.id,
      campaign_id: campaign.id,
      conversation_id: recipient.conversation_id,
      scheduled_at: recipient.scheduled_at,
      status: status,
      message_type: message_type,
      channel: campaign.channel,
      template_name: tpl['name'] || meta['template_name'],
      template_category: tpl['category'] || meta['template_category'],
      message: campaign.message_template.presence || meta['message_preview'].to_s,
      contact_name: recipient.name,
      contact_phone: recipient.phone,
      inbox_id: campaign.inbox_id,
      inbox_name: campaign_meta['inbox_name'] || campaign.inbox&.name,
      created_by_id: campaign.created_by_id,
      created_by_email: campaign.created_by_email,
      created_at: recipient.created_at
    }
  end

  def parse_scheduled_at(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def normalize_phone(phone)
    phone.to_s.gsub(/\D/, '')
  end

  def find_conversation(ref)
    return if ref.blank?

    id = ref.to_i
    account.conversations.find_by(display_id: id) || account.conversations.find_by(id: id)
  end

  def link_schedule_conversation!(conversation, campaign, recipient)
    return if conversation.blank?

    attrs = (conversation.additional_attributes || {}).stringify_keys
    conversation.update!(
      additional_attributes: attrs.merge(
        'disparador_campaign_id' => campaign.id,
        'disparador_recipient_id' => recipient.id
      )
    )
  end

  # Keep wrapper campaign aligned with the recipient schedule (also heals older rows
  # that were incorrectly created as running).
  def sync_campaign_schedule!(recipient)
    campaign = recipient.disparador_campaign
    return unless campaign.metadata&.dig('source') == SOURCE
    return unless %w[pending queued].include?(recipient.status)
    return unless %w[scheduled running].include?(campaign.status)

    campaign.update!(status: 'scheduled', scheduled_at: recipient.scheduled_at, started_at: nil)
  end

  def build_template_params_body(values)
    body = {}
    Array(values).each_with_index do |val, idx|
      next if val.blank?

      body[(idx + 1).to_s] = val.to_s.strip
    end
    body
  end

  def build_template_snapshot(params)
    template = (params[:template] || {}).with_indifferent_access
    body_text = template[:body_text].presence
    if body_text.blank? && template[:components].present?
      body = Array(template[:components]).find { |c| c['type'].to_s.upcase == 'BODY' || c[:type].to_s.upcase == 'BODY' }
      body_text = body && (body['text'] || body[:text])
    end

    header = Array(template[:components]).find do |c|
      (c['type'] || c[:type]).to_s.upcase == 'HEADER'
    end
    header_format = (header && (header['format'] || header[:format])).to_s.upcase
    processed_header = {}
    header_url = params[:template_header_url].presence
    if header_url.present? && %w[IMAGE VIDEO DOCUMENT].include?(header_format)
      processed_header = {
        'media_url' => header_url,
        'media_type' => header_format.downcase
      }
    end

    {
      'name' => template[:name],
      'language' => template[:language],
      'namespace' => template[:namespace].to_s,
      'category' => template[:category].presence || 'UTILITY',
      'status' => template[:status],
      'components' => template[:components] || [],
      'body_text' => body_text.to_s,
      'variable_keys' => template[:variable_keys] || [],
      'header_media_type' => %w[IMAGE VIDEO DOCUMENT].include?(header_format) ? header_format.downcase : nil,
      'processed_params' => {
        'body' => build_template_params_body(params[:template_param_values]),
        'header' => processed_header
      }
    }
  end
end
