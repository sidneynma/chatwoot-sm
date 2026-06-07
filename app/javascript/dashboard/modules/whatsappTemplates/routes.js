import { frontendURL } from '../../helper/URLHelper';
import Index from './pages/Index.vue';

export default [
  {
    path: frontendURL('accounts/:accountId/whatsapp/templates'),
    name: 'whatsapp_templates_index',
    component: Index,
    meta: {
      permissions: ['administrator'],
    },
  },
];
