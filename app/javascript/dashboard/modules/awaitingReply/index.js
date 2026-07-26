import routes from './routes';

export default {
  id: 'awaitingReply',
  routes,
  sidebarItems({ t, accountScopedRoute }) {
    return [
      {
        name: 'Awaiting Reply',
        label: t('AWAITING_REPLY.SIDEBAR'),
        icon: 'i-lucide-message-circle-warning',
        to: accountScopedRoute('awaiting_reply_index'),
        activeOn: ['awaiting_reply_index'],
      },
    ];
  },
};
