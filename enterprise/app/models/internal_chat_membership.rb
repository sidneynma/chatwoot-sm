class InternalChatMembership < ApplicationRecord
  belongs_to :internal_chat_room
  belongs_to :user

  validates :user_id, uniqueness: { scope: :internal_chat_room_id }

  scope :open, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }

  def closed?
    closed_at.present?
  end

  def close!
    update!(closed_at: Time.current)
  end

  def reopen!
    update!(closed_at: nil) if closed?
  end

  def unread_count
    scope = internal_chat_room.messages.where.not(user_id: user_id)
    scope = scope.where('created_at > ?', last_read_at) if last_read_at.present?
    scope.count
  end
end
