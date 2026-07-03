<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import CrmKanbanAPI from '../api';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const router = useRouter();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();

const funnels = ref([]);
const isLoading = ref(false);

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

const hasFunnels = computed(() => funnels.value.length > 0);

onMounted(fetchFunnels);
</script>

<template>
  <div class="flex flex-col h-full bg-n-background">
    <header class="px-6 py-4 border-b border-n-weak">
      <h1 class="text-lg font-medium text-n-slate-12">
        {{ $t('CRM_KANBAN.LIST.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ $t('CRM_KANBAN.LIST.DESCRIPTION') }}
      </p>
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

    <div v-else class="grid gap-4 p-6 sm:grid-cols-2 lg:grid-cols-3">
      <button
        v-for="funnel in funnels"
        :key="funnel.id"
        type="button"
        class="flex flex-col gap-3 p-4 text-left bg-n-solid-1 border border-n-weak rounded-xl hover:border-n-brand transition-colors"
        @click="openBoard(funnel)"
      >
        <div class="flex items-center justify-between gap-2">
          <h2 class="text-base font-medium text-n-slate-12 truncate">
            {{ funnel.name }}
          </h2>
          <span class="text-xs text-n-slate-11 shrink-0">
            {{ funnel.stages.length }}
            {{ $t('CRM_KANBAN.LIST.STAGES') }}
          </span>
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
