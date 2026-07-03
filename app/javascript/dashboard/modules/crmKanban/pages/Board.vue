<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAdmin } from 'dashboard/composables/useAdmin';
import CrmKanbanAPI from '../api';
import KanbanColumn from '../components/KanbanColumn.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const { isAdmin } = useAdmin();

const funnelId = computed(() => Number(route.params.funnelId));
const assigneeType = ref('me');
const status = ref('open');
const isLoading = ref(false);
const isMoving = ref(false);
const funnel = ref(null);
const stages = ref([]);

const assigneeOptions = computed(() => [
  { value: 'me', label: t('CRM_KANBAN.BOARD.FILTER.MINE') },
  { value: 'all', label: t('CRM_KANBAN.BOARD.FILTER.ALL') },
]);

const statusOptions = computed(() => [
  { value: 'open', label: t('CRM_KANBAN.BOARD.STATUS.OPEN') },
  { value: 'pending', label: t('CRM_KANBAN.BOARD.STATUS.PENDING') },
  { value: 'all', label: t('CRM_KANBAN.BOARD.STATUS.ALL') },
]);

const isInactive = ref(false);

const fetchBoard = async () => {
  isLoading.value = true;
  isInactive.value = false;
  try {
    const { data } = await CrmKanbanAPI.getBoard(funnelId.value, {
      assignee_type: isAdmin.value ? assigneeType.value : 'me',
      status: status.value,
    });
    funnel.value = data.payload.funnel;
    stages.value = data.payload.stages;
  } catch (error) {
    if (error?.response?.status === 403) {
      isInactive.value = true;
    } else {
      useAlert(t('CRM_KANBAN.ERRORS.FETCH_BOARD'));
    }
  } finally {
    isLoading.value = false;
  }
};

const onCardChange = async ({ event, stage }) => {
  if (!event.added) return;

  const conversation = event.added.element;
  isMoving.value = true;

  try {
    await CrmKanbanAPI.move(funnelId.value, {
      conversation_id: conversation.id,
      stage_id: stage.id,
    });
  } catch (error) {
    const message = error?.response?.data?.error || t('CRM_KANBAN.ERRORS.MOVE');
    useAlert(message);
    await fetchBoard();
  } finally {
    isMoving.value = false;
  }
};

const openConversation = conversation => {
  router.push(
    accountScopedRoute('inbox_conversation', {
      conversation_id: conversation.id,
    })
  );
};

const goBack = () => {
  router.push(accountScopedRoute('crm_kanban_index'));
};

watch([assigneeType, status], fetchBoard);

onMounted(fetchBoard);
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden bg-n-background">
    <header
      class="flex flex-wrap items-center justify-between gap-3 px-6 py-4 border-b border-n-weak"
    >
      <div class="flex items-center gap-3 min-w-0">
        <Button
          icon="i-lucide-arrow-left"
          slate
          xs
          faded
          :title="$t('CRM_KANBAN.ACTIONS.BACK')"
          @click="goBack"
        />
        <div class="min-w-0">
          <h1 class="text-lg font-medium text-n-slate-12 truncate">
            {{ funnel?.name || $t('CRM_KANBAN.BOARD.TITLE') }}
          </h1>
          <p class="text-sm text-n-slate-11">
            {{
              isAdmin
                ? $t('CRM_KANBAN.BOARD.DESCRIPTION')
                : $t('CRM_KANBAN.BOARD.DESCRIPTION_AGENT')
            }}
          </p>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <Select
          v-if="isAdmin"
          v-model="assigneeType"
          :options="assigneeOptions"
          size="sm"
        />
        <Select v-model="status" :options="statusOptions" size="sm" />
        <Button
          icon="i-lucide-refresh-cw"
          slate
          xs
          faded
          :title="$t('CRM_KANBAN.ACTIONS.REFRESH')"
          @click="fetchBoard"
        />
      </div>
    </header>

    <div v-if="isLoading" class="flex flex-1 items-center justify-center">
      <Spinner />
    </div>

    <div
      v-else-if="isInactive"
      class="flex flex-1 items-center justify-center text-n-slate-11"
    >
      {{ $t('CRM_KANBAN.BOARD.INACTIVE') }}
    </div>

    <div
      v-else-if="stages.length === 0"
      class="flex flex-1 items-center justify-center text-n-slate-11"
    >
      {{ $t('CRM_KANBAN.BOARD.EMPTY_STAGES') }}
    </div>

    <div v-else class="flex flex-1 gap-4 p-6 overflow-x-auto overflow-y-hidden">
      <KanbanColumn
        v-for="stage in stages"
        :key="stage.id"
        :stage="stage"
        :is-moving="isMoving"
        @card-change="onCardChange"
        @open-conversation="openConversation"
      />
    </div>
  </div>
</template>
