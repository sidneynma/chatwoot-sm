import routes from './routes';

const moduleEnabled = (chatolheModules, name) =>
  Boolean(chatolheModules && chatolheModules[name]);

export default {
  id: 'disparador',
  routes,
  sidebarItems({ t, accountScopedRoute, chatolheModules = {} }) {
    const children = [];

    if (moduleEnabled(chatolheModules, 'disparador')) {
      children.push({
        name: 'Disparador Campaigns',
        label: t('SIDEBAR.DISPARADOR_CAMPAIGNS'),
        to: accountScopedRoute('disparador_campaigns_index'),
        activeOn: ['disparador_campaigns_index', 'disparador_campaign_show'],
      });
    }

    if (moduleEnabled(chatolheModules, 'mensagens_agendadas')) {
      children.push({
        name: 'Disparador Schedules',
        label: t('SIDEBAR.DISPARADOR_SCHEDULES'),
        to: accountScopedRoute('disparador_schedules_index'),
        activeOn: ['disparador_schedules_index'],
      });
    }

    if (!children.length) {
      return [];
    }

    return [
      {
        name: 'Disparador',
        label: t('SIDEBAR.DISPARADOR'),
        icon: 'i-lucide-send',
        children,
      },
    ];
  },
};
