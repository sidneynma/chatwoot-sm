import whatsappTemplates from './whatsappTemplates';
import conversationRedistribution from './conversationRedistribution';
import crmKanban from './crmKanban';

const customModules = [
  whatsappTemplates,
  conversationRedistribution,
  crmKanban,
];

export const customModuleRoutes = customModules.flatMap(
  module => module.routes || []
);

export const getCustomSidebarItems = context =>
  customModules.flatMap(module =>
    module.sidebarItems ? module.sidebarItems(context) : []
  );

export default customModules;
