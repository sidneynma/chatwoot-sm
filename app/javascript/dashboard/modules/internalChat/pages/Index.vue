<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import InternalChatAPI from '../api';
import { INTERNAL_CHAT_EVENTS, onInternalChatEvent } from '../cable';
import RoomList from '../components/RoomList.vue';
import ChatPanel from '../components/ChatPanel.vue';
import GroupDialog from '../components/GroupDialog.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { accountScopedRoute } = useAccount();
const currentRole = useMapGetter('getCurrentRole');

const rooms = ref([]);
const messages = ref([]);
const activeRoom = ref(null);
const agentSearch = ref('');
const loadingMessages = ref(false);
const hasMore = ref(false);
const editingRoom = ref(null);
const groupDialogRef = ref(null);

const isAdmin = computed(() => currentRole.value === 'administrator');
const activeRoomId = computed(
  () => activeRoom.value?.id || route.params.roomId || null
);

const unsubscribers = [];

const sortRooms = list =>
  [...list].sort((a, b) => (b.last_message_at || 0) - (a.last_message_at || 0));

const loadRooms = async () => {
  try {
    const { data } = await InternalChatAPI.getRooms();
    rooms.value = sortRooms(data.payload || []);
    store.dispatch('internalChat/fetchUnreadCount');
  } catch (error) {
    useAlert(t('INTERNAL_CHAT.ERROR_LOAD'));
  }
};

const loadMessages = async ({ before } = {}) => {
  if (!activeRoom.value) return;
  loadingMessages.value = true;
  try {
    const { data } = await InternalChatAPI.getMessages(activeRoom.value.id, {
      before,
    });
    const payload = data.payload || [];
    if (before) {
      messages.value = [...payload, ...messages.value];
    } else {
      messages.value = payload;
    }
    hasMore.value = payload.length >= 50;
    await InternalChatAPI.markRead(activeRoom.value.id);
    const room = rooms.value.find(item => item.id === activeRoom.value.id);
    if (room) room.unread_count = 0;
    store.dispatch('internalChat/fetchUnreadCount');
  } catch (error) {
    useAlert(t('INTERNAL_CHAT.ERROR_LOAD'));
  } finally {
    loadingMessages.value = false;
  }
};

const selectRoom = async room => {
  activeRoom.value = room;
  messages.value = [];
  router.replace(accountScopedRoute('internal_chat_room', { roomId: room.id }));
  await loadMessages();
};

const openRoomById = async roomId => {
  if (!roomId) return;
  let room = rooms.value.find(item => item.id === Number(roomId));
  if (!room) {
    const { data } = await InternalChatAPI.getRoom(roomId);
    room = data.payload;
    rooms.value = sortRooms([
      room,
      ...rooms.value.filter(item => item.id !== room.id),
    ]);
  }
  await selectRoom(room);
};

const startDirect = async agent => {
  try {
    const { data } = await InternalChatAPI.createDirect(agent.id);
    const room = data.payload;
    rooms.value = sortRooms([
      room,
      ...rooms.value.filter(item => item.id !== room.id),
    ]);
    agentSearch.value = '';
    await selectRoom(room);
  } catch (error) {
    useAlert(error?.response?.data?.error || t('INTERNAL_CHAT.ERROR_LOAD'));
  }
};

const openFromSearch = async room => {
  try {
    let payload = room;
    if (room.closed) {
      const { data } = await InternalChatAPI.reopenRoom(room.id);
      payload = data.payload;
    }
    rooms.value = sortRooms([
      payload,
      ...rooms.value.filter(item => item.id !== payload.id),
    ]);
    agentSearch.value = '';
    await selectRoom(payload);
  } catch (error) {
    useAlert(error?.response?.data?.error || t('INTERNAL_CHAT.ERROR_LOAD'));
  }
};

const sendMessage = async payload => {
  if (!activeRoom.value) return;
  try {
    const { data } = await InternalChatAPI.sendMessage(activeRoom.value.id, {
      content: payload.content,
      blobSignedIds: payload.blobSignedIds,
      isVoice: payload.isVoice,
    });
    const message = data.payload;
    if (message && !messages.value.some(item => item.id === message.id)) {
      messages.value = [...messages.value, message];
    }
    const room = rooms.value.find(item => item.id === activeRoom.value.id);
    if (room) {
      room.last_message_at =
        message?.created_at || Math.floor(Date.now() / 1000);
      rooms.value = sortRooms(rooms.value);
    }
    payload.onSuccess?.();
  } catch (error) {
    const apiError = error?.response?.data?.error;
    let landed = false;
    try {
      const beforeCount = messages.value.length;
      await loadMessages();
      landed =
        messages.value.length > beforeCount ||
        messages.value.some(
          item =>
            item.content === payload.content &&
            item.sender?.id === store.getters.getCurrentUserID
        );
      if (activeRoom.value) {
        const { data } = await InternalChatAPI.getRoom(activeRoom.value.id);
        activeRoom.value = data.payload;
        const idx = rooms.value.findIndex(
          item => item.id === activeRoom.value.id
        );
        if (idx >= 0) rooms.value[idx] = data.payload;
      }
    } catch {
      // ignore refresh errors
    }
    if (landed) {
      payload.onSuccess?.();
      return;
    }
    payload.onError?.();
    useAlert(apiError || t('INTERNAL_CHAT.ERROR_SEND'));
  }
};

const openCreateGroup = () => {
  editingRoom.value = null;
  groupDialogRef.value?.open();
};

const openEditGroup = () => {
  editingRoom.value = activeRoom.value;
  groupDialogRef.value?.open();
};

const saveGroup = async ({ name, memberIds }) => {
  try {
    const response = editingRoom.value
      ? await InternalChatAPI.updateGroup(editingRoom.value.id, {
          name,
          memberIds,
        })
      : await InternalChatAPI.createGroup({ name, memberIds });
    const room = response.data.payload;
    rooms.value = sortRooms([
      room,
      ...rooms.value.filter(item => item.id !== room.id),
    ]);
    groupDialogRef.value?.close();
    await selectRoom(room);
  } catch (error) {
    useAlert(t('INTERNAL_CHAT.ERROR_SAVE'));
  }
};

const deleteGroup = async () => {
  if (!activeRoom.value || activeRoom.value.room_type !== 'group') return;
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('INTERNAL_CHAT.DELETE_CONFIRM'))) return;
  try {
    const roomId = activeRoom.value.id;
    await InternalChatAPI.deleteRoom(roomId);
    rooms.value = rooms.value.filter(item => item.id !== roomId);
    activeRoom.value = null;
    messages.value = [];
    router.replace(accountScopedRoute('internal_chat_index'));
  } catch (error) {
    useAlert(t('INTERNAL_CHAT.ERROR_SAVE'));
  }
};

const closeRoom = async () => {
  if (!activeRoom.value) return;
  try {
    const roomId = activeRoom.value.id;
    await InternalChatAPI.closeRoom(roomId);
    rooms.value = rooms.value.filter(item => item.id !== roomId);
    activeRoom.value = null;
    messages.value = [];
    store.dispatch('internalChat/fetchUnreadCount');
    router.replace(accountScopedRoute('internal_chat_index'));
  } catch (error) {
    useAlert(t('INTERNAL_CHAT.ERROR_CLOSE'));
  }
};

const onMessageCreated = data => {
  if (!data?.room_id) return;
  const room = rooms.value.find(item => item.id === data.room_id);
  if (room) {
    room.last_message_at = data.created_at;
    if (activeRoom.value?.id !== data.room_id) {
      room.unread_count = (room.unread_count || 0) + 1;
    }
    rooms.value = sortRooms(rooms.value);
  } else {
    // Closed room reopened by a new message — refresh open list.
    loadRooms();
  }

  if (activeRoom.value?.id === data.room_id) {
    if (!messages.value.some(item => item.id === data.id)) {
      messages.value = [...messages.value, data];
    }
    InternalChatAPI.markRead(data.room_id).then(() => {
      store.dispatch('internalChat/fetchUnreadCount');
    });
  }
};

const onRoomChanged = () => loadRooms();

const onRoomDeleted = data => {
  rooms.value = rooms.value.filter(item => item.id !== data.id);
  if (activeRoom.value?.id === data.id) {
    activeRoom.value = null;
    messages.value = [];
    router.replace(accountScopedRoute('internal_chat_index'));
  }
};

onMounted(async () => {
  store.dispatch('agents/get');
  await loadRooms();
  if (route.params.roomId) {
    await openRoomById(route.params.roomId);
  }

  unsubscribers.push(
    onInternalChatEvent(INTERNAL_CHAT_EVENTS.MESSAGE_CREATED, onMessageCreated),
    onInternalChatEvent(INTERNAL_CHAT_EVENTS.ROOM_UPDATED, onRoomChanged),
    onInternalChatEvent(INTERNAL_CHAT_EVENTS.ROOM_CREATED, onRoomChanged),
    onInternalChatEvent(INTERNAL_CHAT_EVENTS.ROOM_DELETED, onRoomDeleted)
  );
});

onUnmounted(() => {
  unsubscribers.forEach(unsubscribe => unsubscribe?.());
});

watch(
  () => route.params.roomId,
  roomId => {
    if (roomId && Number(roomId) !== activeRoom.value?.id) {
      openRoomById(roomId);
    }
  }
);
</script>

<template>
  <div class="flex h-full w-full min-w-0 flex-col bg-n-background">
    <header
      class="flex shrink-0 items-center justify-between border-b border-n-weak px-4 py-3"
    >
      <h1 class="text-lg font-medium text-n-slate-12">
        {{ t('INTERNAL_CHAT.TITLE') }}
      </h1>
      <Button
        v-if="isAdmin"
        :label="t('INTERNAL_CHAT.NEW_GROUP')"
        size="sm"
        color="blue"
        icon="i-lucide-users"
        @click="openCreateGroup"
      />
    </header>

    <div class="flex min-h-0 min-w-0 flex-1">
      <RoomList
        :rooms="rooms"
        :active-room-id="activeRoomId"
        :search="agentSearch"
        @update:search="value => (agentSearch = value)"
        @select="selectRoom"
        @start-direct="startDirect"
        @open-room="openFromSearch"
      />
      <ChatPanel
        :room="activeRoom"
        :messages="messages"
        :is-admin="isAdmin"
        :loading="loadingMessages"
        :has-more="hasMore"
        @send="sendMessage"
        @load-more="loadMessages({ before: messages[0]?.id })"
        @edit-group="openEditGroup"
        @delete-group="deleteGroup"
        @close="closeRoom"
      />
    </div>

    <GroupDialog ref="groupDialogRef" :room="editingRoom" @save="saveGroup" />
  </div>
</template>
