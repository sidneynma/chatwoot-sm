import { frontendURL } from '../../helper/URLHelper';

export default [
  {
    path: frontendURL('accounts/:accountId/settings/inbox-members'),
    name: 'inbox_member_access_index',
    component: () => import('./pages/InboxMemberAccessIndex.vue'),
    meta: {
      permissions: ['administrator', 'inbox_member_manage'],
    },
  },
];
