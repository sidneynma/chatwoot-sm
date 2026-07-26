import { frontendURL } from '../../helper/URLHelper';
import { ROLES, CONVERSATION_PERMISSIONS } from '../../constants/permissions';
import AwaitingReplyIndex from './pages/AwaitingReplyIndex.vue';

const permissions = [...ROLES, ...CONVERSATION_PERMISSIONS, 'custom_role'];

export default [
  {
    path: frontendURL('accounts/:accountId/awaiting-reply'),
    name: 'awaiting_reply_index',
    component: AwaitingReplyIndex,
    meta: {
      permissions,
    },
  },
];
