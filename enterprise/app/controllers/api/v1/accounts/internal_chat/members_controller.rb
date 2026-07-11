class Api::V1::Accounts::InternalChat::MembersController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :fetch_room
  before_action :ensure_group!
  before_action :check_authorization

  def create
    user = Current.account.users.find(params.require(:user_id))
    @membership = @room.memberships.find_or_create_by!(user: user)
    reload_room
    InternalChat::BroadcastService.room_updated(@room)
    render 'api/v1/accounts/internal_chat/rooms/show'
  end

  def destroy
    membership = @room.memberships.find_by!(user_id: params[:id])
    membership.destroy!
    reload_room
    InternalChat::BroadcastService.room_updated(@room)
    head :ok
  end

  private

  def fetch_room
    @room = Current.account.internal_chat_rooms.includes(:members, memberships: :user).find(params[:room_id])
  end

  def reload_room
    @room = Current.account.internal_chat_rooms.includes(:members, memberships: :user).find(@room.id)
  end

  def ensure_group!
    render json: { error: 'Only group rooms support member management' }, status: :unprocessable_entity unless @room.room_type_group?
  end

  def check_authorization
    authorize(@room, :manage_members?)
  end
end
