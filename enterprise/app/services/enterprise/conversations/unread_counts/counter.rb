module Enterprise::Conversations::UnreadCounts::Counter
  VIEW_ALL_PERMISSION = 'conversation_view_all'.freeze

  private

  def visible_inbox_ids
    return account.inboxes.pluck(:id) if conversation_view_all?

    super
  end

  def permission_mode
    return :base if conversation_view_all?

    super
  end

  def conversation_view_all?
    permissions.include?(VIEW_ALL_PERMISSION)
  end
end
