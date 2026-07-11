class Api::V1::Accounts::InternalChat::MessagesController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :fetch_room
  before_action :check_authorization

  RESULTS_PER_PAGE = 50

  def index
    messages = @room.messages.includes(:user).with_attached_attachments.order(id: :desc)
    messages = messages.where('id < ?', params[:before]) if params[:before].present?
    @messages = messages.limit(RESULTS_PER_PAGE).reverse
  end

  def create
    @message = InternalChat::CreateMessageService.new(
      account: Current.account,
      room: @room,
      user: Current.user,
      content: message_params[:content],
      blob_signed_ids: message_params[:blob_signed_ids],
      is_voice: message_params[:is_voice]
    ).perform
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Internal chat message create failed: #{e.class}: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_room
    @room = Current.account.internal_chat_rooms.find(params[:room_id])
  end

  def message_params
    params.permit(:content, :is_voice, blob_signed_ids: [])
  end

  def check_authorization
    authorize(@room.messages.new(account: Current.account, user: Current.user, internal_chat_room: @room))
  end
end
