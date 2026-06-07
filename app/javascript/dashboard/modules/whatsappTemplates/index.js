import routes from './routes';

export default {
  id: 'whatsappTemplates',
  routes,
  sidebarItems({ t, accountScopedRoute }) {
    return [
      {
        name: 'WhatsApp Admin',
        label: t('SIDEBAR.WHATSAPP'),
        icon: 'i-lucide-message-circle',
        children: [
          {
            name: 'WhatsApp Templates Admin',
            label: t('SIDEBAR.WHATSAPP_TEMPLATES'),
            to: accountScopedRoute('whatsapp_templates_index'),
            activeOn: ['whatsapp_templates_index'],
          },
        ],
      },
    ];
  },
};
