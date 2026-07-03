class CrmFunnelStage < ApplicationRecord
  belongs_to :crm_funnel, inverse_of: :stages
  belongs_to :label

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :label_id, uniqueness: { scope: :crm_funnel_id }
  validate :label_belongs_to_account

  default_scope { order(:position) }

  private

  def label_belongs_to_account
    return if label.blank? || label.account_id == crm_funnel.account_id

    errors.add(:label_id, :invalid)
  end
end
