class InternalChatMessagePolicy < ApplicationPolicy
  def index?
    member?
  end

  def create?
    member? && record.internal_chat_room.can_send_message?(@user)
  end

  private

  def member?
    (@account_user.administrator? || @account_user.agent?) &&
      record.internal_chat_room.member?(@user)
  end
end
