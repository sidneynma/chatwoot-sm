module Enterprise::Label
  extend ActiveSupport::Concern

  included do
    belongs_to :inbox, optional: true

    validate :inbox_belongs_to_account
  end

  private

  def inbox_belongs_to_account
    return if inbox.blank? || inbox.account_id == account_id

    errors.add(:inbox_id, :invalid)
  end
end
