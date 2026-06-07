/* global axios */
import ApiClient from '../../api/ApiClient';

class WhatsappTemplatesAPI extends ApiClient {
  constructor() {
    super('whatsapp/templates', { accountScoped: true });
  }

  get(inboxId) {
    return axios.get(this.url, { params: { inbox_id: inboxId } });
  }
}

export default new WhatsappTemplatesAPI();
