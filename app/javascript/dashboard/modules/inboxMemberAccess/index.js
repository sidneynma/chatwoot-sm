import routes from './routes';

export default {
  id: 'inboxMemberAccess',
  routes,
  sidebarItems({ t, accountScopedRoute }) {
    return [
      {
        name: 'Inbox member access',
        label: t('INBOX_MEMBER_ACCESS.SIDEBAR'),
        icon: 'i-lucide-user-plus',
        to: accountScopedRoute('inbox_member_access_index'),
        activeOn: ['inbox_member_access_index'],
      },
    ];
  },
};
