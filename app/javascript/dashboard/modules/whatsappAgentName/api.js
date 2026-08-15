/* global axios */
import ApiClient from '../../api/ApiClient';

class WhatsappAgentNameAPI extends ApiClient {
  constructor() {
    super('whatsapp/agent_name_setting', { accountScoped: true });
  }

  update(inboxId, enabled) {
    return axios.patch(this.url, {
      inbox_id: inboxId,
      enabled,
    });
  }
}

export default new WhatsappAgentNameAPI();
