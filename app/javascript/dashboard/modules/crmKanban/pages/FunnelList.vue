<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import CrmKanbanAPI from '../api';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const router = useRouter();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');

const funnels = ref([]);
const isLoading = ref(false);
const selectedInboxId = ref('');

const filteredFunnels = computed(() => {
  if (!selectedInboxId.value) return funnels.value;

  return funnels.value.filter(
    funnel => Number(funnel.inbox_id) === Number(selectedInboxId.value)
  );
});

const hasFunnels = computed(() => funnels.value.length > 0);
const hasFilteredFunnels = computed(() => filteredFunnels.value.length > 0);

const inboxName = inboxId => {
  if (!inboxId) return t('CRM_KANBAN.LIST.NO_INBOX');
  return (
    inboxes.value.find(inbox => inbox.id === inboxId)?.name ||
    t('CRM_KANBAN.LIST.NO_INBOX')
  );
};

const fetchFunnels = async () => {
  isLoading.value = true;
  try {
    const { data } = await CrmKanbanAPI.get();
    funnels.value = data.payload;
  } catch {
    useAlert(t('CRM_KANBAN.ERRORS.FETCH_FUNNELS'));
  } finally {
    isLoading.value = false;
  }
};

const openBoard = funnel => {
  router.push(accountScopedRoute('crm_kanban_board', { funnelId: funnel.id }));
};

onMounted(async () => {
  await store.dispatch('inboxes/get');
  await fetchFunnels();
});
</script>

<template>
  <div class="flex flex-col flex-1 w-full min-w-0 h-full bg-n-background">
    <header
      class="flex flex-wrap items-end justify-between gap-3 px-6 py-4 border-b border-n-weak w-full"
    >
      <div class="min-w-0">
        <h1 class="text-lg font-medium text-n-slate-12">
          {{ $t('CRM_KANBAN.LIST.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ $t('CRM_KANBAN.LIST.DESCRIPTION') }}
        </p>
      </div>
      <div class="w-56 shrink-0">
        <select
          v-model="selectedInboxId"
          class="w-full appearance-none rounded-lg border-0 outline-1 outline -outline-offset-1 outline-n-weak hover:outline-n-slate-6 focus:outline-n-blue-9 bg-n-surface-1 py-2 px-3 text-sm text-n-slate-12"
        >
          <option value="">
            {{ $t('CRM_KANBAN.LIST.ALL_INBOXES') }}
          </option>
          <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }}
          </option>
        </select>
      </div>
    </header>

    <div v-if="isLoading" class="flex flex-1 items-center justify-center">
      <Spinner />
    </div>

    <div
      v-else-if="!hasFunnels"
      class="flex flex-1 items-center justify-center p-6 text-center text-n-slate-11"
    >
      {{ $t('CRM_KANBAN.LIST.EMPTY_AGENT') }}
    </div>

    <div
      v-else-if="!hasFilteredFunnels"
      class="flex flex-1 items-center justify-center p-6 text-center text-n-slate-11"
    >
      {{ $t('CRM_KANBAN.LIST.EMPTY_FILTER') }}
    </div>

    <div
      v-else
      class="grid flex-1 w-full gap-4 p-6 sm:grid-cols-2 lg:grid-cols-3 content-start"
    >
      <button
        v-for="funnel in filteredFunnels"
        :key="funnel.id"
        type="button"
        class="flex flex-col gap-3 p-4 text-left bg-n-solid-1 border border-n-weak rounded-xl hover:border-n-brand transition-colors w-full min-w-0"
        @click="openBoard(funnel)"
      >
        <div class="flex items-start justify-between gap-2">
          <h2 class="text-base font-medium text-n-slate-12 truncate">
            {{ funnel.name }}
          </h2>
          <div
            class="flex flex-col items-end gap-0.5 shrink-0 text-xs text-n-slate-11"
          >
            <span>
              {{ funnel.stages.length }}
              {{ $t('CRM_KANBAN.LIST.STAGES') }}
            </span>
            <span
              class="max-w-[10rem] truncate"
              :title="inboxName(funnel.inbox_id)"
            >
              {{ inboxName(funnel.inbox_id) }}
            </span>
          </div>
        </div>

        <div v-if="funnel.stages.length" class="flex flex-wrap gap-1.5">
          <span
            v-for="stage in funnel.stages"
            :key="stage.id"
            class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 capitalize"
          >
            <span
              class="size-2 rounded-sm shrink-0"
              :style="{ backgroundColor: stage.label.color }"
            />
            {{ stage.label.title }}
          </span>
        </div>
      </button>
    </div>
  </div>
</template>
