/* global axios */
import ApiClient from '../../api/ApiClient';

class WhatsappTemplatesAPI extends ApiClient {
  constructor() {
    super('whatsapp/templates', { accountScoped: true });
  }

  get(inboxId) {
    return axios.get(this.url, { params: { inbox_id: inboxId } });
  }

  create(inboxId, template) {
    return axios.post(this.url, { inbox_id: inboxId, template });
  }

  delete(inboxId, name) {
    return axios.delete(`${this.url}/${name}`, {
      params: { inbox_id: inboxId },
    });
  }

  uploadMedia(inboxId, file, headerFormat) {
    const formData = new FormData();
    formData.append('inbox_id', inboxId);
    formData.append('header_format', headerFormat);
    formData.append('file', file);

    return axios.post(`${this.url}/upload_media`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  uploadHeaderMedia(file) {
    const formData = new FormData();
    formData.append('file', file);

    return axios.post(
      `${this.baseUrl()}/whatsapp/template_header_media`,
      formData,
      {
        headers: { 'Content-Type': 'multipart/form-data' },
      }
    );
  }
}

export default new WhatsappTemplatesAPI();
