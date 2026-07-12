class CrmFunnel < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true

  has_many :stages, class_name: 'CrmFunnelStage', dependent: :destroy, inverse_of: :crm_funnel
  has_many :crm_case_states, dependent: :delete_all

  validates :name, presence: true
  validate :inbox_belongs_to_account

  scope :active, -> { where(active: true) }

  # Agent: funnels of their inboxes OR with a stage handed to one of their teams.
  # Global funnels (no inbox) without team stages are admin-only.
  def self.visible_to(user, account)
    inbox_ids = user.inboxes.where(account_id: account.id).pluck(:id)
    team_ids = user.teams.where(account_id: account.id).pluck(:id)
    return none if inbox_ids.blank? && team_ids.blank?

    by_inbox = inbox_ids.present? ? where(inbox_id: inbox_ids) : none
    by_team = if team_ids.present?
                where(id: CrmFunnelStage.where(responsible_team_id: team_ids).select(:crm_funnel_id))
              else
                none
              end

    if inbox_ids.present? && team_ids.present?
      by_inbox.or(by_team)
    elsif inbox_ids.present?
      by_inbox
    else
      by_team
    end
  end

  def stage_label_titles
    stages.joins(:label).pluck('labels.title')
  end

  private

  def inbox_belongs_to_account
    return if inbox.blank? || inbox.account_id == account_id

    errors.add(:inbox_id, :invalid)
  end
end
