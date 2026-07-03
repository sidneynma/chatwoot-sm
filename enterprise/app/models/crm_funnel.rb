class CrmFunnel < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true

  has_many :stages, class_name: 'CrmFunnelStage', dependent: :destroy_async, inverse_of: :crm_funnel

  validates :name, presence: true
  validate :inbox_belongs_to_account

  scope :active, -> { where(active: true) }

  def stage_label_titles
    stages.joins(:label).pluck('labels.title')
  end

  private

  def inbox_belongs_to_account
    return if inbox.blank? || inbox.account_id == account_id

    errors.add(:inbox_id, :invalid)
  end
end
