class CrmCaseState < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :crm_funnel
  belongs_to :previous_assignee, class_name: 'User', optional: true
  belongs_to :previous_team, class_name: 'Team', optional: true

  validates :conversation_id, uniqueness: { scope: :crm_funnel_id }
end
