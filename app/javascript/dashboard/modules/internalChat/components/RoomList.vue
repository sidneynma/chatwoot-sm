<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import InternalChatAPI from '../api';

const props = defineProps({
  rooms: { type: Array, default: () => [] },
  activeRoomId: { type: [Number, String], default: null },
  search: { type: String, default: '' },
});

const emit = defineEmits([
  'select',
  'update:search',
  'start-direct',
  'open-room',
]);

const { t } = useI18n();
const agents = useMapGetter('agents/getAgents');
const currentUserId = useMapGetter('getCurrentUserID');

const searchResults = ref([]);
const searching = ref(false);
let searchTimer = null;

const agentQuery = computed({
  get: () => props.search,
  set: value => emit('update:search', value),
});

const filteredAgents = computed(() => {
  const query = agentQuery.value.trim().toLowerCase();
  if (!query) return [];

  const resultIds = new Set(
    searchResults.value
      .filter(room => room.room_type === 'direct')
      .flatMap(room => (room.members || []).map(member => member.id))
  );

  return agents.value
    .filter(agent => agent.id !== currentUserId.value)
    .filter(agent =>
      [agent.name, agent.available_name, agent.email]
        .filter(Boolean)
        .some(value => value.toLowerCase().includes(query))
    )
    .filter(agent => !resultIds.has(agent.id))
    .slice(0, 8);
});

const runSearch = async query => {
  const q = query.trim();
  if (!q) {
    searchResults.value = [];
    return;
  }
  searching.value = true;
  try {
    const { data } = await InternalChatAPI.searchRooms(q);
    searchResults.value = data.payload || [];
  } catch {
    searchResults.value = [];
  } finally {
    searching.value = false;
  }
};

watch(
  () => props.search,
  value => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => runSearch(value), 250);
  }
);

const resultLabel = room => {
  if (room.peer_inactive) return t('INTERNAL_CHAT.AGENT_INACTIVE_LABEL');
  if (room.closed) return t('INTERNAL_CHAT.CLOSED_LABEL');
  if (room.room_type === 'group') return t('INTERNAL_CHAT.GROUP');
  return t('INTERNAL_CHAT.DIRECT');
};
</script>

<template>
  <aside
    class="flex h-full w-80 shrink-0 flex-col border-r border-n-weak bg-n-solid-1"
  >
    <div class="border-b border-n-weak p-3">
      <input
        v-model="agentQuery"
        type="search"
        class="w-full rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
        :placeholder="t('INTERNAL_CHAT.SEARCH_AGENT')"
      />
    </div>

    <div v-if="agentQuery.trim()" class="border-b border-n-weak px-2 py-2">
      <p v-if="searching" class="px-2 py-2 text-xs text-n-slate-11">
        {{ t('INTERNAL_CHAT.SEARCHING') }}
      </p>
      <template v-else>
        <button
          v-for="room in searchResults"
          :key="`room-${room.id}`"
          type="button"
          class="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-n-alpha-2"
          @click="emit('open-room', room)"
        >
          <Avatar
            :name="room.name"
            :src="room.members?.[0]?.thumbnail"
            :size="32"
            rounded-full
          />
          <div class="min-w-0 flex-1">
            <span class="block truncate text-sm text-n-slate-12">{{
              room.name
            }}</span>
            <span class="text-xs text-n-slate-11">{{ resultLabel(room) }}</span>
          </div>
        </button>
        <button
          v-for="agent in filteredAgents"
          :key="`agent-${agent.id}`"
          type="button"
          class="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-n-alpha-2"
          @click="emit('start-direct', agent)"
        >
          <Avatar
            :name="agent.name"
            :src="agent.thumbnail"
            :size="32"
            rounded-full
          />
          <span class="truncate text-sm text-n-slate-12">{{
            agent.available_name || agent.name
          }}</span>
        </button>
        <p
          v-if="!searchResults.length && !filteredAgents.length"
          class="px-2 py-2 text-xs text-n-slate-11"
        >
          {{ t('INTERNAL_CHAT.NO_AGENTS') }}
        </p>
      </template>
    </div>

    <div class="flex-1 overflow-y-auto p-2">
      <p
        v-if="!rooms.length"
        class="px-2 py-6 text-center text-sm text-n-slate-11"
      >
        {{ t('INTERNAL_CHAT.EMPTY_ROOMS') }}
      </p>
      <button
        v-for="room in rooms"
        :key="room.id"
        type="button"
        class="mb-1 flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left transition-colors"
        :class="
          Number(activeRoomId) === room.id
            ? 'bg-n-alpha-2'
            : 'hover:bg-n-alpha-2'
        "
        @click="emit('select', room)"
      >
        <Avatar
          :name="room.name"
          :src="room.members?.[0]?.thumbnail"
          :size="36"
          rounded-full
        />
        <div class="min-w-0 flex-1">
          <div class="flex items-center justify-between gap-2">
            <span class="truncate text-sm font-medium text-n-slate-12">{{
              room.name
            }}</span>
            <span
              v-if="room.unread_count"
              class="rounded-full bg-n-brand px-1.5 text-xs text-white"
            >
              {{ room.unread_count }}
            </span>
          </div>
          <span class="text-xs text-n-slate-11">
            <template v-if="room.peer_inactive">
              {{ t('INTERNAL_CHAT.AGENT_INACTIVE_LABEL') }}
            </template>
            <template v-else-if="room.room_type === 'group'">
              {{ t('INTERNAL_CHAT.GROUP') }}
            </template>
            <template v-else>
              {{ t('INTERNAL_CHAT.DIRECT') }}
            </template>
          </span>
        </div>
      </button>
    </div>
  </aside>
</template>
