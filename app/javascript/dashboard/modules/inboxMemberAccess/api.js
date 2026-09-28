/* global axios */
import ApiClient from 'dashboard/api/ApiClient';

class InboxMemberAccessApi extends ApiClient {
  constructor() {
    super('inbox_member_access', { accountScoped: true });
  }

  updateMembers(inboxId, userIds) {
    return axios.patch(`${this.url}/${inboxId}`, { user_ids: userIds });
  }
}

export default new InboxMemberAccessApi();
