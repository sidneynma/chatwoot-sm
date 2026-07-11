import { frontendURL } from '../../helper/URLHelper';
import Index from './pages/Index.vue';
import { ROLES } from '../../constants/permissions';

export default [
  {
    path: frontendURL('accounts/:accountId/internal-chat'),
    name: 'internal_chat_index',
    component: Index,
    meta: {
      permissions: [...ROLES, 'custom_role'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/internal-chat/:roomId'),
    name: 'internal_chat_room',
    component: Index,
    meta: {
      permissions: [...ROLES, 'custom_role'],
    },
  },
];
