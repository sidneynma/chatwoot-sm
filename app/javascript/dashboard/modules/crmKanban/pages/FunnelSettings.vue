<script setup>
import { computed, onActivated, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import SettingsLayout from 'dashboard/routes/dashboard/settings/SettingsLayout.vue';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import CrmKanbanAPI from '../api';
import StageEditor from '../components/StageEditor.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');

const funnels = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const isTogglingId = ref(null);
const editingFunnel = ref(null);
const funnelToDelete = ref(null);

const form = ref({
  name: '',
  inbox_id: '',
  active: true,
  stages: [],
});

const formDialogRef = ref(null);
const deleteDialogRef = ref(null);

const tableHeaders = computed(() => [
  t('CRM_KANBAN.SETTINGS.TABLE.NAME'),
  t('CRM_KANBAN.SETTINGS.TABLE.INBOX'),
  t('CRM_KANBAN.SETTINGS.TABLE.STAGES'),
  t('CRM_KANBAN.SETTINGS.TABLE.STATUS'),
  t('CRM_KANBAN.SETTINGS.TABLE.ACTIONS'),
]);

const inboxOptions = computed(() => [
  { value: '', label: t('CRM_KANBAN.SETTINGS.ALL_INBOXES') },
  ...inboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  })),
]);

const isEditing = computed(() => Boolean(editingFunnel.value?.id));

const resetForm = () => {
  form.value = {
    name: '',
    inbox_id: '',
    active: true,
    stages: [],
  };
  editingFunnel.value = null;
};

const fetchFunnels = async () => {
  isLoading.value = true;
  try {
    const { data } = await CrmKanbanAPI.getForSettings();
    funnels.value = data.payload;
  } catch {
    useAlert(t('CRM_KANBAN.ERRORS.FETCH_FUNNELS'));
  } finally {
    isLoading.value = false;
  }
};

const openCreateDialog = () => {
  resetForm();
  formDialogRef.value?.open();
};

const openEditDialog = funnel => {
  editingFunnel.value = funnel;
  form.value = {
    name: funnel.name,
    inbox_id: funnel.inbox_id || '',
    active: funnel.active,
    stages: funnel.stages.map(stage => ({
      label_id: stage.label.id,
      position: stage.position,
      label: stage.label,
    })),
  };
  formDialogRef.value?.open();
};

const closeFormDialog = () => {
  formDialogRef.value?.close();
  resetForm();
};

const buildPayload = (overrides = {}) => ({
  crm_funnel: {
    name: form.value.name.trim(),
    inbox_id: form.value.inbox_id || null,
    active: form.value.active,
    stages: form.value.stages.map((stage, index) => ({
      label_id: stage.label_id,
      position: index,
    })),
    ...overrides,
  },
});

const saveFunnel = async () => {
  if (!form.value.name.trim()) {
    useAlert(t('CRM_KANBAN.ERRORS.NAME_REQUIRED'));
    return;
  }

  if (form.value.stages.length === 0) {
    useAlert(t('CRM_KANBAN.ERRORS.STAGES_REQUIRED'));
    return;
  }

  isSaving.value = true;
  try {
    if (isEditing.value) {
      await CrmKanbanAPI.update(editingFunnel.value.id, buildPayload());
      useAlert(t('CRM_KANBAN.SETTINGS.UPDATE_SUCCESS'));
    } else {
      await CrmKanbanAPI.create(buildPayload());
      useAlert(t('CRM_KANBAN.SETTINGS.CREATE_SUCCESS'));
    }
    closeFormDialog();
    await fetchFunnels();
  } catch (error) {
    const message =
      error?.response?.data?.error ||
      error?.response?.data?.message ||
      t('CRM_KANBAN.ERRORS.SAVE_FUNNEL');
    useAlert(message);
  } finally {
    isSaving.value = false;
  }
};

const toggleActive = async funnel => {
  isTogglingId.value = funnel.id;
  try {
    await CrmKanbanAPI.update(funnel.id, {
      crm_funnel: { active: !funnel.active },
    });
    useAlert(
      funnel.active
        ? t('CRM_KANBAN.SETTINGS.DEACTIVATE_SUCCESS')
        : t('CRM_KANBAN.SETTINGS.ACTIVATE_SUCCESS')
    );
    await fetchFunnels();
  } catch {
    useAlert(t('CRM_KANBAN.ERRORS.TOGGLE_FUNNEL'));
  } finally {
    isTogglingId.value = null;
  }
};

const openDeleteDialog = funnel => {
  funnelToDelete.value = funnel;
  deleteDialogRef.value?.open();
};

const confirmDelete = async () => {
  if (!funnelToDelete.value) return;

  try {
    await CrmKanbanAPI.delete(funnelToDelete.value.id);
    useAlert(t('CRM_KANBAN.SETTINGS.DELETE_SUCCESS'));
    deleteDialogRef.value?.close();
    funnelToDelete.value = null;
    await fetchFunnels();
  } catch {
    useAlert(t('CRM_KANBAN.ERRORS.DELETE_FUNNEL'));
  }
};

const inboxName = inboxId => {
  if (!inboxId) return t('CRM_KANBAN.SETTINGS.ALL_INBOXES');
  return inboxes.value.find(inbox => inbox.id === inboxId)?.name;
};

const initializePage = async () => {
  await Promise.all([
    store.dispatch('labels/get'),
    store.dispatch('inboxes/get'),
    fetchFunnels(),
  ]);

  if (route.query.new === '1') {
    openCreateDialog();
    router.replace({ query: {} });
  }
};

onMounted(initializePage);
onActivated(fetchFunnels);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('CRM_KANBAN.SETTINGS.LOADING')"
    :no-records-found="!isLoading && funnels.length === 0"
    :no-records-message="$t('CRM_KANBAN.SETTINGS.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('CRM_KANBAN.SETTINGS.TITLE')"
        :description="$t('CRM_KANBAN.SETTINGS.DESCRIPTION')"
      >
        <template v-if="funnels.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('CRM_KANBAN.SETTINGS.COUNT', { n: funnels.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            icon="i-lucide-plus"
            size="sm"
            :label="$t('CRM_KANBAN.ACTIONS.CREATE_FUNNEL')"
            @click="openCreateDialog"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable :headers="tableHeaders" :items="funnels">
        <template #row="{ items }">
          <BaseTableRow v-for="funnel in items" :key="funnel.id" :item="funnel">
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ funnel.name }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ inboxName(funnel.inbox_id) }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ funnel.stages.length }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <div class="flex items-center gap-2">
                  <span
                    class="inline-flex px-2 py-0.5 text-xs rounded-md"
                    :class="
                      funnel.active
                        ? 'bg-n-teal-3 text-n-teal-11'
                        : 'bg-n-slate-3 text-n-slate-11'
                    "
                  >
                    {{
                      funnel.active
                        ? $t('CRM_KANBAN.SETTINGS.ACTIVE')
                        : $t('CRM_KANBAN.SETTINGS.INACTIVE')
                    }}
                  </span>
                  <Button
                    xs
                    slate
                    faded
                    :label="
                      funnel.active
                        ? $t('CRM_KANBAN.ACTIONS.DEACTIVATE')
                        : $t('CRM_KANBAN.ACTIONS.ACTIVATE')
                    "
                    :is-loading="isTogglingId === funnel.id"
                    @click="toggleActive(funnel)"
                  />
                </div>
              </BaseTableCell>
              <BaseTableCell>
                <div class="flex gap-2 justify-end">
                  <Button
                    icon="i-lucide-pencil"
                    xs
                    slate
                    faded
                    :title="$t('CRM_KANBAN.ACTIONS.EDIT')"
                    @click="openEditDialog(funnel)"
                  />
                  <Button
                    icon="i-lucide-trash-2"
                    xs
                    ruby
                    faded
                    :title="$t('CRM_KANBAN.ACTIONS.DELETE')"
                    @click="openDeleteDialog(funnel)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <template #preBody>
      <div
        v-if="!isLoading && funnels.length === 0"
        class="flex justify-center pb-4"
      >
        <Button
          icon="i-lucide-plus"
          :label="$t('CRM_KANBAN.ACTIONS.CREATE_FUNNEL')"
          @click="openCreateDialog"
        />
      </div>
    </template>

    <Dialog
      ref="formDialogRef"
      type="edit"
      width="2xl"
      :title="
        isEditing
          ? $t('CRM_KANBAN.SETTINGS.EDIT_TITLE')
          : $t('CRM_KANBAN.SETTINGS.CREATE_TITLE')
      "
      :show-confirm-button="false"
      :show-cancel-button="false"
      @close="resetForm"
    >
      <div class="flex flex-col gap-4">
        <div>
          <label class="block mb-1 text-sm text-n-slate-11">
            {{ $t('CRM_KANBAN.SETTINGS.FORM.NAME') }}
          </label>
          <input
            v-model="form.name"
            type="text"
            class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
            :placeholder="$t('CRM_KANBAN.SETTINGS.FORM.NAME_PLACEHOLDER')"
          />
        </div>

        <div>
          <label class="block mb-1 text-sm text-n-slate-11">
            {{ $t('CRM_KANBAN.SETTINGS.FORM.INBOX') }}
          </label>
          <ComboBox
            v-model="form.inbox_id"
            :options="inboxOptions"
            :placeholder="$t('CRM_KANBAN.SETTINGS.FORM.INBOX_PLACEHOLDER')"
          />
        </div>

        <Checkbox v-model="form.active">
          {{ $t('CRM_KANBAN.SETTINGS.FORM.ACTIVE') }}
        </Checkbox>

        <StageEditor v-model="form.stages" />
      </div>

      <template #footer>
        <div class="flex justify-end gap-2">
          <Button
            slate
            faded
            :label="$t('CRM_KANBAN.ACTIONS.CANCEL')"
            @click="closeFormDialog"
          />
          <Button
            :label="$t('CRM_KANBAN.ACTIONS.SAVE')"
            :is-loading="isSaving"
            @click="saveFunnel"
          />
        </div>
      </template>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="$t('CRM_KANBAN.SETTINGS.DELETE_TITLE')"
      :description="
        $t('CRM_KANBAN.SETTINGS.DELETE_DESCRIPTION', {
          name: funnelToDelete?.name,
        })
      "
      :confirm-button-label="$t('CRM_KANBAN.ACTIONS.DELETE')"
      @confirm="confirmDelete"
      @close="funnelToDelete = null"
    />
  </SettingsLayout>
</template>
