module Enterprise::Api::V1::Accounts::CannedResponsesController
  private

  def canned_responses
    InboxScopedResources::FilterService.new(
      scope: super,
      account_user: Current.account_user
    ).perform
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content, :inbox_id)
  end
end
