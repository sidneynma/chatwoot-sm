/* global axios */
import ApiClient from '../../api/ApiClient';

class DisparadorCampaignsAPI extends ApiClient {
  constructor() {
    super('disparador_campaigns', { accountScoped: true });
  }

  getCampaigns(params = {}) {
    return axios.get(this.url, { params });
  }

  getCampaign(id) {
    return axios.get(`${this.url}/${id}`);
  }

  createCampaign(payload) {
    return axios.post(this.url, payload);
  }

  updateCampaign(id, payload) {
    return axios.patch(`${this.url}/${id}`, payload);
  }

  archiveCampaign(id) {
    return axios.post(`${this.url}/${id}/archive`);
  }

  unarchiveCampaign(id) {
    return axios.post(`${this.url}/${id}/unarchive`);
  }

  deleteCampaign(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  dispatchCampaign(id, payload = {}) {
    return axios.post(`${this.url}/${id}/dispatch`, payload);
  }

  retryFailed(id, payload = {}) {
    return axios.post(`${this.url}/${id}/retry_failed`, payload);
  }

  getStats(id) {
    return axios.get(`${this.url}/${id}/stats`);
  }

  getDispatchStatus(id) {
    return axios.get(`${this.url}/${id}/dispatch_status`);
  }

  getRecipients(campaignId, params = {}) {
    return axios.get(`${this.url}/${campaignId}/recipients`, { params });
  }

  addRecipients(campaignId, recipients) {
    return axios.post(`${this.url}/${campaignId}/recipients`, { recipients });
  }

  exportCampaigns(params = {}) {
    return axios.get(`${this.url}/export`, {
      params,
      responseType: 'blob',
    });
  }

  uploadMedia(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(`${this.url}/upload_media`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  getSchedules(params = {}) {
    return axios.get(this.schedulesUrl, { params });
  }

  createSchedule(payload) {
    return axios.post(this.schedulesUrl, payload);
  }

  updateSchedule(id, payload) {
    return axios.patch(`${this.schedulesUrl}/${id}`, payload);
  }

  cancelSchedule(id) {
    return axios.delete(`${this.schedulesUrl}/${id}`);
  }

  get schedulesUrl() {
    return `${this.baseUrl()}/disparador_schedules`;
  }
}

export default new DisparadorCampaignsAPI();
