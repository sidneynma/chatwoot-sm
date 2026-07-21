class DisparadorRecipient < ApplicationRecord
  belongs_to :disparador_campaign, inverse_of: :disparador_recipients

  STATUSES = %w[
    pending queued sent delivered read replied failed opted_out bounced cancelled
  ].freeze

  validates :status, inclusion: { in: STATUSES }
  validate :contact_present

  scope :pending, -> { where(status: 'pending') }

  private

  def contact_present
    return if phone.present? || email.present? || contact_id.present?

    errors.add(:base, 'phone, email or contact_id is required')
  end
end
