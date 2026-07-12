class Api::V1::Accounts::InternalChat::RoomsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :fetch_room, only: [:show, :update, :destroy, :mark_read, :close, :reopen]
  before_action :check_authorization

  def index
    @rooms = Current.account.internal_chat_rooms
                    .open_for_user(Current.user)
                    .includes(:members, memberships: :user)
                    .order(Arel.sql(
                             'COALESCE(internal_chat_rooms.last_message_at, internal_chat_rooms.created_at) DESC'
                           ))
  end

  def search
    @rooms = InternalChat::SearchRoomsService.new(
      account: Current.account,
      user: Current.user,
      query: params[:q]
    ).perform
    render :index
  end

  def unread_count
    total = InternalChat::UnreadCountService.new(
      account: Current.account,
      user: Current.user
    ).perform
    render json: { unread_count: total }
  end

  def show; end

  def create
    @room = Current.account.internal_chat_rooms.create!(
      room_type: :group,
      name: room_params[:name],
      created_by: Current.user
    )
    sync_members(Array(room_params[:member_ids]) | [Current.user.id])
    reload_room
    InternalChat::BroadcastService.room_updated(@room, 'internal_chat.room_created')
  end

  def update
    @room.update!(name: room_params[:name]) if room_params[:name].present?
    sync_members(Array(room_params[:member_ids])) if room_params.key?(:member_ids)
    reload_room
    InternalChat::BroadcastService.room_updated(@room)
  end

  def destroy
    raise Pundit::NotAuthorizedError unless @room.room_type_group?

    tokens = @room.members.filter_map(&:pubsub_token)
    room_id = @room.id
    account_id = @room.account_id
    @room.destroy!
    ActionCableBroadcastJob.perform_later(
      tokens,
      'internal_chat.room_deleted',
      { id: room_id, account_id: account_id }
    )
    head :ok
  end

  def create_direct
    @room = InternalChat::CreateDirectService.new(
      account: Current.account,
      current_user: Current.user,
      peer_user_id: params.require(:user_id)
    ).perform
    reload_room
    render :show
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Agent not found in this account' }, status: :unprocessable_entity
  end

  def mark_read
    membership = @room.memberships.find_by!(user_id: Current.user.id)
    membership.update!(last_read_at: Time.current)
    head :ok
  end

  def close
    membership = @room.memberships.find_by!(user_id: Current.user.id)
    membership.close!
    head :ok
  end

  def reopen
    membership = @room.memberships.find_by!(user_id: Current.user.id)
    membership.reopen!
    reload_room
    render :show
  end

  private

  def fetch_room
    @room = Current.account.internal_chat_rooms.includes(:members, memberships: :user).find(params[:id])
  end

  def reload_room
    @room = Current.account.internal_chat_rooms.includes(:members, memberships: :user).find(@room.id)
  end

  def room_params
    params.require(:room).permit(:name, member_ids: [])
  end

  def sync_members(member_ids)
    raise Pundit::NotAuthorizedError unless @room.room_type_group?

    user_ids = Current.account.users.where(id: member_ids).pluck(:id)
    user_ids |= [Current.user.id]

    existing = @room.memberships.pluck(:user_id)
    (user_ids - existing).each { |user_id| @room.memberships.create!(user_id: user_id) }
    @room.memberships.where(user_id: existing - user_ids).destroy_all
  end

  def check_authorization
    case action_name
    when 'create_direct'
      authorize(InternalChatRoom, :create_direct?)
    when 'search', 'unread_count'
      authorize(InternalChatRoom, :index?)
    when 'mark_read'
      authorize(@room, :mark_read?)
    when 'close', 'reopen'
      authorize(@room, :close?)
    when 'index', 'create'
      authorize(InternalChatRoom)
    else
      authorize(@room)
    end
  end
end
