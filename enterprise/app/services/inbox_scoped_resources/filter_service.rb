module InboxScopedResources
  class FilterService
    pattr_initialize [:scope!, :account_user!]

    def perform
      return scope if account_user.administrator?

      inbox_ids = Current.user.assigned_inboxes.pluck(:id)
      scope.where(inbox_id: [nil] + inbox_ids)
    end
  end
end
