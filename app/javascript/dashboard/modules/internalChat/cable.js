import { emitter } from 'shared/helpers/mitt';

export const INTERNAL_CHAT_EVENTS = {
  MESSAGE_CREATED: 'internal_chat.message_created',
  ROOM_UPDATED: 'internal_chat.room_updated',
  ROOM_CREATED: 'internal_chat.room_created',
  ROOM_DELETED: 'internal_chat.room_deleted',
};

export const onInternalChatEvent = (event, handler) => {
  emitter.on(event, handler);
  return () => emitter.off(event, handler);
};
