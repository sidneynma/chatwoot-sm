/* global axios */
import ApiClient from '../../api/ApiClient';

class InternalChatAPI extends ApiClient {
  constructor() {
    super('internal_chat/rooms', { accountScoped: true });
  }

  getRooms() {
    return axios.get(this.url);
  }

  searchRooms(query) {
    return axios.get(`${this.url}/search`, { params: { q: query } });
  }

  getRoom(id) {
    return axios.get(`${this.url}/${id}`);
  }

  createGroup({ name, memberIds }) {
    return axios.post(this.url, {
      room: { name, member_ids: memberIds },
    });
  }

  updateGroup(id, { name, memberIds }) {
    return axios.patch(`${this.url}/${id}`, {
      room: { name, member_ids: memberIds },
    });
  }

  deleteRoom(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  createDirect(userId) {
    return axios.post(`${this.url}/direct`, { user_id: userId });
  }

  markRead(id) {
    return axios.post(`${this.url}/${id}/mark_read`);
  }

  closeRoom(id) {
    return axios.post(`${this.url}/${id}/close`);
  }

  reopenRoom(id) {
    return axios.post(`${this.url}/${id}/reopen`);
  }

  getMessages(roomId, { before } = {}) {
    return axios.get(`${this.url}/${roomId}/messages`, {
      params: { before },
    });
  }

  sendMessage(roomId, { content, blobSignedIds, isVoice }) {
    return axios.post(`${this.url}/${roomId}/messages`, {
      content,
      blob_signed_ids: blobSignedIds,
      is_voice: isVoice,
    });
  }

  addMember(roomId, userId) {
    return axios.post(`${this.url}/${roomId}/members`, { user_id: userId });
  }

  removeMember(roomId, userId) {
    return axios.delete(`${this.url}/${roomId}/members/${userId}`);
  }
}

export default new InternalChatAPI();
