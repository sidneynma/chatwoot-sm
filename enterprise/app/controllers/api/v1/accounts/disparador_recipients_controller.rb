class Api::V1::Accounts::DisparadorRecipientsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_disparador_module_enabled!
  before_action :fetch_campaign
  before_action :check_authorization

  def index
    @recipients = @campaign.disparador_recipients.order(id: :desc)
                           .limit((params[:limit] || 200).to_i)
                           .offset((params[:offset] || 0).to_i)
  end

  def create
    created = []
    recipients_payload.each do |attrs|
      created << @campaign.disparador_recipients.create!(attrs)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      next
    end

    @recipients = created
    render :index
  end

  private

  def fetch_campaign
    @campaign = Current.account.disparador_campaigns.find(params[:disparador_campaign_id])
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
