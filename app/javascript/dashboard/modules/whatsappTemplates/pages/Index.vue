<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import WhatsappTemplatesAPI from '../api';
import InboxesAPI from 'dashboard/api/inboxes';

import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TemplateCard from '../components/TemplateCard.vue';
import CreateTemplateDialog from '../components/CreateTemplateDialog.vue';

const { t } = useI18n();
const store = useStore();

const selectedInboxId = ref(null);
const isFetching = ref(false);
const isSyncing = ref(false);
const isCreating = ref(false);
const isDeleting = ref(false);
const messageTemplates = ref([]);
const messageTemplatesLastUpdated = ref(null);

const searchQuery = ref('');
const statusFilter = ref('ALL');
const templateToDelete = ref(null);

const createDialogRef = ref(null);
const deleteDialogRef = ref(null);

const whatsAppInboxes = useMapGetter('inboxes/getWhatsAppInboxes');
const inboxesUiFlags = useMapGetter('inboxes/getUIFlags');

const inboxOptions = computed(() =>
  whatsAppInboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }))
);

const statusOptions = computed(() => [
  { value: 'ALL', label: t('WHATSAPP_TEMPLATES.ADMIN.STATUS_FILTER.ALL') },
  {
    value: 'APPROVED',
    label: t('WHATSAPP_TEMPLATES.ADMIN.STATUS_FILTER.APPROVED'),
  },
  {
    value: 'PENDING',
    label: t('WHATSAPP_TEMPLATES.ADMIN.STATUS_FILTER.PENDING'),
  },
  {
    value: 'REJECTED',
    label: t('WHATSAPP_TEMPLATES.ADMIN.STATUS_FILTER.REJECTED'),
  },
]);

const hasWhatsAppInboxes = computed(() => whatsAppInboxes.value.length > 0);

const formattedLastSync = computed(() => {
  if (!messageTemplatesLastUpdated.value) {
    return t('WHATSAPP_TEMPLATES.ADMIN.LAST_SYNC_NEVER');
  }
  return dynamicTime(messageTemplatesLastUpdated.value);
});

const countByStatus = status =>
  messageTemplates.value.filter(
    template => (template.status || '').toUpperCase() === status
  ).length;

const stats = computed(() => ({
  total: messageTemplates.value.length,
  approved: countByStatus('APPROVED'),
  pending: countByStatus('PENDING'),
  rejected: countByStatus('REJECTED'),
}));

const filteredTemplates = computed(() =>
  messageTemplates.value.filter(template => {
    const nameMatch =
      !searchQuery.value ||
      template.name?.toLowerCase().includes(searchQuery.value.toLowerCase());
    const statusMatch =
      statusFilter.value === 'ALL' ||
      (template.status || '').toUpperCase() === statusFilter.value;
    return nameMatch && statusMatch;
  })
);

const noDataMessage = computed(() => {
  if (messageTemplatesLastUpdated.value === null) {
    return t('WHATSAPP_TEMPLATES.ADMIN.SYNC_TO_LOAD');
  }
  return t('WHATSAPP_TEMPLATES.ADMIN.NO_TEMPLATES');
});

const fetchTemplates = async () => {
  if (!selectedInboxId.value) return;

  isFetching.value = true;
  try {
    const { data } = await WhatsappTemplatesAPI.get(selectedInboxId.value);
    messageTemplates.value = data.message_templates || [];
    messageTemplatesLastUpdated.value = data.message_templates_last_updated;
  } catch {
    useAlert(t('WHATSAPP_TEMPLATES.ADMIN.FETCH_ERROR'));
  } finally {
    isFetching.value = false;
  }
};

const syncTemplates = async () => {
  if (!selectedInboxId.value || isSyncing.value) return;

  isSyncing.value = true;
  try {
    await InboxesAPI.syncTemplates(selectedInboxId.value);
    await fetchTemplates();
    useAlert(t('WHATSAPP_TEMPLATES.ADMIN.SYNC_SUCCESS'));
  } catch {
    useAlert(t('WHATSAPP_TEMPLATES.ADMIN.SYNC_ERROR'));
  } finally {
    isSyncing.value = false;
  }
};

const openCreateDialog = () => {
  nextTick(() => createDialogRef.value?.open());
};

const handleCreate = async payload => {
  if (!selectedInboxId.value) return;

  isCreating.value = true;
  try {
    const { data } = await WhatsappTemplatesAPI.create(
      selectedInboxId.value,
      payload
    );
    messageTemplates.value = data.message_templates || messageTemplates.value;
    messageTemplatesLastUpdated.value = new Date().toISOString();
    useAlert(t('WHATSAPP_TEMPLATES.ADMIN.CREATE.SUCCESS'));
    createDialogRef.value?.close();
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('WHATSAPP_TEMPLATES.ADMIN.CREATE.ERROR')
    );
  } finally {
    isCreating.value = false;
  }
};

const requestDelete = template => {
  templateToDelete.value = template;
  nextTick(() => deleteDialogRef.value?.open());
};

const confirmDelete = async () => {
  if (!templateToDelete.value || !selectedInboxId.value) return;

  isDeleting.value = true;
  try {
    const { data } = await WhatsappTemplatesAPI.delete(
      selectedInboxId.value,
      templateToDelete.value.name
    );
    messageTemplates.value = data.message_templates || messageTemplates.value;
    useAlert(t('WHATSAPP_TEMPLATES.ADMIN.DELETE.SUCCESS'));
    deleteDialogRef.value?.close();
    templateToDelete.value = null;
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('WHATSAPP_TEMPLATES.ADMIN.DELETE.ERROR')
    );
  } finally {
    isDeleting.value = false;
  }
};

watch(selectedInboxId, () => {
  messageTemplates.value = [];
  messageTemplatesLastUpdated.value = null;
  searchQuery.value = '';
  statusFilter.value = 'ALL';
});

onMounted(async () => {
  if (!store.getters['inboxes/getInboxes'].length) {
    await store.dispatch('inboxes/get');
  }

  if (whatsAppInboxes.value.length) {
    selectedInboxId.value = whatsAppInboxes.value[0].id;
  }
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="flex flex-col w-full max-w-5xl gap-6 py-6 mx-auto">
        <div v-if="inboxesUiFlags.isFetching" class="flex justify-center py-10">
          <Spinner />
        </div>

        <div v-else-if="!hasWhatsAppInboxes" class="py-10 text-center">
          <p class="text-body-main text-n-slate-11">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.NO_INBOXES') }}
          </p>
        </div>

        <template v-else>
          <header
            class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between"
          >
            <div class="flex flex-col gap-1">
              <h1 class="text-xl font-semibold text-n-slate-12">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.TITLE') }}
              </h1>
              <p class="text-sm text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.SUBTITLE') }}
              </p>
            </div>
            <Button
              :label="t('WHATSAPP_TEMPLATES.ADMIN.NEW_TEMPLATE')"
              icon="i-lucide-plus"
              size="sm"
              :disabled="!selectedInboxId"
              @click="openCreateDialog"
            />
          </header>

          <div class="flex flex-col gap-3 sm:flex-row sm:items-end">
            <div class="w-full sm:max-w-xs">
              <label class="block mb-1 text-sm font-medium text-n-slate-12">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.INBOX_LABEL') }}
              </label>
              <ComboBox
                v-model="selectedInboxId"
                :options="inboxOptions"
                :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.INBOX_PLACEHOLDER')"
              />
            </div>
            <p class="text-sm text-n-slate-11 sm:ml-auto">
              {{ t('WHATSAPP_TEMPLATES.ADMIN.LAST_SYNC') }}:
              <span class="text-n-slate-12">{{ formattedLastSync }}</span>
            </p>
          </div>

          <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <div class="p-4 rounded-xl border border-n-weak">
              <p class="text-xs uppercase text-n-slate-10">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.STATS.TOTAL') }}
              </p>
              <p class="text-2xl font-semibold text-n-slate-12">
                {{ stats.total }}
              </p>
            </div>
            <div class="p-4 rounded-xl border border-n-weak">
              <p class="text-xs uppercase text-n-slate-10">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.STATS.APPROVED') }}
              </p>
              <p class="text-2xl font-semibold text-n-teal-11">
                {{ stats.approved }}
              </p>
            </div>
            <div class="p-4 rounded-xl border border-n-weak">
              <p class="text-xs uppercase text-n-slate-10">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.STATS.PENDING') }}
              </p>
              <p class="text-2xl font-semibold text-n-amber-11">
                {{ stats.pending }}
              </p>
            </div>
            <div class="p-4 rounded-xl border border-n-weak">
              <p class="text-xs uppercase text-n-slate-10">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.STATS.REJECTED') }}
              </p>
              <p class="text-2xl font-semibold text-n-ruby-11">
                {{ stats.rejected }}
              </p>
            </div>
          </div>

          <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
            <div
              class="flex flex-1 items-center gap-2 px-3 py-2 rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak focus-within:outline-n-brand"
            >
              <fluent-icon icon="search" class="text-n-slate-11" size="16" />
              <input
                v-model="searchQuery"
                type="text"
                class="w-full text-sm bg-transparent border-0 reset-base focus:outline-none text-n-slate-12"
                :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.SEARCH_PLACEHOLDER')"
              />
            </div>
            <Select
              v-model="statusFilter"
              :options="statusOptions"
              class="!w-full sm:!w-auto"
            />
            <Button
              :label="t('WHATSAPP_TEMPLATES.ADMIN.SYNC_BUTTON')"
              icon="i-lucide-refresh-ccw"
              variant="outline"
              size="sm"
              :is-loading="isSyncing"
              :disabled="!selectedInboxId || isSyncing"
              @click="syncTemplates"
            />
          </div>

          <div v-if="isFetching || isSyncing" class="flex justify-center py-10">
            <Spinner />
          </div>

          <div
            v-else-if="!filteredTemplates.length"
            class="py-10 text-center text-sm text-n-slate-11"
          >
            {{ noDataMessage }}
          </div>

          <div v-else class="flex flex-col gap-3">
            <TemplateCard
              v-for="template in filteredTemplates"
              :key="`${template.name}-${template.language}`"
              :template="template"
              can-manage
              @delete="requestDelete"
            />
          </div>
        </template>
      </div>
    </main>

    <CreateTemplateDialog
      ref="createDialogRef"
      :is-creating="isCreating"
      @submit="handleCreate"
    />

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('WHATSAPP_TEMPLATES.ADMIN.DELETE.TITLE')"
      :description="
        t('WHATSAPP_TEMPLATES.ADMIN.DELETE.MESSAGE', {
          name: templateToDelete?.name,
        })
      "
      :confirm-button-label="t('WHATSAPP_TEMPLATES.ADMIN.DELETE.CONFIRM')"
      :cancel-button-label="t('WHATSAPP_TEMPLATES.ADMIN.DELETE.CANCEL')"
      :is-loading="isDeleting"
      :disable-confirm-button="isDeleting"
      @confirm="confirmDelete"
    />
  </section>
</template>
