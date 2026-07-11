import routes from './routes';

export default {
  id: 'internalChat',
  routes,
  sidebarItems({ t, accountScopedRoute }) {
    return [
      {
        name: 'Internal Chat',
        label: t('SIDEBAR.INTERNAL_CHAT'),
        icon: 'i-lucide-message-square',
        to: accountScopedRoute('internal_chat_index'),
        activeOn: ['internal_chat_index', 'internal_chat_room'],
      },
    ];
  },
};
