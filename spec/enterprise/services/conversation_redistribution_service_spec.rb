require 'rails_helper'

RSpec.describe ConversationRedistributionService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent1) { create(:user, account: account, role: :agent) }
  let(:agent2) { create(:user, account: account, role: :agent) }
  let(:agent3) { create(:user, account: account, role: :agent) }

  let(:base_params) do
    {
      inbox_id: inbox.id,
      redistribution_type: 'unassigned',
      statuses: %w[open pending],
      agent_ids: [agent1.id, agent2.id],
      strategy: 'round_robin'
    }
  end

  let(:service) { described_class.new(account: account, params: params) }
  let(:params) { base_params }

  before do
    create(:inbox_member, inbox: inbox, user: agent1)
    create(:inbox_member, inbox: inbox, user: agent2)
    create(:inbox_member, inbox: inbox, user: agent3)
  end

  describe '#simulate' do
    context 'with unassigned conversations' do
      let!(:conversation1) { create(:conversation, account: account, inbox: inbox, status: :open, assignee: nil) }
      let!(:conversation2) { create(:conversation, account: account, inbox: inbox, status: :pending, assignee: nil) }
      let!(:ignored) do
        create(:conversation, account: account, inbox: inbox, status: :open, assignee: agent3)
      end

      it 'returns a redistribution plan without changing assignees' do
        result = service.simulate

        expect(result[:total_conversations]).to eq(2)
        expect(result[:agent_count]).to eq(2)
        expect(result[:assignments].pluck(:conversation_id)).to contain_exactly(conversation1.id, conversation2.id)
        expect(conversation1.reload.assignee).to be_nil
        expect(conversation2.reload.assignee).to be_nil
      end

      it 'distributes conversations in round robin order' do
        result = service.simulate

        expect(result[:assignments][0][:new_assignee][:id]).to eq(agent1.id)
        expect(result[:assignments][1][:new_assignee][:id]).to eq(agent2.id)
        expect(result[:summary]).to contain_exactly(
          { agent_id: agent1.id, name: agent1.name, count: 1 },
          { agent_id: agent2.id, name: agent2.name, count: 1 }
        )
      end
    end

    context 'with from_agent redistribution' do
      let(:params) do
        base_params.merge(
          redistribution_type: 'from_agent',
          source_agent_id: agent3.id
        )
      end

      let!(:conversation) do
        create(:conversation, account: account, inbox: inbox, status: :open, assignee: agent3)
      end

      before do
        create(:conversation, account: account, inbox: inbox, status: :open, assignee: agent1)
      end

      it 'only includes conversations from the source agent' do
        result = service.simulate

        expect(result[:total_conversations]).to eq(1)
        expect(result[:assignments].first[:conversation_id]).to eq(conversation.id)
        expect(result[:assignments].first[:current_assignee][:id]).to eq(agent3.id)
      end
    end

    context 'with load_balance strategy' do
      let(:params) { base_params.merge(strategy: 'load_balance') }

      let!(:unassigned_conversation) do
        create(:conversation, account: account, inbox: inbox, status: :open, assignee: nil)
      end

      before do
        2.times { create(:conversation, account: account, inbox: inbox, status: :open, assignee: agent1) }
        create(:conversation, account: account, inbox: inbox, status: :open, assignee: agent2)
      end

      it 'assigns to the agent with the lowest open conversation count' do
        result = service.simulate

        expect(result[:assignments].first[:new_assignee][:id]).to eq(agent2.id)
      end
    end
  end

  describe '#execute' do
    let!(:conversation1) { create(:conversation, account: account, inbox: inbox, status: :open, assignee: nil) }
    let!(:conversation2) { create(:conversation, account: account, inbox: inbox, status: :open, assignee: nil) }

    it 'updates assignees according to the plan' do
      result = service.execute

      expect(result[:total_conversations]).to eq(2)
      expect(conversation1.reload.assignee).to eq(agent1)
      expect(conversation2.reload.assignee).to eq(agent2)
    end

    it 'rolls back all changes when an update fails' do
      allow_any_instance_of(Conversation).to receive(:update!).and_wrap_original do |method, *args|
        raise ActiveRecord::RecordInvalid, conversation2 if method.receiver.id == conversation2.id

        method.call(*args)
      end

      expect { service.execute }.to raise_error(ActiveRecord::RecordInvalid)

      expect(conversation1.reload.assignee).to be_nil
      expect(conversation2.reload.assignee).to be_nil
    end
  end

  describe 'validation' do
    it 'requires inbox_id' do
      params[:inbox_id] = nil

      expect { service.simulate }.to raise_error(
        ConversationRedistributionService::ValidationError,
        'inbox_id is required'
      )
    end

    it 'requires at least two participating agents' do
      params[:agent_ids] = [agent1.id]

      expect { service.simulate }.to raise_error(
        ConversationRedistributionService::ValidationError,
        'Select at least two agents'
      )
    end

    it 'requires source agent for from_agent type' do
      params[:redistribution_type] = 'from_agent'

      expect { service.simulate }.to raise_error(
        ConversationRedistributionService::ValidationError,
        'source_agent_id is required'
      )
    end

    it 'requires participating agents to belong to the inbox' do
      outsider = create(:user, account: account, role: :agent)
      params[:agent_ids] = [agent1.id, outsider.id]

      expect { service.simulate }.to raise_error(
        ConversationRedistributionService::ValidationError,
        'Agents must belong to the inbox'
      )
    end

    it 'enforces the maximum conversation limit' do
      stub_const('ConversationRedistributionService::MAX_CONVERSATIONS', 1)
      2.times { create(:conversation, account: account, inbox: inbox, status: :open, assignee: nil) }

      expect { service.simulate }.to raise_error(
        ConversationRedistributionService::ValidationError,
        'Maximum of 1 conversations per redistribution'
      )
    end
  end
end
