import routes from './routes';

export default {
  id: 'internalChat',
  routes,
  sidebarItems({ t, accountScopedRoute }) {
    return [
      {
        name: 'Internal Chat',
        label: t('SIDEBAR.INTERNAL_CHAT'),
        // Remix icon already used elsewhere in the build (inbox helpers / emoji picker).
        icon: 'i-ri-chat-1-line',
        to: accountScopedRoute('internal_chat_index'),
        activeOn: ['internal_chat_index', 'internal_chat_room'],
        getterKeys: {
          count: 'internalChat/getUnreadCount',
        },
      },
    ];
  },
};
