import whatsappTemplates from './whatsappTemplates';
import conversationRedistribution from './conversationRedistribution';
import crmKanban from './crmKanban';
import internalChat from './internalChat';
import disparador from './disparador';
import awaitingReply from './awaitingReply';
import inboxMemberAccess from './inboxMemberAccess';

const customModules = [
  whatsappTemplates,
  conversationRedistribution,
  crmKanban,
  internalChat,
  disparador,
  awaitingReply,
  inboxMemberAccess,
];

export const customModuleRoutes = customModules.flatMap(
  module => module.routes || []
);

export const getCustomSidebarItems = context =>
  customModules.flatMap(module =>
    module.sidebarItems ? module.sidebarItems(context) : []
  );

export default customModules;
