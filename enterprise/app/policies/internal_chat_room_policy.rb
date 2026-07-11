class InternalChatRoomPolicy < ApplicationPolicy
  def index?
    agent_or_admin?
  end

  def show?
    agent_or_admin? && member?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def create_direct?
    agent_or_admin?
  end

  def mark_read?
    show?
  end

  def close?
    show?
  end

  def manage_members?
    @account_user.administrator?
  end

  private

  def agent_or_admin?
    @account_user.administrator? || @account_user.agent?
  end

  def member?
    record.member?(@user)
  end
end
