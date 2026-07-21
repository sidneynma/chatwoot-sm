class Api::V1::Accounts::DisparadorCampaignsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_disparador_module_enabled!
  before_action :fetch_campaign, only: [
    :show, :update, :destroy, :archive, :unarchive, :dispatch_now, :retry_failed, :stats, :dispatch_status
  ]
  before_action :check_authorization

  def index
    scope = filtered_campaigns_scope
    @campaigns = scope.limit((params[:limit] || 100).to_i).offset((params[:offset] || 0).to_i)
    @overview = build_overview(filtered_campaigns_scope(with_inbox: false)) if params[:overview] == 'true'
  end

  def export
    scope = filtered_campaigns_scope.limit(5000)
    csv = Disparador::CampaignsExportService.new(campaigns: scope, locale: :pt).to_csv
    filename = "campanhas_#{Time.zone.today.iso8601}.csv"
    send_data csv, filename: filename, type: 'text/csv; charset=utf-8', disposition: 'attachment'
  end

  def show; end

  def create
    @campaign = Current.account.disparador_campaigns.create!(campaign_params.merge(
                                                               created_by_id: Current.user.id,
                                                               created_by_email: Current.user.email
                                                             ))
    add_recipients
  end

  def update
    @campaign.update!(campaign_params)
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  def archive
    @campaign.archive!
    render :show
  end

  def unarchive
    @campaign.unarchive!
    render :show
  end

  def dispatch_now
    mode = params[:dispatch_mode].presence
    if mode.present? && %w[meta_direct conversation].include?(mode)
      @campaign.update!(metadata: @campaign.metadata.merge('dispatch_mode' => mode))
    end

    Disparador::StartDispatchJob.perform_later(@campaign.id, mode, false)
    render json: { status: 'queued', campaign_id: @campaign.id }, status: :accepted
  end

  def retry_failed
    mode = params[:dispatch_mode].presence
    Disparador::StartDispatchJob.perform_later(@campaign.id, mode, true)
    render json: { status: 'queued', campaign_id: @campaign.id }, status: :accepted
  end

  def stats
    render json: { payload: campaign_stats_payload(@campaign) }
  end

  def dispatch_status
    stats = @campaign.recipient_stats
    render json: {
      payload: {
        campaign_status: @campaign.status,
        total: stats.values.sum,
        pending: stats['pending'].to_i,
        queued: stats['queued'].to_i,
        sent: sent_count(stats),
        failed: stats['failed'].to_i,
        delivered: stats['delivered'].to_i,
        read: stats['read'].to_i,
        replied: stats['replied'].to_i
      }
    }
  end

  private

  def fetch_campaign
    @campaign = Current.account.disparador_campaigns.find(params[:id])
  end

  def filtered_campaigns_scope(with_inbox: true)
    scope = Current.account.disparador_campaigns.ordered
    scope = scope.includes(:inbox) if with_inbox
    scope = case params[:archived].to_s
            when 'archived' then scope.archived
            when 'all' then scope
            else scope.active
            end
    scope = scope.where(status: params[:status]) if params[:status].present?
    if params[:search].present?
      scope = scope.where('name ILIKE ?', "%#{DisparadorCampaign.sanitize_sql_like(params[:search])}%")
    end
    apply_date_filters(scope)
  end

  def apply_date_filters(scope)
    date_expr = 'COALESCE(disparador_campaigns.started_at, disparador_campaigns.scheduled_at, disparador_campaigns.created_at)'
    if params[:from].present?
      from = Time.zone.parse(params[:from])
      scope = scope.where("#{date_expr} >= ?", from.beginning_of_day) if from
    end
    if params[:to].present?
      to = Time.zone.parse(params[:to])
      scope = scope.where("#{date_expr} <= ?", to.end_of_day) if to
    end
    scope
  end

  def campaign_params
    params.permit(
      :name, :description, :inbox_id, :channel, :status,
      :message_template, :scheduled_at
    ).tap do |permitted|
      next if params[:metadata].blank?

      permitted[:metadata] = if params[:metadata].respond_to?(:to_unsafe_h)
                               params[:metadata].to_unsafe_h
                             else
                               params[:metadata].to_h
                             end
    end
  end

  def recipients_payload
    raw = params[:recipients]
    return [] if raw.blank?

    Array(raw).filter_map do |row|
      attrs = if row.respond_to?(:permit)
                row.permit(:name, :phone, :email, :contact_id, :conversation_id, metadata: {}).to_h
              else
                row.to_h.with_indifferent_access.slice(
                  :name, :phone, :email, :contact_id, :conversation_id, :metadata,
                  'name', 'phone', 'email', 'contact_id', 'conversation_id', 'metadata'
                )
              end
      attrs = attrs.with_indifferent_access
      next if attrs[:phone].blank? && attrs[:email].blank? && attrs[:contact_id].blank?

      attrs
    end
  end

  def add_recipients
    recipients_payload.each do |attrs|
      @campaign.disparador_recipients.create!(attrs)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      next
    end
  end

  def build_overview(scope)
    ids = scope.pluck(:id)
    recipients = DisparadorRecipient.where(disparador_campaign_id: ids)
    by_status = recipients.group(:status).count
    {
      total_campaigns: ids.size,
      running_campaigns: scope.where(status: 'running').count,
      scheduled_campaigns: scope.where(status: 'scheduled').count,
      total_recipients: by_status.values.sum,
      sent_count: sent_count(by_status),
      replied_count: by_status['replied'].to_i,
      failed_count: by_status['failed'].to_i,
      reply_rate: reply_rate(by_status)
    }
  end

  def campaign_stats_payload(campaign)
    stats = campaign.recipient_stats
    {
      total_recipients: stats.values.sum,
      pending_count: stats['pending'].to_i,
      queued_count: stats['queued'].to_i,
      sent_count: sent_count(stats),
      delivered_count: stats['delivered'].to_i,
      read_count: stats['read'].to_i,
      replied_count: stats['replied'].to_i,
      failed_count: stats['failed'].to_i,
      reply_rate: reply_rate(stats),
      status: campaign.status,
      dispatch_mode: campaign.metadata&.dig('dispatch_mode'),
      template: campaign.metadata&.dig('template')
    }
  end

  def sent_count(stats)
    stats['sent'].to_i + stats['delivered'].to_i + stats['read'].to_i + stats['replied'].to_i
  end

  def reply_rate(stats)
    sent = sent_count(stats)
    return 0 if sent.zero?

    ((stats['replied'].to_i.to_f / sent) * 100).round(1)
  end

  def ensure_disparador_module_enabled!
    return if Current.account.chatolhe_module_enabled?('disparador')

    render json: { error: 'Disparador module is not enabled for this account' }, status: :forbidden
  end
end
