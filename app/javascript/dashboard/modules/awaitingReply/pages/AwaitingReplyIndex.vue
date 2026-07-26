<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useMapGetter } from 'dashboard/composables/store';
import { MANAGE_ALL_CONVERSATION_PERMISSIONS } from 'dashboard/constants/permissions';
import ConversationApi from 'dashboard/api/inbox/conversation';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { isAdmin } = useAdmin();
const { checkPermissions } = usePolicy();
const inboxes = useMapGetter('inboxes/getInboxes');

const items = ref([]);
const page = ref(1);
const hasMore = ref(false);
const isLoading = ref(false);
const isLoadingMore = ref(false);
const assigneeType = ref('all');
const status = ref('open');

const canViewAll = computed(
  () => isAdmin.value || checkPermissions([MANAGE_ALL_CONVERSATION_PERMISSIONS])
);

const assigneeOptions = computed(() => {
  const options = [{ value: 'me', label: t('AWAITING_REPLY.FILTER_MINE') }];
  if (canViewAll.value) {
    options.unshift({
      value: 'all',
      label: t('AWAITING_REPLY.FILTER_ALL'),
    });
  }
  return options;
});

const statusOptions = computed(() => [
  { value: 'open', label: t('AWAITING_REPLY.STATUS_OPEN') },
  { value: 'pending', label: t('AWAITING_REPLY.STATUS_PENDING') },
  { value: 'all', label: t('AWAITING_REPLY.STATUS_ALL') },
]);

const inboxName = inboxId =>
  inboxes.value.find(inbox => inbox.id === inboxId)?.name || '—';

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

const waitingSinceValue = conversation => {
  const value = conversation.waiting_since;
  return value && value > 0 ? value : null;
};

const buildParams = pageNumber => {
  let type = assigneeType.value;
  if (!canViewAll.value && type === 'all') type = 'me';

  return {
    conversationType: 'unattended',
    status: status.value,
    assigneeType: type,
    sortBy: 'waiting_since_asc',
    page: pageNumber,
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

watch([assigneeType, status], () => fetchPage());

onMounted(async () => {
  if (!canViewAll.value) assigneeType.value = 'me';
  await fetchPage();
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
        <Select v-model="assigneeType" :options="assigneeOptions" size="sm" />
        <Select v-model="status" :options="statusOptions" size="sm" />
        <Button
          icon="i-lucide-refresh-cw"
          slate
          xs
          faded
          :title="$t('AWAITING_REPLY.REFRESH')"
          @click="fetchPage()"
        />
      </div>
    </header>

    <div v-if="isLoading" class="flex flex-1 items-center justify-center">
      <Spinner />
    </div>

    <div
      v-else-if="!items.length"
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
              {{ $t('AWAITING_REPLY.COLUMNS.CONTACT') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.INBOX') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.ASSIGNEE') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.PRIORITY') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.STATUS') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('AWAITING_REPLY.COLUMNS.LAST_ACTIVITY') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="conversation in items"
            :key="conversation.id"
            class="border-b border-n-weak cursor-pointer hover:bg-n-alpha-2"
            @click="openConversation(conversation)"
          >
            <td class="px-4 py-3 text-n-slate-12 whitespace-nowrap">
              {{ formatDateTime(waitingSinceValue(conversation)) }}
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
              {{ conversation.priority || '—' }}
            </td>
            <td class="px-4 py-3 text-n-slate-11 capitalize">
              {{ conversation.status }}
            </td>
            <td class="px-4 py-3 text-n-slate-11 whitespace-nowrap">
              {{
                formatDateTime(
                  conversation.timestamp || conversation.last_activity_at
                )
              }}
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
