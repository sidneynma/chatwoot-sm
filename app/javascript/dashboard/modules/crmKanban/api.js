/* global axios */
import ApiClient from '../../api/ApiClient';

class CrmKanbanAPI extends ApiClient {
  constructor() {
    super('crm_funnels', { accountScoped: true });
  }

  getBoard(funnelId, params = {}) {
    return axios.get(`${this.url}/${funnelId}/board`, { params });
  }

  getForSettings() {
    return axios.get(this.url, { params: { include_inactive: true } });
  }

  move(funnelId, payload) {
    return axios.post(`${this.url}/${funnelId}/move`, payload);
  }
}

export default new CrmKanbanAPI();
