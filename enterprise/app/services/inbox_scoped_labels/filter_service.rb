module InboxScopedLabels
  class FilterService
    pattr_initialize [:labels!, :account_user!]

    def perform
      InboxScopedResources::FilterService.new(
        scope: labels,
        account_user: account_user
      ).perform
    end
  end
end
