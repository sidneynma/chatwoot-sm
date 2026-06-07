<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import WhatsappTemplatesAPI from '../api';
import InboxesAPI from 'dashboard/api/inboxes';

import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import {
  getTemplateBody,
  getTemplateButtons,
  getTemplateComponents,
  getTemplateFooter,
  getTemplateHeader,
} from '../templateDisplay';

const { t } = useI18n();
const store = useStore();

const selectedInboxId = ref(null);
const isFetching = ref(false);
const isSyncing = ref(false);
const messageTemplates = ref([]);
const messageTemplatesLastUpdated = ref(null);

const filters = ref({
  name: '',
  status: '',
  category: '',
  language: '',
});

const whatsAppInboxes = useMapGetter('inboxes/getWhatsAppInboxes');
const inboxesUiFlags = useMapGetter('inboxes/getUIFlags');

const inboxOptions = computed(() =>
  whatsAppInboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }))
);

const formattedLastSync = computed(() => {
  if (!messageTemplatesLastUpdated.value) {
    return t('WHATSAPP_TEMPLATES.ADMIN.LAST_SYNC_NEVER');
  }

  return dynamicTime(messageTemplatesLastUpdated.value);
});

const filteredTemplates = computed(() => {
  return messageTemplates.value.filter(template => {
    const nameMatch =
      !filters.value.name ||
      template.name?.toLowerCase().includes(filters.value.name.toLowerCase());
    const statusMatch =
      !filters.value.status ||
      template.status
        ?.toLowerCase()
        .includes(filters.value.status.toLowerCase());
    const categoryMatch =
      !filters.value.category ||
      template.category
        ?.toLowerCase()
        .includes(filters.value.category.toLowerCase());
    const languageMatch =
      !filters.value.language ||
      template.language
        ?.toLowerCase()
        .includes(filters.value.language.toLowerCase());

    return nameMatch && statusMatch && categoryMatch && languageMatch;
  });
});

const tableHeaders = computed(() => [
  t('WHATSAPP_TEMPLATES.ADMIN.TABLE.NAME'),
  t('WHATSAPP_TEMPLATES.ADMIN.TABLE.STATUS'),
  t('WHATSAPP_TEMPLATES.ADMIN.TABLE.CATEGORY'),
  t('WHATSAPP_TEMPLATES.ADMIN.TABLE.LANGUAGE'),
  t('WHATSAPP_TEMPLATES.ADMIN.TABLE.COMPONENTS'),
  t('WHATSAPP_TEMPLATES.ADMIN.TABLE.HEADER'),
  t('WHATSAPP_TEMPLATES.ADMIN.TABLE.BODY'),
  t('WHATSAPP_TEMPLATES.ADMIN.TABLE.FOOTER'),
  t('WHATSAPP_TEMPLATES.ADMIN.TABLE.BUTTONS'),
]);

const hasWhatsAppInboxes = computed(() => whatsAppInboxes.value.length > 0);

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

const pollForUpdatedTemplates = previousLastUpdated => {
  let attempts = 0;

  const poll = async () => {
    await fetchTemplates();
    attempts += 1;

    if (
      messageTemplatesLastUpdated.value !== previousLastUpdated ||
      attempts >= 10
    ) {
      return;
    }

    setTimeout(poll, 3000);
  };

  setTimeout(poll, 3000);
};

const syncTemplates = async () => {
  if (!selectedInboxId.value) return;

  isSyncing.value = true;
  const previousLastUpdated = messageTemplatesLastUpdated.value;

  try {
    await InboxesAPI.syncTemplates(selectedInboxId.value);
    useAlert(t('WHATSAPP_TEMPLATES.ADMIN.SYNC_SUCCESS'));
    pollForUpdatedTemplates(previousLastUpdated);
  } catch {
    useAlert(t('WHATSAPP_TEMPLATES.ADMIN.SYNC_ERROR'));
  } finally {
    isSyncing.value = false;
  }
};

watch(selectedInboxId, () => {
  messageTemplates.value = [];
  messageTemplatesLastUpdated.value = null;
  fetchTemplates();
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
    <header class="sticky top-0 z-10 px-6">
      <div class="w-full max-w-5xl mx-auto">
        <div class="flex items-center w-full h-20">
          <span class="text-heading-1 text-n-slate-12">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.TITLE') }}
          </span>
        </div>
      </div>
    </header>

    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-5xl mx-auto py-4">
        <div v-if="inboxesUiFlags.isFetching" class="flex justify-center py-10">
          <Spinner />
        </div>

        <div v-else-if="!hasWhatsAppInboxes" class="py-10 text-center">
          <p class="text-body-main text-n-slate-11">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.NO_INBOXES') }}
          </p>
        </div>

        <div v-else class="flex flex-col gap-6">
          <div
            class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between"
          >
            <div class="w-full max-w-xs">
              <label class="block mb-1 text-sm font-medium text-n-slate-12">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.INBOX_LABEL') }}
              </label>
              <ComboBox
                v-model="selectedInboxId"
                :options="inboxOptions"
                :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.INBOX_PLACEHOLDER')"
              />
            </div>

            <div class="flex flex-col gap-2 sm:items-end">
              <p class="text-sm text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.LAST_SYNC') }}:
                <span class="text-n-slate-12">{{ formattedLastSync }}</span>
              </p>
              <Button
                :label="t('WHATSAPP_TEMPLATES.ADMIN.SYNC_BUTTON')"
                icon="i-lucide-refresh-ccw"
                size="sm"
                :is-loading="isSyncing"
                :disabled="!selectedInboxId || isSyncing"
                @click="syncTemplates"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Input
              v-model="filters.name"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.FILTERS.NAME')"
              :placeholder="
                t('WHATSAPP_TEMPLATES.ADMIN.FILTERS.NAME_PLACEHOLDER')
              "
            />
            <Input
              v-model="filters.status"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.FILTERS.STATUS')"
              :placeholder="
                t('WHATSAPP_TEMPLATES.ADMIN.FILTERS.STATUS_PLACEHOLDER')
              "
            />
            <Input
              v-model="filters.category"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.FILTERS.CATEGORY')"
              :placeholder="
                t('WHATSAPP_TEMPLATES.ADMIN.FILTERS.CATEGORY_PLACEHOLDER')
              "
            />
            <Input
              v-model="filters.language"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.FILTERS.LANGUAGE')"
              :placeholder="
                t('WHATSAPP_TEMPLATES.ADMIN.FILTERS.LANGUAGE_PLACEHOLDER')
              "
            />
          </div>

          <div v-if="isFetching" class="flex justify-center py-10">
            <Spinner />
          </div>

          <div v-else class="overflow-x-auto">
            <BaseTable
              :headers="tableHeaders"
              :items="filteredTemplates"
              :no-data-message="t('WHATSAPP_TEMPLATES.ADMIN.NO_TEMPLATES')"
            >
              <template #row="{ items }">
                <BaseTableRow
                  v-for="template in items"
                  :key="`${template.name}-${template.language}`"
                  :item="template"
                >
                  <template #default>
                    <BaseTableCell>
                      <span class="text-body-main text-n-slate-12">
                        {{ template.name }}
                      </span>
                    </BaseTableCell>

                    <BaseTableCell>
                      <span class="text-body-main text-n-slate-11">
                        {{ template.status }}
                      </span>
                    </BaseTableCell>

                    <BaseTableCell>
                      <span class="text-body-main text-n-slate-11">
                        {{ template.category }}
                      </span>
                    </BaseTableCell>

                    <BaseTableCell>
                      <span class="text-body-main text-n-slate-11">
                        {{ template.language }}
                      </span>
                    </BaseTableCell>

                    <BaseTableCell>
                      <span class="text-body-main text-n-slate-11">
                        {{ getTemplateComponents(template) }}
                      </span>
                    </BaseTableCell>

                    <BaseTableCell>
                      <span class="text-body-main text-n-slate-11">
                        {{ getTemplateHeader(template) }}
                      </span>
                    </BaseTableCell>

                    <BaseTableCell>
                      <span class="text-body-main text-n-slate-11">
                        {{ getTemplateBody(template) }}
                      </span>
                    </BaseTableCell>

                    <BaseTableCell>
                      <span class="text-body-main text-n-slate-11">
                        {{ getTemplateFooter(template) }}
                      </span>
                    </BaseTableCell>

                    <BaseTableCell>
                      <span class="text-body-main text-n-slate-11">
                        {{ getTemplateButtons(template) }}
                      </span>
                    </BaseTableCell>
                  </template>
                </BaseTableRow>
              </template>
            </BaseTable>
          </div>
        </div>
      </div>
    </main>
  </section>
</template>
