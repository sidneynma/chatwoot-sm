import { frontendURL } from '../../helper/URLHelper';
import SettingsWrapper from '../../routes/dashboard/settings/SettingsWrapper.vue';
import Index from './pages/Index.vue';

export default [
  {
    path: frontendURL(
      'accounts/:accountId/settings/conversation-redistribution'
    ),
    component: SettingsWrapper,
    children: [
      {
        path: '',
        name: 'conversation_redistribution_index',
        component: Index,
        meta: {
          permissions: ['administrator'],
        },
      },
    ],
  },
];
