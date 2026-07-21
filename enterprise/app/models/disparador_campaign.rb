class DisparadorCampaign < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true
  belongs_to :created_by, class_name: 'User', optional: true, foreign_key: :created_by_id

  has_many :disparador_recipients, dependent: :destroy, inverse_of: :disparador_campaign

  CHANNELS = %w[whatsapp email sms meta evolution webhook other].freeze
  STATUSES = %w[draft scheduled running paused completed cancelled failed].freeze

  validates :name, presence: true
  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :ordered, -> { order(created_at: :desc) }

  before_validation :apply_schedule_status, on: :create

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
    Disparador::PurgeCampaignMediaService.new(campaign: self).perform
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def recipient_stats
    disparador_recipients.group(:status).count
  end

  private

  def apply_schedule_status
    return if status != 'draft'
    return if scheduled_at.blank?

    self.status = 'scheduled'
  end
end
