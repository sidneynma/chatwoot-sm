import { frontendURL } from '../../helper/URLHelper';
import SettingsWrapper from '../../routes/dashboard/settings/SettingsWrapper.vue';
import FunnelList from './pages/FunnelList.vue';
import Board from './pages/Board.vue';
import FunnelSettings from './pages/FunnelSettings.vue';
import { ROLES, CONVERSATION_PERMISSIONS } from '../../constants/permissions';

const crmPermissions = [...ROLES, ...CONVERSATION_PERMISSIONS, 'custom_role'];

export default [
  {
    path: frontendURL('accounts/:accountId/crm'),
    name: 'crm_kanban_index',
    component: FunnelList,
    meta: {
      permissions: crmPermissions,
    },
  },
  {
    path: frontendURL('accounts/:accountId/crm/:funnelId'),
    name: 'crm_kanban_board',
    component: Board,
    meta: {
      permissions: crmPermissions,
    },
  },
  {
    path: frontendURL('accounts/:accountId/settings/crm-funnels'),
    component: SettingsWrapper,
    children: [
      {
        path: '',
        name: 'crm_kanban_settings',
        component: FunnelSettings,
        meta: {
          permissions: ['administrator'],
        },
      },
    ],
  },
];
