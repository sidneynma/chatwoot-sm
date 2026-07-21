<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';
import DisparadorAPI from '../api';
import {
  extractBodyText,
  extractHeaderComponent,
  extractVariableKeys,
  isAutoAgentVar,
  isAutoContactVar,
} from '../templateHelpers';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

const props = defineProps({
  show: { type: Boolean, default: false },
  conversation: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['close']);

const { t, te } = useI18n();
const store = useStore();

const isLoading = ref(false);
const isSaving = ref(false);
const isUploading = ref(false);
const existing = ref([]);
const scheduledDate = ref('');
const messageText = ref('');
const messageTextareaRef = ref(null);
const selectedTemplateKey = ref('');
const templateParams = ref([]);
const templateVariableKeys = ref([]);
const headerMediaUrl = ref('');
const mediaUploadStatus = ref('');
const evolutionMediaUrl = ref('');
const evolutionMediaType = ref('image');
const evolutionMediaFilename = ref('');

const getFilteredWhatsAppTemplates = useMapGetter(
  'inboxes/getFilteredWhatsAppTemplates'
);
const getInboxById = useMapGetter('inboxes/getInboxById');
const currentUser = useMapGetter('getCurrentUser');

const inbox = computed(() => {
  const id = props.conversation?.inbox_id;
  if (!id) return null;
  const getter = getInboxById.value;
  return typeof getter === 'function' ? getter(id) : null;
});
const inboxId = computed(() => props.conversation?.inbox_id || inbox.value?.id);
const contact = computed(() => props.conversation?.meta?.sender || {});
const phone = computed(
  () => contact.value?.phone_number || contact.value?.phoneNumber || ''
);
const contactName = computed(
  () => contact.value?.name || contact.value?.available_name || ''
);

const channelType = computed(
  () => inbox.value?.channel_type || inbox.value?.channelType || ''
);

const isEvolution = computed(() => channelType.value === INBOX_TYPES.API);

const approvedTemplates = computed(() => {
  if (isEvolution.value || !inboxId.value) return [];
  const getter = getFilteredWhatsAppTemplates.value;
  if (typeof getter !== 'function') return [];
  return getter(inboxId.value) || [];
});

const templateOptions = computed(() =>
  approvedTemplates.value.map(tpl => ({
    value: `${tpl.name}::${tpl.language}`,
    label: `${tpl.name} (${tpl.language})`,
  }))
);

const selectedTemplate = computed(() => {
  if (!selectedTemplateKey.value) return null;
  const [name, language] = selectedTemplateKey.value.split('::');
  return (
    approvedTemplates.value.find(
      tpl => tpl.name === name && tpl.language === language
    ) || null
  );
});

const templateBody = computed(() =>
  selectedTemplate.value ? extractBodyText(selectedTemplate.value) : ''
);

const templateCategoryLabel = category => {
  if (!category) return '';
  const key = String(category).toUpperCase();
  const path = `DISPARADOR.TEMPLATE_CATEGORY.${key}`;
  return te(path) ? t(path) : String(category);
};

const scheduleVarFieldMeta = key => {
  if (isAutoContactVar(key)) {
    return {
      label: `{{${key}}} — ${t('DISPARADOR.CAMPAIGNS.VAR_AUTO_CONTACT')}`,
      placeholder: t('DISPARADOR.CAMPAIGNS.VAR_AUTO_PLACEHOLDER'),
    };
  }
  if (isAutoAgentVar(key)) {
    return {
      label: `{{${key}}} — ${t('DISPARADOR.CAMPAIGNS.VAR_AUTO_AGENT')}`,
      placeholder: t('DISPARADOR.CAMPAIGNS.VAR_AUTO_PLACEHOLDER'),
    };
  }
  return {
    label: `{{${key}}} — ${t('DISPARADOR.CAMPAIGNS.VAR_DEFAULT')}`,
    placeholder: '',
  };
};

const needsHeaderMedia = computed(() => {
  const header = selectedTemplate.value
    ? extractHeaderComponent(selectedTemplate.value)
    : null;
  const format = (header?.format || '').toUpperCase();
  return ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(format);
});

const defaultDatetimeLocal = () => {
  const d = new Date(Date.now() + 60 * 60 * 1000);
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

const formatDateTime = value => {
  if (!value) return '—';
  return new Date(value).toLocaleString('pt-BR');
};

const statusLabel = status => {
  const st = status === 'queued' ? 'pending' : status;
  return t(`DISPARADOR.SCHEDULES.STATUS.${st}`, st);
};

const loadExisting = async () => {
  if (!props.conversation?.id) return;
  isLoading.value = true;
  try {
    const { data } = await DisparadorAPI.getSchedules({
      conversation_id: props.conversation.id,
      limit: 50,
    });
    existing.value = data.payload || [];
  } catch {
    existing.value = [];
  } finally {
    isLoading.value = false;
  }
};

const resetForm = () => {
  scheduledDate.value = defaultDatetimeLocal();
  messageText.value = '';
  selectedTemplateKey.value = '';
  templateParams.value = [];
  templateVariableKeys.value = [];
  headerMediaUrl.value = '';
  mediaUploadStatus.value = '';
  evolutionMediaUrl.value = '';
  evolutionMediaType.value = 'image';
  evolutionMediaFilename.value = '';
};

const contactFirstName = () => (contactName.value || '').split(/\s+/)[0] || '';

const agentDisplayName = () => currentUser.value?.name || '';

const insertMessageVar = token => {
  const insert = `{{${token}}}`;
  const el = messageTextareaRef.value;
  if (!el) {
    messageText.value = `${messageText.value || ''}${insert}`;
    return;
  }
  const start = el.selectionStart ?? messageText.value.length;
  const end = el.selectionEnd ?? start;
  const value = messageText.value || '';
  messageText.value = value.slice(0, start) + insert + value.slice(end);
  requestAnimationFrame(() => {
    const pos = start + insert.length;
    el.focus();
    el.setSelectionRange(pos, pos);
  });
};

const applyTemplateVar = token => {
  const keys = templateVariableKeys.value;
  if (!keys.length) return;
  const value = token === 'agent' ? agentDisplayName() : contactFirstName();
  if (!value) return;
  templateParams.value = keys.map((key, idx) => {
    const match =
      token === 'agent' ? isAutoAgentVar(key) : isAutoContactVar(key);
    if (match) return value;
    // Fallback: first slot gets contact name when template only has numbered vars
    if (
      token === 'nome' &&
      idx === 0 &&
      !keys.some(k => isAutoContactVar(k) || isAutoAgentVar(k))
    ) {
      return value;
    }
    return templateParams.value[idx] || '';
  });
};

const varTokenNome = '{{nome}}';
const varTokenAgent = '{{agent}}';

watch(
  () => props.show,
  async visible => {
    if (!visible) return;
    resetForm();
    try {
      await store.dispatch('inboxes/get');
    } catch {
      // optional
    }
    await loadExisting();
  }
);

watch(selectedTemplate, template => {
  if (!template) {
    templateParams.value = [];
    templateVariableKeys.value = [];
    return;
  }
  let keys = extractVariableKeys(template);
  if (!keys.length) {
    keys = [
      ...new Set(
        (extractBodyText(template).match(/\{\{\s*\d+\s*\}\}/g) || [])
          .map(m => m.replace(/\D/g, ''))
          .filter(Boolean)
      ),
    ];
  }
  templateVariableKeys.value = keys;
  templateParams.value = keys.map(key => {
    if (isAutoContactVar(key) && contactName.value) {
      return contactFirstName();
    }
    if (isAutoAgentVar(key) && agentDisplayName()) {
      return agentDisplayName();
    }
    return '';
  });
  if (
    contactName.value &&
    templateParams.value.length &&
    !keys.some(k => isAutoContactVar(k))
  ) {
    templateParams.value[0] = contactFirstName();
  }
});

const uploadMedia = async (event, target) => {
  const file = event.target?.files?.[0];
  if (!file) return;
  isUploading.value = true;
  mediaUploadStatus.value = t('DISPARADOR.CAMPAIGNS.MEDIA_UPLOADING');
  try {
    const { data } = await DisparadorAPI.uploadMedia(file);
    if (target === 'evolution') {
      evolutionMediaUrl.value = data.media_url || data.url;
      evolutionMediaType.value = data.media_type || 'image';
      evolutionMediaFilename.value =
        data.filename || data.original_filename || file.name;
    } else {
      headerMediaUrl.value = data.media_url || data.url;
    }
    mediaUploadStatus.value = t('DISPARADOR.CAMPAIGNS.MEDIA_UPLOAD_OK');
  } catch (error) {
    mediaUploadStatus.value =
      error?.response?.data?.error ||
      t('DISPARADOR.CAMPAIGNS.MEDIA_UPLOAD_ERROR');
    useAlert(mediaUploadStatus.value);
  } finally {
    isUploading.value = false;
    if (event.target) event.target.value = '';
  }
};

const createSchedule = async () => {
  if (!phone.value) {
    useAlert(t('DISPARADOR.SCHEDULES.PHONE_REQUIRED'));
    return;
  }
  if (!scheduledDate.value) {
    useAlert(t('DISPARADOR.SCHEDULES.DATE_REQUIRED'));
    return;
  }

  const payload = {
    conversation_id: props.conversation.id,
    inbox_id: inboxId.value,
    inbox_name: inbox.value?.name,
    contact_id: contact.value?.id,
    phone: phone.value,
    name: contactName.value,
    scheduled_at: new Date(scheduledDate.value).toISOString(),
    channel: isEvolution.value ? 'evolution' : 'whatsapp',
  };

  if (isEvolution.value) {
    payload.message_type = 'text';
    payload.message = messageText.value;
    if (evolutionMediaUrl.value) {
      payload.media = {
        media_url: evolutionMediaUrl.value,
        media_type: evolutionMediaType.value,
        filename: evolutionMediaFilename.value,
      };
    }
    if (!payload.message?.trim() && !payload.media) {
      useAlert(t('DISPARADOR.CAMPAIGNS.MESSAGE_REQUIRED'));
      return;
    }
  } else {
    if (!selectedTemplate.value) {
      useAlert(t('DISPARADOR.CAMPAIGNS.TEMPLATE_REQUIRED'));
      return;
    }
    if (needsHeaderMedia.value && !headerMediaUrl.value) {
      useAlert(t('DISPARADOR.CAMPAIGNS.MEDIA_REQUIRED'));
      return;
    }
    payload.message_type = 'template';
    payload.template = selectedTemplate.value;
    payload.template_param_values = templateParams.value;
    payload.template_header_url = headerMediaUrl.value || undefined;
    payload.message = templateBody.value;
  }

  isSaving.value = true;
  try {
    await DisparadorAPI.createSchedule(payload);
    useAlert(t('DISPARADOR.SCHEDULES.CREATE_OK'));
    resetForm();
    await loadExisting();
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('DISPARADOR.SCHEDULES.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const cancelItem = async item => {
  if (!window.confirm(t('DISPARADOR.SCHEDULES.CANCEL_CONFIRM'))) return;
  try {
    await DisparadorAPI.cancelSchedule(item.id);
    useAlert(t('DISPARADOR.SCHEDULES.CANCEL_OK'));
    await loadExisting();
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('DISPARADOR.SCHEDULES.SAVE_ERROR')
    );
  }
};

onMounted(() => {
  if (props.show) {
    resetForm();
    loadExisting();
  }
});
</script>

<template>
  <TeleportWithDirection to="body">
    <div
      v-if="show"
      class="fixed inset-0 z-[100000] flex items-center justify-center bg-n-alpha-black2 p-4"
      @click.self="emit('close')"
    >
      <div
        class="max-h-[90vh] w-full max-w-lg overflow-auto rounded-xl border border-n-weak bg-n-solid-1 p-5 text-n-slate-12 shadow-lg"
        role="dialog"
        aria-modal="true"
        @click.stop
      >
        <div class="flex items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold">
              {{ t('DISPARADOR.SCHEDULES.MODAL_TITLE') }}
            </h2>
            <p class="mt-1 text-sm text-n-slate-11">
              <strong>{{
                contactName || t('DISPARADOR.SCHEDULES.NO_NAME')
              }}</strong>
              <span v-if="phone"> · {{ phone }}</span>
              <br v-if="inbox?.name" />
              <span v-if="inbox?.name">
                {{ t('DISPARADOR.DETAIL.META_INBOX') }}: {{ inbox.name }}
              </span>
            </p>
          </div>
          <Button
            :label="t('DISPARADOR.SCHEDULES.CLOSE')"
            variant="ghost"
            size="sm"
            @click="emit('close')"
          />
        </div>

        <div class="mt-4 space-y-3">
          <p class="text-sm font-medium">
            {{ t('DISPARADOR.SCHEDULES.NEW_TITLE') }}
            <span
              class="ml-2 rounded-full bg-n-brand/10 px-2 py-0.5 text-xs text-n-brand"
            >
              {{
                isEvolution
                  ? t('DISPARADOR.DETAIL.CHANNEL_EVOLUTION')
                  : t('DISPARADOR.DETAIL.CHANNEL_WHATSAPP')
              }}
            </span>
          </p>

          <template v-if="isEvolution">
            <div class="flex flex-col gap-1 text-sm">
              <div class="flex flex-wrap items-center justify-between gap-2">
                <span>{{ t('DISPARADOR.SCHEDULES.FIELD_MESSAGE') }}</span>
                <div class="flex flex-wrap gap-1">
                  <button
                    type="button"
                    class="rounded-md border border-n-weak bg-n-solid-2 px-2 py-1 text-xs font-medium text-n-brand hover:border-n-brand"
                    @click="insertMessageVar('nome')"
                  >
                    {{ varTokenNome }}
                  </button>
                  <button
                    type="button"
                    class="rounded-md border border-n-weak bg-n-solid-2 px-2 py-1 text-xs font-medium text-n-brand hover:border-n-brand"
                    @click="insertMessageVar('agent')"
                  >
                    {{ varTokenAgent }}
                  </button>
                </div>
              </div>
              <textarea
                ref="messageTextareaRef"
                v-model="messageText"
                rows="3"
                class="rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm outline-none focus:border-n-brand"
                :placeholder="
                  t('DISPARADOR.CAMPAIGNS.FIELD_MESSAGE_PLACEHOLDER')
                "
              />
              <span class="text-xs text-n-slate-11">
                {{ t('DISPARADOR.SCHEDULES.INSERT_VAR_HINT') }}
              </span>
            </div>
            <div class="flex flex-col gap-2 text-sm">
              <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_EVOLUTION_MEDIA') }}</span>
              <div class="flex flex-wrap gap-2">
                <label
                  class="inline-flex h-9 cursor-pointer items-center rounded-lg border border-n-weak bg-n-solid-2 px-3 text-xs font-medium"
                >
                  {{ t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_UPLOAD') }}
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,video/mp4,video/3gpp,application/pdf"
                    class="hidden"
                    :disabled="isUploading"
                    @change="uploadMedia($event, 'evolution')"
                  />
                </label>
                <input
                  v-model="evolutionMediaUrl"
                  type="url"
                  class="h-9 min-w-0 flex-1 rounded-lg border border-n-weak bg-n-solid-2 px-3 outline-none focus:border-n-brand"
                  :placeholder="t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_URL')"
                />
              </div>
              <span v-if="mediaUploadStatus" class="text-xs text-n-slate-11">
                {{ mediaUploadStatus }}
              </span>
            </div>
          </template>

          <template v-else>
            <label class="flex flex-col gap-1 text-sm">
              <span>{{ t('DISPARADOR.SCHEDULES.FIELD_TEMPLATE') }}</span>
              <select
                v-model="selectedTemplateKey"
                class="h-9 rounded-lg border border-n-weak bg-n-solid-2 px-3 text-sm outline-none focus:border-n-brand"
              >
                <option value="">
                  {{ t('DISPARADOR.CAMPAIGNS.FIELD_TEMPLATE_PLACEHOLDER') }}
                </option>
                <option
                  v-for="opt in templateOptions"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ opt.label }}
                </option>
              </select>
            </label>

            <div
              v-if="selectedTemplate"
              class="space-y-2 rounded-lg border border-n-weak bg-n-background p-3"
            >
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-sm font-semibold">
                  {{ selectedTemplate.name }}
                </span>
                <span
                  class="rounded-full bg-n-teal-3 px-2 py-0.5 text-[11px] font-medium text-n-teal-11"
                >
                  {{ selectedTemplate.status || 'APPROVED' }}
                </span>
                <span
                  v-if="selectedTemplate.category"
                  class="rounded-full bg-n-brand/10 px-2 py-0.5 text-[11px] font-medium text-n-brand"
                >
                  {{ templateCategoryLabel(selectedTemplate.category) }}
                </span>
                <span
                  class="rounded-full bg-n-slate-3 px-2 py-0.5 text-[11px] font-medium text-n-slate-11"
                >
                  {{ selectedTemplate.language }}
                </span>
              </div>
              <p
                v-if="templateBody"
                class="whitespace-pre-wrap text-sm text-n-slate-12"
              >
                {{ templateBody }}
              </p>
            </div>

            <div v-if="templateVariableKeys.length" class="flex flex-col gap-2">
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-sm font-medium">
                  {{ t('DISPARADOR.CAMPAIGNS.VARS_TITLE') }}
                </span>
                <button
                  type="button"
                  class="rounded-md border border-n-weak bg-n-solid-2 px-2 py-1 text-xs font-medium text-n-brand hover:border-n-brand"
                  @click="applyTemplateVar('nome')"
                >
                  {{ varTokenNome }}
                </button>
                <button
                  type="button"
                  class="rounded-md border border-n-weak bg-n-solid-2 px-2 py-1 text-xs font-medium text-n-brand hover:border-n-brand"
                  @click="applyTemplateVar('agent')"
                >
                  {{ varTokenAgent }}
                </button>
              </div>
              <span class="text-xs text-n-slate-11">
                {{ t('DISPARADOR.SCHEDULES.APPLY_VAR_HINT') }}
              </span>
              <label
                v-for="(key, idx) in templateVariableKeys"
                :key="`${key}-${idx}`"
                class="flex flex-col gap-1 text-sm"
              >
                <span>{{ scheduleVarFieldMeta(key).label }}</span>
                <input
                  v-model="templateParams[idx]"
                  type="text"
                  class="h-9 rounded-lg border border-n-weak bg-n-solid-2 px-3 outline-none focus:border-n-brand"
                  :placeholder="scheduleVarFieldMeta(key).placeholder"
                />
              </label>
            </div>

            <div v-if="needsHeaderMedia" class="flex flex-col gap-2 text-sm">
              <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_URL') }}</span>
              <div class="flex flex-wrap gap-2">
                <label
                  class="inline-flex h-9 cursor-pointer items-center rounded-lg border border-n-weak bg-n-solid-2 px-3 text-xs font-medium"
                >
                  {{ t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_UPLOAD') }}
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,video/mp4,video/3gpp,application/pdf"
                    class="hidden"
                    :disabled="isUploading"
                    @change="uploadMedia($event, 'whatsapp')"
                  />
                </label>
                <input
                  v-model="headerMediaUrl"
                  type="url"
                  class="h-9 min-w-0 flex-1 rounded-lg border border-n-weak bg-n-solid-2 px-3 outline-none focus:border-n-brand"
                  :placeholder="t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_URL')"
                />
              </div>
            </div>
          </template>

          <label class="flex flex-col gap-1 text-sm">
            <span>{{ t('DISPARADOR.SCHEDULES.FIELD_DATETIME') }}</span>
            <input
              v-model="scheduledDate"
              type="datetime-local"
              class="h-9 rounded-lg border border-n-weak bg-n-solid-2 px-3 outline-none focus:border-n-brand"
            />
          </label>

          <div class="flex justify-end gap-2 pt-2">
            <Button
              :label="t('DISPARADOR.SCHEDULES.CLOSE')"
              variant="ghost"
              size="sm"
              @click="emit('close')"
            />
            <Button
              :label="t('DISPARADOR.SCHEDULES.SUBMIT')"
              size="sm"
              :is-loading="isSaving"
              @click="createSchedule"
            />
          </div>
        </div>

        <div class="mt-6 border-t border-n-weak pt-4">
          <p class="text-sm font-medium">
            {{ t('DISPARADOR.SCHEDULES.EXISTING_TITLE') }}
          </p>
          <div v-if="isLoading" class="flex justify-center py-6">
            <Spinner />
          </div>
          <div
            v-else-if="!existing.length"
            class="py-4 text-sm text-n-slate-11"
          >
            {{ t('DISPARADOR.SCHEDULES.EMPTY_CONVERSATION') }}
          </div>
          <div v-else class="mt-3 space-y-2">
            <div
              v-for="item in existing"
              :key="item.id"
              class="rounded-lg border border-n-weak bg-n-solid-2 p-3"
            >
              <div class="flex items-start justify-between gap-2">
                <div class="text-sm font-medium text-n-brand">
                  {{ formatDateTime(item.scheduled_at) }}
                </div>
                <span class="text-xs text-n-slate-11">
                  {{ statusLabel(item.status) }}
                </span>
              </div>
              <p class="mt-1 text-sm text-n-slate-11">
                <template v-if="item.message_type === 'template'">
                  {{ item.template_name }}
                </template>
                <template v-else>
                  {{ item.message }}
                </template>
              </p>
              <Button
                v-if="item.status === 'pending'"
                class="mt-2"
                :label="t('DISPARADOR.SCHEDULES.CANCEL')"
                variant="ghost"
                size="sm"
                @click="cancelItem(item)"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </TeleportWithDirection>
</template>
