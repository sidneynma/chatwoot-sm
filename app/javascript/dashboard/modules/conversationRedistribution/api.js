/* global axios */
import ApiClient from '../../api/ApiClient';

class ConversationRedistributionAPI extends ApiClient {
  constructor() {
    super('conversation_redistribution', { accountScoped: true });
  }

  simulate(payload) {
    return axios.post(`${this.url}/simulate`, payload);
  }

  execute(payload) {
    return axios.post(`${this.url}/execute`, payload);
  }

  getInboxAgents(inboxId) {
    return axios.get(`${this.baseUrl()}/inbox_members/${inboxId}`);
  }
}

export default new ConversationRedistributionAPI();
