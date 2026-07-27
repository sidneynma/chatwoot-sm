import routes from './routes';

export default {
  id: 'awaitingReply',
  routes,
  sidebarItems({ t, accountScopedRoute }) {
    return [
      {
        name: 'Awaiting Reply',
        label: t('AWAITING_REPLY.SIDEBAR'),
        // Same icon as native "Unattended" — avoid unknown icons in sidebar render.
        icon: 'i-lucide-clock-alert',
        to: accountScopedRoute('awaiting_reply_index'),
        activeOn: ['awaiting_reply_index'],
      },
    ];
  },
};
