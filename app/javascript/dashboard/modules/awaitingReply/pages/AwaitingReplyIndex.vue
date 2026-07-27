<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import {
  getUserPermissions,
  hasPermissions,
} from 'dashboard/helper/permissionsHelper';
import { MANAGE_ALL_CONVERSATION_PERMISSIONS } from 'dashboard/constants/permissions';
import ConversationApi from 'dashboard/api/inbox/conversation';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const router = useRouter();
const { accountId, accountScopedRoute } = useAccount();
const inboxes = useMapGetter('inboxes/getInboxes');
const currentUser = useMapGetter('getCurrentUser');

const items = ref([]);
const page = ref(1);
const hasMore = ref(false);
const isLoading = ref(false);
const isLoadingMore = ref(false);
const inboxId = ref('');
const waitMinSeconds = ref(0);
const assigneeType = ref('me');

const userPermissions = computed(() =>
  getUserPermissions(currentUser.value, accountId.value)
);

const canViewAll = computed(() =>
  hasPermissions(
    ['administrator', MANAGE_ALL_CONVERSATION_PERMISSIONS],
    userPermissions.value
  )
);

const inboxOptions = computed(() => [
  { value: '', label: t('AWAITING_REPLY.FILTER_INBOX_ALL') },
  ...inboxes.value.map(inbox => ({
    value: String(inbox.id),
    label: inbox.name,
  })),
]);

const waitOptions = computed(() => [
  { value: 0, label: t('AWAITING_REPLY.FILTER_WAIT_ALL') },
  { value: 5 * 60, label: t('AWAITING_REPLY.FILTER_WAIT_5M') },
  { value: 15 * 60, label: t('AWAITING_REPLY.FILTER_WAIT_15M') },
  { value: 30 * 60, label: t('AWAITING_REPLY.FILTER_WAIT_30M') },
  { value: 60 * 60, label: t('AWAITING_REPLY.FILTER_WAIT_1H') },
  { value: 2 * 60 * 60, label: t('AWAITING_REPLY.FILTER_WAIT_2H') },
]);

const assigneeOptions = computed(() => {
  const options = [
    { value: 'me', label: t('AWAITING_REPLY.FILTER_ASSIGNEE_MINE') },
  ];
  if (canViewAll.value) {
    options.unshift({
      value: 'all',
      label: t('AWAITING_REPLY.FILTER_ASSIGNEE_ALL'),
    });
  }
  return options;
});

const inboxName = id =>
  inboxes.value.find(inbox => inbox.id === id)?.name || '—';

const formatDateTime = value => {
  if (!value) return '—';
  const date =
    typeof value === 'number' ? new Date(value * 1000) : new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const waitingSeconds = conversation => {
  const since = Number(conversation.waiting_since);
  if (!since) return null;
  return Math.max(0, Math.floor(Date.now() / 1000 - since));
};

const formatWaitDuration = conversation => {
  const seconds = waitingSeconds(conversation);
  if (seconds == null) return '—';
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)} min`;
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  return mins ? `${hours} h ${mins} min` : `${hours} h`;
};

const visibleItems = computed(() => {
  const minWait = Number(waitMinSeconds.value) || 0;
  if (!minWait) return items.value;
  return items.value.filter(conversation => {
    const seconds = waitingSeconds(conversation);
    return seconds != null && seconds >= minWait;
  });
});

const buildParams = pageNumber => {
  let type = assigneeType.value;
  if (!canViewAll.value && type === 'all') type = 'me';

  return {
    conversationType: 'unattended',
    status: 'open',
    assigneeType: type,
    sortBy: 'waiting_since_asc',
    page: pageNumber,
    inboxId: inboxId.value ? Number(inboxId.value) : undefined,
  };
};

const fetchPage = async ({ append = false } = {}) => {
  if (append) {
    isLoadingMore.value = true;
  } else {
    isLoading.value = true;
    page.value = 1;
    items.value = [];
  }

  try {
    const currentPage = append ? page.value + 1 : 1;
    const {
      data: { data },
    } = await ConversationApi.get(buildParams(currentPage));
    const payload = data?.payload || [];
    items.value = append ? [...items.value, ...payload] : payload;
    page.value = currentPage;
    hasMore.value = payload.length >= 25;
  } catch {
    useAlert(t('AWAITING_REPLY.ERRORS.FETCH'));
    if (!append) items.value = [];
    hasMore.value = false;
  } finally {
    isLoading.value = false;
    isLoadingMore.value = false;
  }
};

const openConversation = conversation => {
  router.push(
    accountScopedRoute('inbox_conversation', {
      conversation_id: conversation.id,
    })
  );
};

watch([inboxId, assigneeType], () => fetchPage());

onMounted(() => {
  if (canViewAll.value) assigneeType.value = 'all';
  fetchPage();
});
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full min-w-0 h-full overflow-hidden bg-n-background"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-3 px-6 py-4 border-b border-n-weak"
    >
      <div class="min-w-0">
        <h1 class="text-lg font-medium text-n-slate-12">
          {{ $t('AWAITING_REPLY.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ $t('AWAITING_REPLY.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <label class="flex flex-col gap-0.5 text-xs text-n-slate-11">
          {{ $t('AWAITING_REPLY.FILTER_INBOX') }}
          <select
            v-model="inboxId"
            class="h-9 min-w-[10rem] rounded-lg border-0 bg-n-solid-2 px-2 text-sm text-n-slate-12 outline-1 -outline-offset-1 outline-n-weak"
          >
            <option
              v-for="option in inboxOptions"
              :key="`inbox-${option.value}`"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-0.5 text-xs text-n-slate-11">
          {{ $t('AWAITING_REPLY.FILTER_WAIT') }}
          <select
            v-model.number="waitMinSeconds"
            class="h-9 min-w-[10rem] rounded-lg border-0 bg-n-solid-2 px-2 text-sm text-n-slate-12 outline-1 -outline-offset-1 outline-n-weak"
          >
            <option
              v-for="option in waitOptions"
              :key="`wait-${option.value}`"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-0.5 text-xs text-n-slate-11">
          {{ $t('AWAITING_REPLY.FILTER_ASSIGNEE') }}
          <select
            v-model="assigneeType"
            class="h-9 min-w-[8rem] rounded-lg border-0 bg-n-solid-2 px-2 text-sm text-n-slate-12 outline-1 -outline-offset-1 outline-n-weak"
          >
            <option
              v-for="option in assigneeOptions"
              :key="`assignee-${option.value}`"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
        <Button
          icon="i-lucide-refresh-cw"
          slate
          xs
          faded
          class="self-end"
          :title="$t('AWAITING_REPLY.REFRESH')"
          @click="fetchPage()"
        />
      </div>
    </header>

    <div v-if="isLoading" class="flex flex-1 items-center justify-center">
      <Spinner />
    </div>

    <div
      v-else-if="!visibleItems.length"
      class="flex flex-1 items-center justify-center px-6 text-sm text-n-slate-11"
    >
      {{ $t('AWAITING_REPLY.EMPTY') }}
    </div>

    <div v-else class="flex-1 overflow-auto">
      <table class="w-full text-sm text-left">
        <thead class="sticky top-0 bg-n-background border-b border-n-weak">
          <tr class="text-n-slate-11">
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.WAITING') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.SINCE') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.CONTACT') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.INBOX') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.ASSIGNEE') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.STATUS') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="conversation in visibleItems"
            :key="conversation.id"
            class="border-b border-n-weak cursor-pointer hover:bg-n-alpha-2"
            @click="openConversation(conversation)"
          >
            <td class="px-4 py-3 font-medium text-n-slate-12 whitespace-nowrap">
              {{ formatWaitDuration(conversation) }}
            </td>
            <td class="px-4 py-3 text-n-slate-11 whitespace-nowrap">
              {{ formatDateTime(conversation.waiting_since) }}
            </td>
            <td class="px-4 py-3 text-n-slate-12">
              <div class="font-medium">
                {{ conversation.meta?.sender?.name || '—' }}
              </div>
              <div class="text-xs text-n-slate-11">
                {{
                  conversation.meta?.sender?.phone_number ||
                  conversation.meta?.sender?.email ||
                  `#${conversation.id}`
                }}
              </div>
            </td>
            <td class="px-4 py-3 text-n-slate-11">
              {{ inboxName(conversation.inbox_id) }}
            </td>
            <td class="px-4 py-3 text-n-slate-11">
              {{ conversation.meta?.assignee?.name || '—' }}
            </td>
            <td class="px-4 py-3 text-n-slate-11 capitalize">
              {{ conversation.status }}
            </td>
          </tr>
        </tbody>
      </table>

      <div v-if="hasMore" class="flex justify-center p-4">
        <Button
          slate
          faded
          sm
          :label="$t('AWAITING_REPLY.LOAD_MORE')"
          :is-loading="isLoadingMore"
          @click="fetchPage({ append: true })"
        />
      </div>
    </div>
  </div>
</template>
