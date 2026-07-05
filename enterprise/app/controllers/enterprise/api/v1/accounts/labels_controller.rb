module Enterprise::Api::V1::Accounts::LabelsController
  def index
    @labels = InboxScopedLabels::FilterService.new(
      labels: policy_scope(Current.account.labels),
      account_user: Current.account_user
    ).perform
  end

  private

  def permitted_params
    params.require(:label).permit(:title, :description, :color, :show_on_sidebar, :inbox_id)
  end
end
