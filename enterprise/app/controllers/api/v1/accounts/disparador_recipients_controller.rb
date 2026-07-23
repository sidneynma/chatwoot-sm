class Api::V1::Accounts::DisparadorRecipientsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_disparador_module_enabled!
  before_action :fetch_campaign
  before_action :check_authorization

  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 200

  def index
    scope = filtered_recipients
    @meta = pagination_meta(scope)
    @recipients = scope.order(id: :desc)
                       .offset((@meta[:page] - 1) * @meta[:per_page])
                       .limit(@meta[:per_page])
  end

  def create
    created = []
    recipients_payload.each do |attrs|
      created << @campaign.disparador_recipients.create!(attrs)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      next
    end

    @recipients = created
    @meta = {
      total_count: created.size,
      page: 1,
      per_page: created.size,
      total_pages: 1
    }
    render :index
  end

  private

  def fetch_campaign
    @campaign = Current.account.disparador_campaigns.find(params[:disparador_campaign_id])
  end

  def filtered_recipients
    scope = @campaign.disparador_recipients
    return scope if params[:status].blank?

    statuses = params[:status].to_s.split(',').map(&:strip) & DisparadorRecipient::STATUSES
    return scope if statuses.blank?

    scope.where(status: statuses)
  end

  def pagination_meta(scope)
    per_page = (params[:per_page].presence || params[:limit].presence || DEFAULT_PER_PAGE).to_i
    per_page = DEFAULT_PER_PAGE if per_page <= 0
    per_page = [per_page, MAX_PER_PAGE].min

    page = params[:page].to_i
    if page <= 0 && params[:offset].present?
      page = (params[:offset].to_i / per_page) + 1
    end
    page = 1 if page <= 0

    total_count = scope.count
    total_pages = total_count.zero? ? 0 : (total_count.to_f / per_page).ceil

    {
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: total_pages
    }
  end

  def recipients_payload
    raw = params[:recipients]
    return [] if raw.blank?

    Array(raw).filter_map do |row|
      attrs = if row.respond_to?(:permit)
                row.permit(:name, :phone, :email, :contact_id, :conversation_id, :scheduled_at).to_h
              else
                row.to_h.slice(
                  'name', 'phone', 'email', 'contact_id', 'conversation_id', 'scheduled_at',
                  :name, :phone, :email, :contact_id, :conversation_id, :scheduled_at
                )
              end
      attrs = attrs.with_indifferent_access
      next if attrs[:phone].blank? && attrs[:email].blank? && attrs[:contact_id].blank?

      attrs
    end
  end

  def ensure_disparador_module_enabled!
    return if Current.account.chatolhe_module_enabled?('disparador')

    render json: { error: 'Disparador module is not enabled for this account' }, status: :forbidden
  end

  def check_authorization
    authorize(@campaign, :show?)
  end
end
