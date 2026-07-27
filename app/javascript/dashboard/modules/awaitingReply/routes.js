import { frontendURL } from '../../helper/URLHelper';
import { ROLES, CONVERSATION_PERMISSIONS } from '../../constants/permissions';

const permissions = [...ROLES, ...CONVERSATION_PERMISSIONS, 'custom_role'];

export default [
  {
    path: frontendURL('accounts/:accountId/awaiting-reply'),
    name: 'awaiting_reply_index',
    // Lazy chunk: page JS only loads when the route is opened (not on every inbox boot).
    component: () => import('./pages/AwaitingReplyIndex.vue'),
    meta: {
      permissions,
    },
  },
];
