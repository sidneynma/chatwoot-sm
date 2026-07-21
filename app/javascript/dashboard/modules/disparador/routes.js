import { frontendURL } from '../../helper/URLHelper';
import CampaignsIndex from './pages/CampaignsIndex.vue';
import CampaignDetail from './pages/CampaignDetail.vue';
import SchedulesIndex from './pages/SchedulesIndex.vue';

const agentPermissions = ['administrator', 'agent'];

export default [
  {
    path: frontendURL('accounts/:accountId/disparador/campanhas'),
    name: 'disparador_campaigns_index',
    component: CampaignsIndex,
    meta: {
      permissions: agentPermissions,
    },
  },
  {
    path: frontendURL('accounts/:accountId/disparador/campanhas/:campaignId'),
    name: 'disparador_campaign_show',
    component: CampaignDetail,
    meta: {
      permissions: agentPermissions,
    },
  },
  {
    path: frontendURL('accounts/:accountId/disparador/agendamentos'),
    name: 'disparador_schedules_index',
    component: SchedulesIndex,
    meta: {
      permissions: agentPermissions,
    },
  },
];
