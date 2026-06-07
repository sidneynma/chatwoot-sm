import whatsappTemplates from './whatsappTemplates';

const customModules = [whatsappTemplates];

export const customModuleRoutes = customModules.flatMap(
  module => module.routes || []
);

export const getCustomSidebarItems = context =>
  customModules.flatMap(module =>
    module.sidebarItems ? module.sidebarItems(context) : []
  );

export default customModules;
