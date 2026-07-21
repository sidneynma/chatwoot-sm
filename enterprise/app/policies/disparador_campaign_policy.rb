class DisparadorCampaignPolicy < ApplicationPolicy
  def index?
    agent_or_admin?
  end

  def export?
    index?
  end

  def show?
    agent_or_admin?
  end

  def create?
    agent_or_admin?
  end

  def update?
    agent_or_admin?
  end

  def destroy?
    @account_user.administrator?
  end

  def archive?
    agent_or_admin?
  end

  def unarchive?
    agent_or_admin?
  end

  def dispatch_now?
    agent_or_admin?
  end

  def retry_failed?
    agent_or_admin?
  end

  def stats?
    agent_or_admin?
  end

  def dispatch_status?
    agent_or_admin?
  end

  private

  def agent_or_admin?
    @account_user.administrator? || @account_user.agent?
  end
end
