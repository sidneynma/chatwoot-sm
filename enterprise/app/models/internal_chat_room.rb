class InternalChatRoom < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :memberships, class_name: 'InternalChatMembership', dependent: :destroy_async,
                         inverse_of: :internal_chat_room
  has_many :members, through: :memberships, source: :user
  has_many :messages, class_name: 'InternalChatMessage', dependent: :destroy_async,
                      inverse_of: :internal_chat_room

  accepts_nested_attributes_for :memberships

  enum room_type: { direct: 0, group: 1 }, _prefix: true

  validates :name, presence: true, if: :room_type_group?
  validates :direct_key, presence: true, uniqueness: { scope: :account_id }, if: :room_type_direct?

  scope :for_user, lambda { |user|
    where(id: InternalChatMembership.where(user_id: user.id).select(:internal_chat_room_id))
  }

  scope :open_for_user, lambda { |user|
    where(id: InternalChatMembership.open.where(user_id: user.id).select(:internal_chat_room_id))
  }

  def self.direct_key_for(user_a_id, user_b_id)
    [user_a_id, user_b_id].map(&:to_i).minmax.join(':')
  end

  def member?(user)
    memberships.exists?(user_id: user.id)
  end

  def display_name_for(current_user)
    return name if room_type_group?

    other = members.find { |member| member.id != current_user.id }
    other&.name || name || 'Direct'
  end

  def peer_user_ids_for(user)
    memberships.where.not(user_id: user.id).pluck(:user_id)
  end

  # Direct chat peer is no longer an account member (history kept, send blocked).
  def peer_inactive_for?(user)
    return false unless room_type_direct?

    peer_ids = peer_user_ids_for(user)
    return true if peer_ids.blank?

    !account.account_users.exists?(user_id: peer_ids)
  end

  def can_send_message?(user)
    member?(user) && !peer_inactive_for?(user)
  end

  def reopen_for_all!
    reopen_for_active_members!
  end

  # Reopen only for users who still belong to the account (keeps removed peers closed).
  def reopen_for_active_members!
    active_ids = account.account_users.select(:user_id)
    memberships.closed.where(user_id: active_ids).find_each(&:reopen!)
  end

  def closed_for?(user)
    memberships.find_by(user_id: user.id)&.closed? || false
  end
end
