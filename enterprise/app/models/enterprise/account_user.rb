module Enterprise::AccountUser
  def permissions
    custom_role.present? ? (custom_role.permissions + ['custom_role']) : super
  end

  def remove_user_from_account
    InternalChat::HandleAgentRemovedService.new(account: account, user: user).perform
    super
  end
end
