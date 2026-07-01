<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import SettingsLayout from 'dashboard/routes/dashboard/settings/SettingsLayout.vue';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import ConversationRedistributionAPI from '../api';
import SimulationTable from '../components/SimulationTable.vue';

import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const store = useStore();

const STEPS = {
  FORM: 'form',
  SIMULATION: 'simulation',
  EXECUTING: 'executing',
  RESULT: 'result',
};

const REDISTRIBUTION_TYPES = ['unassigned', 'from_agent', 'all_open'];

const STRATEGIES = ['round_robin', 'load_balance'];

const STATUS_OPTIONS = ['open', 'pending', 'snoozed', 'resolved'];

const selectedInboxId = ref(null);
const redistributionType = ref('unassigned');
const sourceAgentId = ref(null);
const selectedStatuses = ref(['open', 'pending']);
const selectedAgentIds = ref([]);
const strategy = ref('round_robin');

const inboxAgents = ref([]);
const isLoadingAgents = ref(false);
const isSimulating = ref(false);
const isExecuting = ref(false);
const currentStep = ref(STEPS.FORM);
const simulationResult = ref(null);
const executionResult = ref(null);
const progressLabel = ref('');

const confirmDialog = ref(null);

const inboxes = useMapGetter('inboxes/getInboxes');

const inboxOptions = computed(() =>
  inboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }))
);

const redistributionTypeOptions = computed(() =>
  REDISTRIBUTION_TYPES.map(value => ({
    value,
    label: t(`CONVERSATION_REDISTRIBUTION.TYPE.${value.toUpperCase()}`),
  }))
);

const strategyOptions = computed(() =>
  STRATEGIES.map(value => ({
    value,
    label: t(`CONVERSATION_REDISTRIBUTION.STRATEGY.${value.toUpperCase()}`),
  }))
);

const sourceAgentOptions = computed(() =>
  inboxAgents.value.map(agent => ({
    value: agent.id,
    label: agent.name,
  }))
);

const showSourceAgent = computed(
  () => redistributionType.value === 'from_agent'
);

const canSimulate = computed(() => {
  if (!selectedInboxId.value || selectedAgentIds.value.length < 2) {
    return false;
  }
  if (!redistributionType.value || !strategy.value) {
    return false;
  }
  if (showSourceAgent.value && !sourceAgentId.value) {
    return false;
  }
  if (selectedStatuses.value.length === 0) {
    return false;
  }
  return true;
});

const confirmDescription = computed(() =>
  t('CONVERSATION_REDISTRIBUTION.CONFIRM.DESCRIPTION', {
    count: simulationResult.value?.total_conversations || 0,
  })
);

const buildPayload = () => ({
  inbox_id: selectedInboxId.value,
  redistribution_type: redistributionType.value,
  source_agent_id: showSourceAgent.value ? sourceAgentId.value : null,
  statuses: selectedStatuses.value,
  agent_ids: selectedAgentIds.value,
  strategy: strategy.value,
});

const fetchInboxAgents = async () => {
  if (!selectedInboxId.value) {
    inboxAgents.value = [];
    selectedAgentIds.value = [];
    sourceAgentId.value = null;
    return;
  }

  isLoadingAgents.value = true;
  try {
    const { data } = await ConversationRedistributionAPI.getInboxAgents(
      selectedInboxId.value
    );
    inboxAgents.value = data.payload || [];
    selectedAgentIds.value = selectedAgentIds.value.filter(agentId =>
      inboxAgents.value.some(agent => agent.id === agentId)
    );
    if (
      sourceAgentId.value &&
      !inboxAgents.value.some(agent => agent.id === sourceAgentId.value)
    ) {
      sourceAgentId.value = null;
    }
  } catch {
    useAlert(t('CONVERSATION_REDISTRIBUTION.ERRORS.FETCH_AGENTS'));
    inboxAgents.value = [];
  } finally {
    isLoadingAgents.value = false;
  }
};

const toggleStatus = status => {
  if (selectedStatuses.value.includes(status)) {
    selectedStatuses.value = selectedStatuses.value.filter(
      item => item !== status
    );
  } else {
    selectedStatuses.value = [...selectedStatuses.value, status];
  }
};

const toggleAgent = agentId => {
  if (selectedAgentIds.value.includes(agentId)) {
    selectedAgentIds.value = selectedAgentIds.value.filter(
      id => id !== agentId
    );
  } else {
    selectedAgentIds.value = [...selectedAgentIds.value, agentId];
  }
};

const resetFlow = () => {
  currentStep.value = STEPS.FORM;
  simulationResult.value = null;
  executionResult.value = null;
  progressLabel.value = '';
};

const runSimulation = async () => {
  if (!canSimulate.value || isSimulating.value) return;

  isSimulating.value = true;
  try {
    const { data } =
      await ConversationRedistributionAPI.simulate(buildPayload());
    simulationResult.value = data;
    currentStep.value = STEPS.SIMULATION;
  } catch (error) {
    const message =
      error?.response?.data?.error ||
      t('CONVERSATION_REDISTRIBUTION.ERRORS.SIMULATE');
    useAlert(message);
  } finally {
    isSimulating.value = false;
  }
};

const openConfirmDialog = () => {
  confirmDialog.value?.open();
};

const runExecution = async () => {
  if (isExecuting.value) return;

  isExecuting.value = true;
  currentStep.value = STEPS.EXECUTING;
  progressLabel.value = t('CONVERSATION_REDISTRIBUTION.PROGRESS.READING');

  try {
    progressLabel.value = t('CONVERSATION_REDISTRIBUTION.PROGRESS.CALCULATING');
    progressLabel.value = t('CONVERSATION_REDISTRIBUTION.PROGRESS.UPDATING');

    const { data } =
      await ConversationRedistributionAPI.execute(buildPayload());
    executionResult.value = data;
    currentStep.value = STEPS.RESULT;
    useAlert(t('CONVERSATION_REDISTRIBUTION.SUCCESS.TOAST'));
  } catch (error) {
    currentStep.value = STEPS.SIMULATION;
    const message =
      error?.response?.data?.error ||
      t('CONVERSATION_REDISTRIBUTION.ERRORS.EXECUTE');
    useAlert(message);
  } finally {
    isExecuting.value = false;
    progressLabel.value = '';
    confirmDialog.value?.close();
  }
};

watch(selectedInboxId, () => {
  resetFlow();
  fetchInboxAgents();
});

onMounted(() => {
  store.dispatch('inboxes/get');
});
</script>

<template>
  <SettingsLayout :no-records-found="false" class="gap-8">
    <template #header>
      <BaseSettingsHeader
        :title="t('CONVERSATION_REDISTRIBUTION.HEADER.TITLE')"
        :description="t('CONVERSATION_REDISTRIBUTION.HEADER.DESCRIPTION')"
        feature-name="conversation-redistribution"
      />
    </template>

    <template #body>
      <div
        v-if="currentStep === STEPS.EXECUTING"
        class="flex flex-col items-center gap-4 py-16"
      >
        <Spinner />
        <p class="text-sm text-n-slate-11">{{ progressLabel }}</p>
      </div>

      <div
        v-else-if="currentStep === STEPS.RESULT && executionResult"
        class="flex flex-col gap-6"
      >
        <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-6">
          <h3 class="text-lg font-semibold text-n-slate-12">
            {{ t('CONVERSATION_REDISTRIBUTION.SUCCESS.TITLE') }}
          </h3>
          <p class="mt-2 text-sm text-n-slate-11">
            {{
              t('CONVERSATION_REDISTRIBUTION.SUCCESS.DESCRIPTION', {
                count: executionResult.total_conversations,
              })
            }}
          </p>
          <ul class="mt-4 space-y-2">
            <li
              v-for="item in executionResult.summary"
              :key="item.agent_id"
              class="text-sm text-n-slate-12"
            >
              {{
                t('CONVERSATION_REDISTRIBUTION.SUCCESS.SUMMARY_LINE', {
                  name: item.name,
                  count: item.count,
                })
              }}
            </li>
          </ul>
        </div>
        <Button
          :label="t('CONVERSATION_REDISTRIBUTION.ACTIONS.NEW')"
          @click="resetFlow"
        />
      </div>

      <div v-else class="flex flex-col gap-8">
        <section class="flex flex-col gap-4">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('CONVERSATION_REDISTRIBUTION.FORM.INBOX') }}
          </h3>
          <ComboBox
            v-model="selectedInboxId"
            :options="inboxOptions"
            :placeholder="
              t('CONVERSATION_REDISTRIBUTION.FORM.INBOX_PLACEHOLDER')
            "
          />
        </section>

        <section class="flex flex-col gap-4">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('CONVERSATION_REDISTRIBUTION.FORM.TYPE') }}
          </h3>
          <Select
            v-model="redistributionType"
            :options="redistributionTypeOptions"
            class="!w-full"
          />
        </section>

        <section v-if="showSourceAgent" class="flex flex-col gap-4">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('CONVERSATION_REDISTRIBUTION.FORM.SOURCE_AGENT') }}
          </h3>
          <ComboBox
            v-model="sourceAgentId"
            :options="sourceAgentOptions"
            :placeholder="
              t('CONVERSATION_REDISTRIBUTION.FORM.SOURCE_AGENT_PLACEHOLDER')
            "
          />
        </section>

        <section class="flex flex-col gap-4">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('CONVERSATION_REDISTRIBUTION.FORM.STATUSES') }}
          </h3>
          <div class="flex flex-wrap gap-4">
            <label
              v-for="status in STATUS_OPTIONS"
              :key="status"
              class="flex items-center gap-2 text-sm text-n-slate-12"
            >
              <Checkbox
                :model-value="selectedStatuses.includes(status)"
                @change="toggleStatus(status)"
              />
              {{
                t(`CONVERSATION_REDISTRIBUTION.STATUS.${status.toUpperCase()}`)
              }}
            </label>
          </div>
        </section>

        <section class="flex flex-col gap-4">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('CONVERSATION_REDISTRIBUTION.FORM.AGENTS') }}
          </h3>
          <p class="text-sm text-n-slate-11">
            {{ t('CONVERSATION_REDISTRIBUTION.FORM.AGENTS_HINT') }}
          </p>
          <div v-if="isLoadingAgents" class="flex justify-center py-6">
            <Spinner />
          </div>
          <div
            v-else-if="inboxAgents.length === 0"
            class="text-sm text-n-slate-11"
          >
            {{ t('CONVERSATION_REDISTRIBUTION.FORM.NO_AGENTS') }}
          </div>
          <div v-else class="grid gap-3 sm:grid-cols-2">
            <label
              v-for="agent in inboxAgents"
              :key="agent.id"
              class="flex items-center gap-2 rounded-lg border border-n-weak px-4 py-3 text-sm text-n-slate-12"
            >
              <Checkbox
                :model-value="selectedAgentIds.includes(agent.id)"
                @change="toggleAgent(agent.id)"
              />
              {{ agent.name }}
            </label>
          </div>
        </section>

        <section class="flex flex-col gap-4">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('CONVERSATION_REDISTRIBUTION.FORM.STRATEGY') }}
          </h3>
          <Select
            v-model="strategy"
            :options="strategyOptions"
            class="!w-full"
          />
        </section>

        <div
          v-if="currentStep === STEPS.SIMULATION && simulationResult"
          class="flex flex-col gap-6"
        >
          <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-6">
            <h3 class="text-base font-semibold text-n-slate-12">
              {{ t('CONVERSATION_REDISTRIBUTION.SIMULATION.TITLE') }}
            </h3>
            <div class="mt-4 grid gap-4 sm:grid-cols-3">
              <div>
                <p class="text-xs text-n-slate-11">
                  {{
                    t('CONVERSATION_REDISTRIBUTION.SIMULATION.CONVERSATIONS')
                  }}
                </p>
                <p class="text-lg font-semibold text-n-slate-12">
                  {{ simulationResult.total_conversations }}
                </p>
              </div>
              <div>
                <p class="text-xs text-n-slate-11">
                  {{ t('CONVERSATION_REDISTRIBUTION.SIMULATION.AGENTS') }}
                </p>
                <p class="text-lg font-semibold text-n-slate-12">
                  {{ simulationResult.agent_count }}
                </p>
              </div>
            </div>
            <ul class="mt-4 space-y-1">
              <li
                v-for="item in simulationResult.summary"
                :key="item.agent_id"
                class="text-sm text-n-slate-12"
              >
                {{
                  t('CONVERSATION_REDISTRIBUTION.SIMULATION.SUMMARY_LINE', {
                    name: item.name,
                    count: item.count,
                  })
                }}
              </li>
            </ul>
          </div>

          <SimulationTable :assignments="simulationResult.assignments" />

          <div class="flex flex-wrap gap-3">
            <Button
              variant="outline"
              :label="t('CONVERSATION_REDISTRIBUTION.ACTIONS.BACK')"
              @click="resetFlow"
            />
            <Button
              :label="t('CONVERSATION_REDISTRIBUTION.ACTIONS.REDISTRIBUTE')"
              :disabled="simulationResult.total_conversations === 0"
              @click="openConfirmDialog"
            />
          </div>
        </div>

        <div v-else class="flex justify-end">
          <Button
            :label="t('CONVERSATION_REDISTRIBUTION.ACTIONS.SIMULATE')"
            :disabled="!canSimulate"
            :is-loading="isSimulating"
            @click="runSimulation"
          />
        </div>
      </div>

      <Dialog
        ref="confirmDialog"
        type="alert"
        :title="t('CONVERSATION_REDISTRIBUTION.CONFIRM.TITLE')"
        :description="confirmDescription"
        :confirm-button-label="
          t('CONVERSATION_REDISTRIBUTION.ACTIONS.REDISTRIBUTE')
        "
        :cancel-button-label="t('CONVERSATION_REDISTRIBUTION.ACTIONS.CANCEL')"
        :is-loading="isExecuting"
        @confirm="runExecution"
      />
    </template>
  </SettingsLayout>
</template>
