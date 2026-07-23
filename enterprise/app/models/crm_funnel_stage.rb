class CrmFunnelStage < ApplicationRecord
  belongs_to :crm_funnel, inverse_of: :stages
  belongs_to :label
  belongs_to :responsible_team, class_name: 'Team', optional: true

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :label_id, uniqueness: { scope: :crm_funnel_id }
  validate :label_belongs_to_account
  validate :teams_belong_to_account

  default_scope { order(:position) }

  before_validation :normalize_responsible_teams

  def responsible_team_ids_list
    Array(responsible_team_ids).map(&:to_i).uniq
  end

  def has_responsible_teams?
    responsible_team_ids_list.present?
  end

  def primary_responsible_team_id
    responsible_team_id.presence || responsible_team_ids_list.first
  end

  def responsible_team_ids_include_any?(team_ids)
    return false if team_ids.blank?

    (responsible_team_ids_list & Array(team_ids).map(&:to_i)).any?
  end

  private

  def normalize_responsible_teams
    ids = responsible_team_ids_list
    ids = [responsible_team_id.to_i] if ids.blank? && responsible_team_id.present?
    self.responsible_team_ids = ids
    self.responsible_team_id = ids.first
  end

  def label_belongs_to_account
    return if label.blank? || label.account_id == crm_funnel.account_id

    errors.add(:label_id, :invalid)
  end

  def teams_belong_to_account
    return if responsible_team_ids_list.blank?

    account_team_ids = crm_funnel.account.teams.where(id: responsible_team_ids_list).pluck(:id)
    return if (responsible_team_ids_list - account_team_ids).blank?

    errors.add(:responsible_team_ids, :invalid)
  end
end
