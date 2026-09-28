class Api::V1::Accounts::InboxMemberAccessController < Api::V1::Accounts::BaseController
  before_action :ensure_member_access
  before_action :fetch_inbox, only: [:update]

  def index
    render json: {
      inboxes: inboxes_payload,
      agents: agents_payload
    }
  end

  def update
    apply_member_ids(Array(params[:user_ids]).map(&:to_i))
    render json: inbox_payload(@inbox)
  end

  private

  def ensure_member_access
    return if Current.account_user.administrator?
    return if Current.account_user.custom_role&.permissions&.include?('inbox_member_manage')

    raise Pundit::NotAuthorizedError
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
  end

  def inboxes_payload
    Current.account.inboxes.order_by_name.map { |inbox| inbox_payload(inbox) }
  end

  def inbox_payload(inbox)
    {
      id: inbox.id,
      name: inbox.name,
      member_ids: inbox.members.pluck(:id)
    }
  end

  def agents_payload
    Current.account.users.order_by_full_name.map do |user|
      { id: user.id, name: user.available_name }
    end
  end

  def apply_member_ids(requested_ids)
    allowed_ids = Current.account.users.where(id: requested_ids).pluck(:id)
    current_ids = @inbox.members.pluck(:id)

    ActiveRecord::Base.transaction do
      @inbox.add_members(allowed_ids - current_ids)
      @inbox.remove_members(current_ids - allowed_ids)
    end
  end
end
