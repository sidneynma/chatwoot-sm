<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';
import DisparadorAPI from '../api';
import {
  buildTemplateMetadata,
  buildEvolutionMetadata,
  extractBodyText,
  extractHeaderComponent,
  extractFooterText,
  extractVariableKeys,
  extractEvolutionVariableKeys,
  parseRecipientsText,
  renderPreviewText,
  buildCsvModel,
  csvToRecipientLines,
  appendRecipientLines,
  formatPhoneForLine,
  normalizePhoneDigits,
  csvVarKeysForExport,
  isAutoContactVar,
  isAutoAgentVar,
} from '../templateHelpers';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import ContactAPI from 'dashboard/api/contacts';
import ConversationAPI from 'dashboard/api/inbox/conversation';

const { t, te } = useI18n();
const router = useRouter();
const store = useStore();
const { accountScopedRoute } = useAccount();

const campaigns = ref([]);
const overview = ref({});
const pageError = ref('');
const isFetching = ref(false);
const isSaving = ref(false);
const isUploadingMedia = ref(false);
const isImportingLabel = ref(false);
const showCreate = ref(false);
const searchQuery = ref('');
const archiveFilter = ref('active');
const dateFrom = ref('');
const dateTo = ref('');
const appliedFrom = ref('');
const appliedTo = ref('');
const isExporting = ref(false);
const mediaUploadStatus = ref('');
const recipientExtras = ref({});
const importSource = ref('contacts');
const importLabel = ref('');

const form = ref({
  name: '',
  channel: 'whatsapp',
  inbox_id: '',
  template_name: '',
  dispatch_mode: 'meta_direct',
  scheduled_at: '',
  header_media_url: '',
  header_media_type: '',
  header_media_name: '',
  message_template: '',
  evolution_delay_seconds: 15,
  evolution_media_url: '',
  evolution_media_type: '',
  evolution_media_filename: '',
  recipientsText: '',
  bodyParams: {},
});

const whatsAppInboxes = useMapGetter('inboxes/getWhatsAppInboxes');
const allInboxes = useMapGetter('inboxes/getInboxes');
const getFilteredWhatsAppTemplates = useMapGetter(
  'inboxes/getFilteredWhatsAppTemplates'
);
const labels = useMapGetter('labels/getLabels');
const currentUser = useMapGetter('getCurrentUser');

const isEvolution = computed(() => form.value.channel === 'evolution');

const channelOptions = computed(() => [
  {
    value: 'whatsapp',
    label: t('DISPARADOR.CAMPAIGNS.CHANNEL_WHATSAPP'),
  },
  {
    value: 'evolution',
    label: t('DISPARADOR.CAMPAIGNS.CHANNEL_EVOLUTION'),
  },
]);

const apiInboxes = computed(() =>
  (allInboxes.value || []).filter(
    inbox =>
      inbox.channel_type === INBOX_TYPES.API ||
      inbox.channelType === INBOX_TYPES.API
  )
);

const inboxOptions = computed(() => {
  const list = isEvolution.value
    ? apiInboxes.value
    : whatsAppInboxes.value || [];
  return list.map(inbox => ({
    value: inbox.id,
    label: inbox.name || `#${inbox.id}`,
  }));
});

const labelOptions = computed(() =>
  (labels.value || [])
    .filter(label => label?.title)
    .map(label => ({
      value: label.title,
      label: String(label.title),
    }))
);

const importSourceOptions = computed(() => [
  {
    value: 'contacts',
    label: t('DISPARADOR.CAMPAIGNS.IMPORT_SOURCE_CONTACTS'),
  },
  {
    value: 'conversations',
    label: t('DISPARADOR.CAMPAIGNS.IMPORT_SOURCE_CONVERSATIONS'),
  },
]);

const archiveOptions = computed(() => [
  { value: 'active', label: t('DISPARADOR.CAMPAIGNS.FILTER_ACTIVE') },
  { value: 'archived', label: t('DISPARADOR.CAMPAIGNS.FILTER_ARCHIVED') },
  { value: 'all', label: t('DISPARADOR.CAMPAIGNS.FILTER_ALL') },
]);

const modeOptions = computed(() => [
  {
    value: 'meta_direct',
    label: t('DISPARADOR.DETAIL.MODE_META_DIRECT'),
  },
  {
    value: 'conversation',
    label: t('DISPARADOR.DETAIL.MODE_CONVERSATION'),
  },
]);

const approvedTemplates = computed(() => {
  if (!form.value.inbox_id || isEvolution.value) return [];
  const getter = getFilteredWhatsAppTemplates.value;
  if (typeof getter !== 'function') return [];
  return getter(form.value.inbox_id) || [];
});

const templateOptions = computed(() =>
  approvedTemplates.value.map(template => ({
    value: `${template.name}::${template.language}`,
    label: `${template.name} (${template.language})`,
  }))
);

const selectedTemplate = computed(() => {
  if (!form.value.template_name || isEvolution.value) return null;
  const [name, language] = String(form.value.template_name).split('::');
  return (
    approvedTemplates.value.find(
      item => item.name === name && item.language === language
    ) || null
  );
});

const variableKeys = computed(() => {
  if (isEvolution.value) {
    return extractEvolutionVariableKeys(form.value.message_template);
  }
  return selectedTemplate.value
    ? extractVariableKeys(selectedTemplate.value)
    : [];
});

const headerComponent = computed(() =>
  selectedTemplate.value ? extractHeaderComponent(selectedTemplate.value) : null
);

const needsHeaderMedia = computed(() => {
  if (isEvolution.value) return false;
  const format = (headerComponent.value?.format || '').toUpperCase();
  return ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(format);
});

const templateBodyRaw = computed(() => {
  if (isEvolution.value) return form.value.message_template || '';
  return selectedTemplate.value ? extractBodyText(selectedTemplate.value) : '';
});

const templatePreviewText = computed(() =>
  renderPreviewText(
    templateBodyRaw.value,
    form.value.bodyParams || {},
    currentUser.value?.name || ''
  )
);

const templateHeaderText = computed(() => {
  const header = headerComponent.value;
  if (!header) return '';
  if ((header.format || '').toUpperCase() === 'TEXT') return header.text || '';
  return '';
});

const templateFooterText = computed(() =>
  selectedTemplate.value ? extractFooterText(selectedTemplate.value) : ''
);

const templateHeaderFormat = computed(() =>
  (headerComponent.value?.format || '').toUpperCase()
);

const templateVariablesHint = computed(() => {
  if (!variableKeys.value.length) {
    return t('DISPARADOR.CAMPAIGNS.TEMPLATE_VARS_EMPTY');
  }
  const list = variableKeys.value.map(k => `{{${k}}}`).join(', ');
  return t('DISPARADOR.CAMPAIGNS.TEMPLATE_VARS_HINT', { list });
});

const variableFieldMeta = key => {
  if (isAutoContactVar(key)) {
    return {
      label: `{{${key}}} — ${t('DISPARADOR.CAMPAIGNS.VAR_AUTO_CONTACT')}`,
      placeholder: t('DISPARADOR.CAMPAIGNS.VAR_AUTO_PLACEHOLDER'),
      auto: true,
    };
  }
  if (isAutoAgentVar(key)) {
    return {
      label: `{{${key}}} — ${t('DISPARADOR.CAMPAIGNS.VAR_AUTO_AGENT')}`,
      placeholder: t('DISPARADOR.CAMPAIGNS.VAR_AUTO_PLACEHOLDER'),
      auto: true,
    };
  }
  return {
    label: `{{${key}}} — ${t('DISPARADOR.CAMPAIGNS.VAR_DEFAULT')}`,
    placeholder: '',
    auto: false,
  };
};

const templateCategoryLabel = category => {
  if (!category) return '';
  const key = String(category).toUpperCase();
  const path = `DISPARADOR.TEMPLATE_CATEGORY.${key}`;
  return te(path) ? t(path) : String(category);
};

const insertEvolutionVar = token => {
  const insert = `{{${token}}}`;
  const current = form.value.message_template || '';
  form.value.message_template = current ? `${current}${insert}` : insert;
};

const varTokenNome = '{{nome}}';
const varTokenAgent = '{{agent}}';

const importHint = computed(() =>
  importSource.value === 'conversations'
    ? t('DISPARADOR.CAMPAIGNS.IMPORT_HINT_CONVERSATIONS')
    : t('DISPARADOR.CAMPAIGNS.IMPORT_HINT_CONTACTS')
);

const recipientsPlaceholder = computed(() =>
  t('DISPARADOR.CAMPAIGNS.FIELD_RECIPIENTS_PLACEHOLDER')
);

const statusLabel = status =>
  t(`DISPARADOR.CAMPAIGNS.STATUS.${status}`, status);

const overviewCards = computed(() => [
  {
    key: 'total_campaigns',
    label: t('DISPARADOR.OVERVIEW.CAMPAIGNS'),
    value: overview.value.total_campaigns || 0,
    icon: 'i-lucide-bar-chart-3',
    iconClass: 'bg-n-ruby-3 text-n-ruby-11',
    accent: false,
  },
  {
    key: 'running_campaigns',
    label: t('DISPARADOR.OVERVIEW.RUNNING'),
    value: overview.value.running_campaigns || 0,
    icon: 'i-lucide-rocket',
    iconClass: 'bg-n-brand/10 text-n-brand',
    accent: false,
  },
  {
    key: 'scheduled_campaigns',
    label: t('DISPARADOR.OVERVIEW.SCHEDULED'),
    value: overview.value.scheduled_campaigns || 0,
    icon: 'i-lucide-calendar',
    iconClass: 'bg-n-slate-3 text-n-slate-11',
    accent: false,
  },
  {
    key: 'total_recipients',
    label: t('DISPARADOR.OVERVIEW.RECIPIENTS'),
    value: overview.value.total_recipients || 0,
    icon: 'i-lucide-users',
    iconClass: 'bg-n-brand/10 text-n-brand',
    accent: false,
  },
  {
    key: 'sent_count',
    label: t('DISPARADOR.OVERVIEW.SENT'),
    value: overview.value.sent_count || 0,
    icon: 'i-lucide-mail',
    iconClass: 'bg-n-slate-3 text-n-slate-11',
    accent: false,
  },
  {
    key: 'replied_count',
    label: t('DISPARADOR.OVERVIEW.REPLIED'),
    value: overview.value.replied_count || 0,
    icon: 'i-lucide-message-circle',
    iconClass: 'bg-n-teal-3 text-n-teal-11',
    accent: false,
  },
  {
    key: 'reply_rate',
    label: t('DISPARADOR.OVERVIEW.REPLY_RATE'),
    value: `${overview.value.reply_rate || 0}%`,
    icon: 'i-lucide-trending-up',
    iconClass: 'bg-white/20 text-white',
    accent: true,
  },
]);

const listQueryParams = () => ({
  archived: archiveFilter.value,
  search: searchQuery.value || undefined,
  from: appliedFrom.value || undefined,
  to: appliedTo.value || undefined,
  overview: true,
  limit: 100,
});

const loadCampaigns = async () => {
  isFetching.value = true;
  pageError.value = '';
  try {
    const { data } = await DisparadorAPI.getCampaigns(listQueryParams());
    campaigns.value = data.payload || [];
    overview.value = data.overview || {};
  } catch (error) {
    const message =
      error?.response?.data?.error || t('DISPARADOR.CAMPAIGNS.LOAD_ERROR');
    pageError.value = message;
    useAlert(message);
  } finally {
    isFetching.value = false;
  }
};

const applyFilters = () => {
  appliedFrom.value = dateFrom.value;
  appliedTo.value = dateTo.value;
  loadCampaigns();
};

const clearFilters = () => {
  dateFrom.value = '';
  dateTo.value = '';
  appliedFrom.value = '';
  appliedTo.value = '';
  searchQuery.value = '';
  archiveFilter.value = 'active';
  loadCampaigns();
};

const downloadBlob = (blob, filename) => {
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  window.URL.revokeObjectURL(url);
};

const exportExcel = async () => {
  isExporting.value = true;
  try {
    const { data } = await DisparadorAPI.exportCampaigns({
      archived: archiveFilter.value,
      search: searchQuery.value || undefined,
      from: appliedFrom.value || undefined,
      to: appliedTo.value || undefined,
    });
    downloadBlob(
      data,
      `campanhas_${new Date().toISOString().slice(0, 10)}.csv`
    );
  } catch (error) {
    useAlert(t('DISPARADOR.CAMPAIGNS.EXPORT_ERROR'));
  } finally {
    isExporting.value = false;
  }
};

const exportPdf = () => {
  const rows = campaigns.value
    .map(
      c =>
        `<tr>
          <td>${c.name || ''}</td>
          <td>${statusLabel(c.status)}</td>
          <td>${c.inbox_name || ''}</td>
          <td>${c.total_recipients || 0}</td>
          <td>${c.sent_count || 0}</td>
          <td>${c.failed_count || 0}</td>
          <td>${c.replied_count || 0}</td>
          <td>${c.reply_rate || 0}%</td>
        </tr>`
    )
    .join('');
  const html = `<!DOCTYPE html><html><head><title>Campanhas</title>
    <style>
      body{font-family:Arial,sans-serif;padding:24px;color:#111}
      h1{font-size:18px;margin:0 0 16px}
      table{width:100%;border-collapse:collapse;font-size:12px}
      th,td{border:1px solid #ddd;padding:8px;text-align:left}
      th{background:#f5f5f5}
    </style></head><body>
    <h1>${t('DISPARADOR.CAMPAIGNS.TITLE')}</h1>
    <table>
      <thead><tr>
        <th>${t('DISPARADOR.CAMPAIGNS.COL_NAME')}</th>
        <th>${t('DISPARADOR.CAMPAIGNS.COL_STATUS')}</th>
        <th>${t('DISPARADOR.CAMPAIGNS.COL_INBOX')}</th>
        <th>${t('DISPARADOR.CAMPAIGNS.COL_RECIPIENTS')}</th>
        <th>${t('DISPARADOR.CAMPAIGNS.COL_SENT')}</th>
        <th>${t('DISPARADOR.CAMPAIGNS.COL_FAILED')}</th>
        <th>${t('DISPARADOR.CAMPAIGNS.COL_REPLIED')}</th>
        <th>${t('DISPARADOR.OVERVIEW.REPLY_RATE')}</th>
      </tr></thead>
      <tbody>${rows}</tbody>
    </table>
    </body></html>`;
  const win = window.open('', '_blank');
  if (!win) {
    useAlert(t('DISPARADOR.CAMPAIGNS.EXPORT_ERROR'));
    return;
  }
  win.document.write(html);
  win.document.close();
  win.focus();
  win.print();
};

const formatDispatchAt = campaign => {
  const value =
    campaign.started_at || campaign.scheduled_at || campaign.created_at;
  if (!value) return '—';
  return new Date(value).toLocaleString();
};

const resetForm = () => {
  form.value = {
    name: '',
    channel: 'whatsapp',
    inbox_id: '',
    template_name: '',
    dispatch_mode: 'meta_direct',
    scheduled_at: '',
    header_media_url: '',
    header_media_type: '',
    header_media_name: '',
    message_template: '',
    evolution_delay_seconds: 15,
    evolution_media_url: '',
    evolution_media_type: '',
    evolution_media_filename: '',
    recipientsText: '',
    bodyParams: {},
  };
  mediaUploadStatus.value = '';
  recipientExtras.value = {};
  importSource.value = 'contacts';
  importLabel.value = '';
};

const openCreate = () => {
  resetForm();
  showCreate.value = true;
};

const closeCreate = () => {
  showCreate.value = false;
};

const openDetail = campaign => {
  router.push(
    accountScopedRoute('disparador_campaign_show', {
      campaignId: campaign.id,
    })
  );
};

watch(
  () => form.value.channel,
  () => {
    form.value.inbox_id = '';
    form.value.template_name = '';
    form.value.bodyParams = {};
    form.value.header_media_url = '';
    form.value.evolution_media_url = '';
    mediaUploadStatus.value = '';
  }
);

watch(
  () => form.value.inbox_id,
  () => {
    form.value.template_name = '';
    form.value.bodyParams = {};
  }
);

watch(selectedTemplate, template => {
  if (!template) {
    form.value.bodyParams = {};
    return;
  }
  const keys = extractVariableKeys(template);
  const next = {};
  keys.forEach(key => {
    next[key] = form.value.bodyParams[key] || '';
  });
  form.value.bodyParams = next;
});

const uploadMediaFile = async (event, target = 'whatsapp') => {
  const file = event.target?.files?.[0];
  if (!file) return;

  isUploadingMedia.value = true;
  mediaUploadStatus.value = t('DISPARADOR.CAMPAIGNS.MEDIA_UPLOADING');
  try {
    const { data } = await DisparadorAPI.uploadMedia(file);
    if (target === 'evolution') {
      form.value.evolution_media_url = data.media_url || data.url;
      form.value.evolution_media_type = data.media_type || 'image';
      form.value.evolution_media_filename =
        data.filename || data.original_filename || file.name;
    } else {
      form.value.header_media_url = data.media_url || data.url;
      form.value.header_media_type = data.media_type || '';
      form.value.header_media_name =
        data.media_name || data.original_filename || '';
    }
    mediaUploadStatus.value = t('DISPARADOR.CAMPAIGNS.MEDIA_UPLOAD_OK');
  } catch (error) {
    mediaUploadStatus.value =
      error?.response?.data?.error ||
      t('DISPARADOR.CAMPAIGNS.MEDIA_UPLOAD_ERROR');
    useAlert(mediaUploadStatus.value);
  } finally {
    isUploadingMedia.value = false;
    if (event.target) event.target.value = '';
  }
};

const downloadCsvModel = () => {
  const keys = isEvolution.value
    ? csvVarKeysForExport(variableKeys.value)
    : csvVarKeysForExport(variableKeys.value);
  const csv = buildCsvModel(keys);
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = 'modelo-contatos-campanha.csv';
  link.click();
  window.URL.revokeObjectURL(url);
};

const onCsvUpload = event => {
  const file = event.target?.files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const imported = csvToRecipientLines(reader.result, variableKeys.value);
      if (!imported.length) {
        useAlert(t('DISPARADOR.CAMPAIGNS.CSV_EMPTY'));
        return;
      }
      form.value.recipientsText = appendRecipientLines(
        form.value.recipientsText,
        imported
      );
      useAlert(t('DISPARADOR.CAMPAIGNS.CSV_IMPORT_OK', { n: imported.length }));
    } catch (error) {
      useAlert(
        error?.message === 'CSV_NEEDS_PHONE'
          ? t('DISPARADOR.CAMPAIGNS.CSV_NEEDS_PHONE')
          : t('DISPARADOR.CAMPAIGNS.CSV_IMPORT_ERROR')
      );
    } finally {
      if (event.target) event.target.value = '';
    }
  };
  reader.onerror = () => {
    useAlert(t('DISPARADOR.CAMPAIGNS.CSV_IMPORT_ERROR'));
    if (event.target) event.target.value = '';
  };
  reader.readAsText(file, 'UTF-8');
};

const fetchContactsByLabel = async label => {
  const items = [];
  let page = 1;
  /* eslint-disable no-await-in-loop -- paginated ContactAPI fetch */
  while (items.length < 500) {
    const { data } = await ContactAPI.get(page, 'name', label);
    const batch = data.payload || [];
    items.push(...batch);
    if (batch.length < 15) break;
    page += 1;
  }
  /* eslint-enable no-await-in-loop */
  return items.slice(0, 500);
};

const fetchConversationsByLabel = async label => {
  const items = [];
  let page = 1;
  /* eslint-disable no-await-in-loop -- paginated ConversationAPI fetch */
  while (items.length < 500) {
    const { data } = await ConversationAPI.get({
      status: 'all',
      assigneeType: 'all',
      page,
      labels: [label],
      inboxId: form.value.inbox_id || undefined,
    });
    const batch = data.data?.payload || data.payload || [];
    items.push(...batch);
    if (batch.length < 15) break;
    page += 1;
  }
  /* eslint-enable no-await-in-loop */
  return items.slice(0, 500);
};

const importFromLabel = async () => {
  if (!importLabel.value) {
    useAlert(t('DISPARADOR.CAMPAIGNS.LABEL_REQUIRED'));
    return;
  }

  isImportingLabel.value = true;
  try {
    const extras = { ...recipientExtras.value };
    let lines = [];

    if (importSource.value === 'conversations') {
      const conversations = await fetchConversationsByLabel(importLabel.value);
      lines = conversations
        .map(conv => {
          const sender = conv.meta?.sender || {};
          const phone = formatPhoneForLine(
            sender.phone_number || conv.meta?.sender?.phone_number
          );
          if (!phone) return null;
          const name = sender.name || sender.available_name || '';
          const digits = normalizePhoneDigits(phone);
          extras[digits] = {
            conversation_id: conv.id,
            contact_id: sender.id || null,
          };
          extras[phone] = extras[digits];
          return `${phone},${name}`;
        })
        .filter(Boolean);
    } else {
      const contacts = await fetchContactsByLabel(importLabel.value);
      lines = contacts
        .map(contact => {
          const phone = formatPhoneForLine(contact.phone_number);
          if (!phone) return null;
          const digits = normalizePhoneDigits(phone);
          extras[digits] = {
            contact_id: contact.id,
            conversation_id: null,
          };
          extras[phone] = extras[digits];
          return `${phone},${contact.name || ''}`;
        })
        .filter(Boolean);
    }

    if (!lines.length) {
      useAlert(
        importSource.value === 'conversations'
          ? t('DISPARADOR.CAMPAIGNS.LABEL_EMPTY_CONVERSATIONS')
          : t('DISPARADOR.CAMPAIGNS.LABEL_EMPTY_CONTACTS')
      );
      return;
    }

    recipientExtras.value = extras;
    form.value.recipientsText = appendRecipientLines(
      form.value.recipientsText,
      lines
    );
    useAlert(
      t('DISPARADOR.CAMPAIGNS.LABEL_IMPORT_OK', {
        n: lines.length,
        type:
          importSource.value === 'conversations'
            ? t(
                'DISPARADOR.CAMPAIGNS.IMPORT_SOURCE_CONVERSATIONS'
              ).toLowerCase()
            : t('DISPARADOR.CAMPAIGNS.IMPORT_SOURCE_CONTACTS').toLowerCase(),
      })
    );
  } catch (error) {
    useAlert(t('DISPARADOR.CAMPAIGNS.LABEL_IMPORT_ERROR'));
  } finally {
    isImportingLabel.value = false;
  }
};

const createCampaign = async () => {
  if (!form.value.name?.trim()) return;
  if (!form.value.inbox_id) {
    useAlert(
      t(
        isEvolution.value
          ? 'DISPARADOR.CAMPAIGNS.INBOX_API_REQUIRED'
          : 'DISPARADOR.CAMPAIGNS.INBOX_REQUIRED'
      )
    );
    return;
  }

  if (isEvolution.value) {
    if (
      !form.value.message_template?.trim() &&
      !form.value.evolution_media_url
    ) {
      useAlert(t('DISPARADOR.CAMPAIGNS.MESSAGE_REQUIRED'));
      return;
    }
  } else if (!selectedTemplate.value) {
    useAlert(t('DISPARADOR.CAMPAIGNS.TEMPLATE_REQUIRED'));
    return;
  }

  if (needsHeaderMedia.value && !form.value.header_media_url) {
    useAlert(t('DISPARADOR.CAMPAIGNS.MEDIA_REQUIRED'));
    return;
  }

  const inboxList = isEvolution.value
    ? apiInboxes.value
    : whatsAppInboxes.value || [];
  const inbox = inboxList.find(
    item => Number(item.id) === Number(form.value.inbox_id)
  );

  let metadata;
  let messageTemplate;
  if (isEvolution.value) {
    metadata = buildEvolutionMetadata({
      inboxName: inbox?.name || '',
      agentName: currentUser.value?.name || '',
      mediaUrl: form.value.evolution_media_url,
      mediaType: form.value.evolution_media_type,
      mediaFilename: form.value.evolution_media_filename,
      delaySeconds: form.value.evolution_delay_seconds,
      bodyParams: form.value.bodyParams,
      variableKeys: variableKeys.value,
    });
    messageTemplate = form.value.message_template.trim();
  } else {
    metadata = buildTemplateMetadata({
      template: selectedTemplate.value,
      bodyParams: form.value.bodyParams,
      headerMediaUrl: form.value.header_media_url,
      headerMediaType:
        form.value.header_media_type ||
        (headerComponent.value?.format || '').toLowerCase(),
      headerMediaName: form.value.header_media_name,
      dispatchMode: form.value.dispatch_mode,
      inboxName: inbox?.name || '',
      agentName: currentUser.value?.name || '',
    });
    messageTemplate = extractBodyText(selectedTemplate.value);
  }

  const recipients = parseRecipientsText(
    form.value.recipientsText,
    variableKeys.value,
    recipientExtras.value
  );
  if (!recipients.length) {
    useAlert(t('DISPARADOR.CAMPAIGNS.RECIPIENTS_REQUIRED'));
    return;
  }

  isSaving.value = true;
  try {
    await DisparadorAPI.createCampaign({
      name: form.value.name.trim(),
      inbox_id: form.value.inbox_id,
      channel: form.value.channel,
      message_template: messageTemplate,
      scheduled_at: form.value.scheduled_at
        ? new Date(form.value.scheduled_at).toISOString()
        : undefined,
      metadata,
      recipients,
    });
    showCreate.value = false;
    await loadCampaigns();
  } catch (error) {
    useAlert(t('DISPARADOR.CAMPAIGNS.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const archiveCampaign = async (campaign, event) => {
  event?.stopPropagation?.();
  try {
    if (campaign.archived_at) {
      await DisparadorAPI.unarchiveCampaign(campaign.id);
    } else {
      await DisparadorAPI.archiveCampaign(campaign.id);
    }
    await loadCampaigns();
  } catch (error) {
    useAlert(t('DISPARADOR.CAMPAIGNS.SAVE_ERROR'));
  }
};

watch([archiveFilter, searchQuery], () => {
  loadCampaigns();
});

onMounted(async () => {
  try {
    await Promise.all([
      store.dispatch('inboxes/get'),
      store.dispatch('labels/get'),
    ]);
  } catch {
    // inbox/labels optional for listing campaigns
  }
  await loadCampaigns();
});
</script>

<template>
  <div
    class="flex h-full min-h-0 w-full min-w-0 flex-1 flex-col overflow-hidden bg-n-background text-n-slate-12"
  >
    <div class="min-h-0 flex-1 overflow-y-auto">
      <div class="flex w-full min-w-0 flex-col gap-5 px-6 py-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 class="flex items-center gap-2 text-xl font-semibold">
              <span
                class="inline-flex size-7 items-center justify-center rounded-md bg-n-brand text-white"
              >
                <span class="i-lucide-megaphone size-4" />
              </span>
              {{ t('DISPARADOR.CAMPAIGNS.TITLE') }}
            </h1>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('DISPARADOR.CAMPAIGNS.DESCRIPTION') }}
            </p>
          </div>
          <Button
            :label="t('DISPARADOR.CAMPAIGNS.NEW')"
            icon="i-lucide-plus"
            size="sm"
            @click="openCreate"
          />
        </div>

        <div
          v-if="pageError"
          class="rounded-xl border border-n-ruby-6 bg-n-ruby-3 px-4 py-3 text-sm text-n-ruby-11"
        >
          {{ pageError }}
        </div>

        <div
          class="grid w-full grid-cols-2 gap-3 md:grid-cols-4 xl:grid-cols-7"
        >
          <div
            v-for="card in overviewCards"
            :key="card.key"
            class="flex items-center justify-between gap-3 rounded-xl border border-n-weak p-4"
            :class="
              card.accent
                ? 'bg-n-brand text-white border-n-brand'
                : 'bg-n-solid-1'
            "
          >
            <div class="min-w-0">
              <p
                class="text-[11px] font-semibold uppercase tracking-wide"
                :class="card.accent ? 'text-white/80' : 'text-n-slate-11'"
              >
                {{ card.label }}
              </p>
              <p class="mt-1 truncate text-2xl font-semibold">
                {{ card.value }}
              </p>
            </div>
            <span
              class="inline-flex size-10 shrink-0 items-center justify-center rounded-xl"
              :class="card.iconClass"
            >
              <span class="size-5" :class="[card.icon]" />
            </span>
          </div>
        </div>

        <div
          class="flex w-full flex-wrap items-end gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-4"
        >
          <label
            class="flex min-w-[140px] flex-col gap-1 text-xs font-medium text-n-slate-11"
          >
            {{ t('DISPARADOR.FILTERS.FROM') }}
            <input
              v-model="dateFrom"
              type="date"
              class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            />
          </label>
          <label
            class="flex min-w-[140px] flex-col gap-1 text-xs font-medium text-n-slate-11"
          >
            {{ t('DISPARADOR.FILTERS.TO') }}
            <input
              v-model="dateTo"
              type="date"
              class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            />
          </label>
          <label
            class="flex min-w-[160px] flex-col gap-1 text-xs font-medium text-n-slate-11"
          >
            {{ t('DISPARADOR.FILTERS.SHOW') }}
            <select
              v-model="archiveFilter"
              class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            >
              <option
                v-for="opt in archiveOptions"
                :key="opt.value"
                :value="opt.value"
              >
                {{ opt.label }}
              </option>
            </select>
          </label>
          <label
            class="flex min-w-[200px] flex-1 flex-col gap-1 text-xs font-medium text-n-slate-11"
          >
            {{ t('DISPARADOR.FILTERS.SEARCH') }}
            <input
              v-model="searchQuery"
              type="search"
              class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              :placeholder="t('DISPARADOR.CAMPAIGNS.SEARCH_PLACEHOLDER')"
            />
          </label>
          <div class="flex flex-wrap gap-2">
            <Button
              :label="t('DISPARADOR.FILTERS.APPLY')"
              size="sm"
              @click="applyFilters"
            />
            <Button
              :label="t('DISPARADOR.FILTERS.CLEAR')"
              variant="outline"
              color="slate"
              size="sm"
              @click="clearFilters"
            />
            <Button
              :label="t('DISPARADOR.FILTERS.EXCEL')"
              variant="outline"
              color="slate"
              size="sm"
              :is-loading="isExporting"
              @click="exportExcel"
            />
            <Button
              :label="t('DISPARADOR.FILTERS.PDF')"
              variant="outline"
              color="slate"
              size="sm"
              @click="exportPdf"
            />
          </div>
        </div>

        <div
          v-if="isFetching"
          class="flex flex-1 items-center justify-center py-16"
        >
          <Spinner />
        </div>

        <div
          v-else-if="!campaigns.length"
          class="flex flex-1 flex-col items-center justify-center rounded-xl border border-dashed border-n-weak bg-n-solid-1 px-6 py-16 text-center"
        >
          <p class="text-sm text-n-slate-11">
            {{ t('DISPARADOR.CAMPAIGNS.EMPTY') }}
          </p>
        </div>

        <div
          v-else
          class="w-full overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
        >
          <div
            class="flex items-center justify-between border-b border-n-weak px-4 py-3"
          >
            <h2 class="text-sm font-semibold">
              {{ t('DISPARADOR.CAMPAIGNS.TABLE_TITLE') }}
            </h2>
            <span class="text-xs text-n-slate-11">
              {{
                t('DISPARADOR.CAMPAIGNS.TABLE_COUNT', {
                  n: campaigns.length,
                })
              }}
            </span>
          </div>
          <div class="w-full overflow-x-auto">
            <table class="w-full min-w-[960px] text-left text-sm">
              <thead
                class="border-b border-n-weak bg-n-alpha-1 text-n-slate-11"
              >
                <tr>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.CAMPAIGNS.COL_NAME') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.CAMPAIGNS.COL_STATUS') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.CAMPAIGNS.COL_DISPATCH') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.CAMPAIGNS.COL_INBOX') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.CAMPAIGNS.COL_RECIPIENTS') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.CAMPAIGNS.COL_SENT') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.CAMPAIGNS.COL_FAILED') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.CAMPAIGNS.COL_REPLIED') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.OVERVIEW.REPLY_RATE') }}
                  </th>
                  <th class="px-4 py-3 font-medium" />
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="campaign in campaigns"
                  :key="campaign.id"
                  class="cursor-pointer border-b border-n-weak last:border-0 hover:bg-n-alpha-1"
                  @click="openDetail(campaign)"
                >
                  <td class="px-4 py-3 font-medium">
                    {{ campaign.name }}
                    <div
                      v-if="campaign.template_name"
                      class="text-xs font-normal text-n-slate-11"
                    >
                      {{ campaign.template_name }}
                    </div>
                  </td>
                  <td class="px-4 py-3">
                    <span
                      class="inline-flex rounded-full bg-n-brand/10 px-2 py-0.5 text-xs font-medium text-n-brand"
                    >
                      {{ statusLabel(campaign.status) }}
                    </span>
                  </td>
                  <td class="px-4 py-3 text-n-slate-11">
                    {{ formatDispatchAt(campaign) }}
                  </td>
                  <td class="px-4 py-3">
                    {{ campaign.inbox_name || '—' }}
                  </td>
                  <td class="px-4 py-3">
                    {{ campaign.total_recipients || 0 }}
                  </td>
                  <td class="px-4 py-3">
                    {{ campaign.sent_count || 0 }}
                  </td>
                  <td class="px-4 py-3">
                    {{ campaign.failed_count || 0 }}
                  </td>
                  <td class="px-4 py-3">
                    {{ campaign.replied_count || 0 }}
                  </td>
                  <td class="px-4 py-3">{{ campaign.reply_rate || 0 }}%</td>
                  <td class="px-4 py-3">
                    <Button
                      :label="
                        campaign.archived_at
                          ? t('DISPARADOR.CAMPAIGNS.UNARCHIVE')
                          : t('DISPARADOR.CAMPAIGNS.ARCHIVE')
                      "
                      variant="ghost"
                      size="sm"
                      @click="archiveCampaign(campaign, $event)"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <TeleportWithDirection to="body">
      <div
        v-if="showCreate"
        class="fixed inset-0 z-[100000] flex items-center justify-center bg-n-alpha-black2 p-4"
        @click.self="closeCreate"
      >
        <div
          class="max-h-[92vh] w-full max-w-5xl overflow-auto rounded-xl border border-n-weak bg-n-solid-1 p-5 shadow-lg"
          role="dialog"
          aria-modal="true"
          @click.stop
        >
          <h2 class="text-lg font-semibold">
            {{ t('DISPARADOR.CAMPAIGNS.CREATE_TITLE') }}
          </h2>

          <div class="mt-4 grid gap-4 lg:grid-cols-2">
            <!-- Dados da campanha -->
            <div
              class="flex flex-col gap-3 rounded-xl border border-n-weak bg-n-solid-2 p-4"
            >
              <p
                class="text-xs font-semibold uppercase tracking-wide text-n-slate-11"
              >
                {{ t('DISPARADOR.CAMPAIGNS.PANEL_CAMPAIGN') }}
              </p>

              <label class="flex flex-col gap-1 text-sm">
                <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_NAME') }}</span>
                <input
                  v-model="form.name"
                  type="text"
                  class="h-9 rounded-lg border border-n-weak bg-n-background px-3 outline-none focus:border-n-brand"
                  :placeholder="
                    t('DISPARADOR.CAMPAIGNS.FIELD_NAME_PLACEHOLDER')
                  "
                />
              </label>

              <label class="flex flex-col gap-1 text-sm">
                <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_CHANNEL') }}</span>
                <select
                  v-model="form.channel"
                  class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm outline-none focus:border-n-brand"
                >
                  <option
                    v-for="opt in channelOptions"
                    :key="opt.value"
                    :value="opt.value"
                  >
                    {{ opt.label }}
                  </option>
                </select>
              </label>

              <label class="flex flex-col gap-1 text-sm">
                <span>
                  {{
                    isEvolution
                      ? t('DISPARADOR.CAMPAIGNS.FIELD_INBOX_API')
                      : t('DISPARADOR.CAMPAIGNS.FIELD_INBOX')
                  }}
                </span>
                <select
                  v-model="form.inbox_id"
                  class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('DISPARADOR.CAMPAIGNS.FIELD_INBOX_PLACEHOLDER') }}
                  </option>
                  <option
                    v-for="opt in inboxOptions"
                    :key="opt.value"
                    :value="opt.value"
                  >
                    {{ opt.label }}
                  </option>
                </select>
                <span v-if="isEvolution" class="text-xs text-n-slate-11">
                  {{ t('DISPARADOR.CAMPAIGNS.FIELD_INBOX_API_HINT') }}
                </span>
              </label>

              <label v-if="!isEvolution" class="flex flex-col gap-1 text-sm">
                <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_MODE') }}</span>
                <select
                  v-model="form.dispatch_mode"
                  class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm outline-none focus:border-n-brand"
                >
                  <option
                    v-for="opt in modeOptions"
                    :key="opt.value"
                    :value="opt.value"
                  >
                    {{ opt.label }}
                  </option>
                </select>
                <span class="text-xs text-n-slate-11">
                  {{ t('DISPARADOR.CAMPAIGNS.FIELD_MODE_HINT') }}
                </span>
              </label>

              <label v-if="isEvolution" class="flex flex-col gap-1 text-sm">
                <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_DELAY') }}</span>
                <input
                  v-model.number="form.evolution_delay_seconds"
                  type="number"
                  min="0"
                  max="300"
                  class="h-9 rounded-lg border border-n-weak bg-n-background px-3 outline-none focus:border-n-brand"
                />
                <span class="text-xs text-n-slate-11">
                  {{ t('DISPARADOR.CAMPAIGNS.FIELD_DELAY_HINT') }}
                </span>
              </label>

              <div v-if="isEvolution" class="flex flex-col gap-1 text-sm">
                <div class="flex flex-wrap items-center justify-between gap-2">
                  <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_MESSAGE') }}</span>
                  <div class="flex flex-wrap gap-1">
                    <button
                      type="button"
                      class="rounded-md border border-n-weak bg-n-background px-2 py-1 text-xs font-medium text-n-brand hover:border-n-brand"
                      @click="insertEvolutionVar('nome')"
                    >
                      {{ varTokenNome }}
                    </button>
                    <button
                      type="button"
                      class="rounded-md border border-n-weak bg-n-background px-2 py-1 text-xs font-medium text-n-brand hover:border-n-brand"
                      @click="insertEvolutionVar('agent')"
                    >
                      {{ varTokenAgent }}
                    </button>
                  </div>
                </div>
                <textarea
                  v-model="form.message_template"
                  rows="4"
                  class="rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm outline-none focus:border-n-brand"
                  :placeholder="
                    t('DISPARADOR.CAMPAIGNS.FIELD_MESSAGE_PLACEHOLDER')
                  "
                />
                <span class="text-xs text-n-slate-11">
                  {{ t('DISPARADOR.CAMPAIGNS.FIELD_MESSAGE_HINT') }}
                </span>
              </div>

              <div
                v-if="variableKeys.length"
                class="flex flex-col gap-2 rounded-lg border border-n-weak bg-n-background p-3"
              >
                <p class="text-sm font-medium">
                  {{ t('DISPARADOR.CAMPAIGNS.VARS_TITLE') }}
                </p>
                <label
                  v-for="key in variableKeys"
                  :key="key"
                  class="flex flex-col gap-1 text-sm"
                >
                  <span class="font-mono text-xs text-n-slate-11">
                    {{ variableFieldMeta(key).label }}
                  </span>
                  <input
                    v-model="form.bodyParams[key]"
                    type="text"
                    class="h-9 rounded-lg border border-n-weak bg-n-solid-2 px-3 outline-none focus:border-n-brand"
                    :placeholder="variableFieldMeta(key).placeholder"
                  />
                </label>
              </div>

              <div v-if="needsHeaderMedia" class="flex flex-col gap-2 text-sm">
                <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_URL') }}</span>
                <div class="flex flex-wrap items-center gap-2">
                  <label
                    class="inline-flex h-9 cursor-pointer items-center rounded-lg border border-n-weak bg-n-background px-3 text-xs font-medium hover:border-n-brand"
                  >
                    {{ t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_UPLOAD') }}
                    <input
                      type="file"
                      accept="image/jpeg,image/png,image/webp,video/mp4,video/3gpp,application/pdf"
                      class="hidden"
                      :disabled="isUploadingMedia"
                      @change="uploadMediaFile($event, 'whatsapp')"
                    />
                  </label>
                  <input
                    v-model="form.header_media_url"
                    type="url"
                    class="h-9 min-w-0 flex-1 rounded-lg border border-n-weak bg-n-background px-3 outline-none focus:border-n-brand"
                    :placeholder="
                      t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_URL_PLACEHOLDER')
                    "
                  />
                </div>
                <span v-if="mediaUploadStatus" class="text-xs text-n-slate-11">
                  {{ mediaUploadStatus }}
                </span>
              </div>

              <div v-if="isEvolution" class="flex flex-col gap-2 text-sm">
                <span>{{
                  t('DISPARADOR.CAMPAIGNS.FIELD_EVOLUTION_MEDIA')
                }}</span>
                <div class="flex flex-wrap items-center gap-2">
                  <label
                    class="inline-flex h-9 cursor-pointer items-center rounded-lg border border-n-weak bg-n-background px-3 text-xs font-medium hover:border-n-brand"
                  >
                    {{ t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_UPLOAD') }}
                    <input
                      type="file"
                      accept="image/jpeg,image/png,image/webp,video/mp4,video/3gpp,application/pdf"
                      class="hidden"
                      :disabled="isUploadingMedia"
                      @change="uploadMediaFile($event, 'evolution')"
                    />
                  </label>
                  <input
                    v-model="form.evolution_media_url"
                    type="url"
                    class="h-9 min-w-0 flex-1 rounded-lg border border-n-weak bg-n-background px-3 outline-none focus:border-n-brand"
                    :placeholder="
                      t('DISPARADOR.CAMPAIGNS.FIELD_MEDIA_URL_PLACEHOLDER')
                    "
                  />
                </div>
                <span class="text-xs text-n-slate-11">
                  {{ t('DISPARADOR.CAMPAIGNS.FIELD_EVOLUTION_MEDIA_HINT') }}
                </span>
              </div>
            </div>

            <!-- Dados do template -->
            <div
              class="flex flex-col gap-3 rounded-xl border border-n-weak bg-n-solid-2 p-4"
            >
              <p
                class="text-xs font-semibold uppercase tracking-wide text-n-slate-11"
              >
                {{ t('DISPARADOR.CAMPAIGNS.PANEL_TEMPLATE') }}
              </p>

              <template v-if="!isEvolution">
                <label class="flex flex-col gap-1 text-sm">
                  <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_TEMPLATE') }}</span>
                  <select
                    v-model="form.template_name"
                    class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm outline-none focus:border-n-brand"
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

                <p v-if="selectedTemplate" class="text-xs text-n-slate-11">
                  {{ templateVariablesHint }}
                </p>

                <div
                  v-if="!selectedTemplate"
                  class="rounded-lg border border-dashed border-n-weak bg-n-background px-4 py-8 text-center text-sm text-n-slate-11"
                >
                  {{ t('DISPARADOR.CAMPAIGNS.TEMPLATE_PREVIEW_EMPTY') }}
                </div>

                <div
                  v-else
                  class="space-y-3 rounded-lg border border-n-weak bg-n-background p-3"
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

                  <div class="grid gap-3 sm:grid-cols-2">
                    <div
                      class="rounded-lg border border-n-weak p-3 sm:col-span-2"
                    >
                      <p
                        class="mb-1 text-[11px] font-semibold uppercase tracking-wide text-n-slate-11"
                      >
                        {{ t('DISPARADOR.CAMPAIGNS.TEMPLATE_PREVIEW_TITLE') }}
                      </p>
                      <p
                        v-if="templateHeaderText"
                        class="mb-1 text-sm font-medium"
                      >
                        {{
                          renderPreviewText(
                            templateHeaderText,
                            form.bodyParams || {},
                            currentUser?.name || ''
                          )
                        }}
                      </p>
                      <p class="whitespace-pre-wrap text-sm">
                        {{ templatePreviewText }}
                      </p>
                    </div>

                    <div class="rounded-lg border border-n-weak p-3">
                      <p
                        class="mb-1 text-[11px] font-semibold uppercase tracking-wide text-n-slate-11"
                      >
                        {{ t('DISPARADOR.CAMPAIGNS.TEMPLATE_HEADER') }}
                      </p>
                      <p class="whitespace-pre-wrap text-sm text-n-slate-12">
                        {{
                          templateHeaderText ||
                          (templateHeaderFormat ? templateHeaderFormat : '—')
                        }}
                      </p>
                    </div>

                    <div class="rounded-lg border border-n-weak p-3">
                      <p
                        class="mb-1 text-[11px] font-semibold uppercase tracking-wide text-n-slate-11"
                      >
                        {{ t('DISPARADOR.CAMPAIGNS.TEMPLATE_FOOTER') }}
                      </p>
                      <p class="whitespace-pre-wrap text-sm text-n-slate-12">
                        {{ templateFooterText || '—' }}
                      </p>
                    </div>

                    <div
                      class="rounded-lg border border-n-weak p-3 sm:col-span-2"
                    >
                      <p
                        class="mb-1 text-[11px] font-semibold uppercase tracking-wide text-n-slate-11"
                      >
                        {{ t('DISPARADOR.CAMPAIGNS.TEMPLATE_BODY') }}
                      </p>
                      <p
                        class="whitespace-pre-wrap font-mono text-xs text-n-slate-12"
                      >
                        {{ templateBodyRaw || '—' }}
                      </p>
                    </div>
                  </div>
                </div>
              </template>

              <template v-else>
                <div
                  class="rounded-lg border border-n-weak bg-n-background p-3"
                >
                  <p
                    class="mb-1 text-[11px] font-semibold uppercase tracking-wide text-n-slate-11"
                  >
                    {{ t('DISPARADOR.CAMPAIGNS.TEMPLATE_PREVIEW_TITLE') }}
                  </p>
                  <p v-if="!templateBodyRaw" class="text-sm text-n-slate-11">
                    {{ t('DISPARADOR.CAMPAIGNS.TEMPLATE_PREVIEW_EMPTY_EVO') }}
                  </p>
                  <p v-else class="whitespace-pre-wrap text-sm">
                    {{ templatePreviewText }}
                  </p>
                </div>
              </template>
            </div>
          </div>

          <!-- Destinatários / import (full width) -->
          <div
            class="mt-4 space-y-4 rounded-xl border border-n-weak bg-n-solid-2 p-4"
          >
            <div>
              <p class="text-sm font-medium">
                {{ t('DISPARADOR.CAMPAIGNS.IMPORT_LABEL_TITLE') }}
              </p>
              <div class="mt-3 flex flex-wrap gap-2">
                <select
                  v-model="importSource"
                  class="h-9 min-w-[140px] rounded-lg border border-n-weak bg-n-background px-3 text-sm outline-none focus:border-n-brand"
                >
                  <option
                    v-for="opt in importSourceOptions"
                    :key="opt.value"
                    :value="opt.value"
                  >
                    {{ opt.label }}
                  </option>
                </select>
                <select
                  v-model="importLabel"
                  class="h-9 min-w-0 flex-1 rounded-lg border border-n-weak bg-n-background px-3 text-sm outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('DISPARADOR.CAMPAIGNS.IMPORT_LABEL_PLACEHOLDER') }}
                  </option>
                  <option
                    v-for="opt in labelOptions"
                    :key="opt.value"
                    :value="opt.value"
                  >
                    {{ opt.label }}
                  </option>
                </select>
                <Button
                  :label="t('DISPARADOR.CAMPAIGNS.IMPORT_LABEL_BUTTON')"
                  variant="outline"
                  size="sm"
                  :is-loading="isImportingLabel"
                  @click="importFromLabel"
                />
              </div>
              <p class="mt-2 text-xs text-n-slate-11">
                {{ importHint }}
              </p>
            </div>

            <div class="flex flex-col gap-2">
              <div class="flex flex-wrap items-center justify-between gap-2">
                <span class="text-sm font-medium">
                  {{ t('DISPARADOR.CAMPAIGNS.FIELD_RECIPIENTS') }}
                </span>
                <div class="flex flex-wrap gap-2">
                  <Button
                    :label="t('DISPARADOR.CAMPAIGNS.CSV_DOWNLOAD')"
                    variant="outline"
                    size="sm"
                    @click="downloadCsvModel"
                  />
                  <label
                    class="inline-flex h-8 cursor-pointer items-center rounded-lg border border-n-weak bg-n-background px-3 text-xs font-medium hover:border-n-brand"
                  >
                    {{ t('DISPARADOR.CAMPAIGNS.CSV_UPLOAD') }}
                    <input
                      type="file"
                      accept=".csv,text/csv,text/plain"
                      class="hidden"
                      @change="onCsvUpload"
                    />
                  </label>
                </div>
              </div>
              <textarea
                v-model="form.recipientsText"
                rows="6"
                class="rounded-lg border border-n-weak bg-n-background px-3 py-2 font-mono text-xs outline-none focus:border-n-brand"
                :placeholder="recipientsPlaceholder"
              />
              <span class="text-xs text-n-slate-11">
                {{ t('DISPARADOR.CAMPAIGNS.FIELD_RECIPIENTS_HINT') }}
              </span>
            </div>

            <label class="flex max-w-sm flex-col gap-1 text-sm">
              <span>{{ t('DISPARADOR.CAMPAIGNS.FIELD_SCHEDULE') }}</span>
              <input
                v-model="form.scheduled_at"
                type="datetime-local"
                class="h-9 rounded-lg border border-n-weak bg-n-background px-3 outline-none focus:border-n-brand"
              />
              <span class="text-xs text-n-slate-11">
                {{ t('DISPARADOR.CAMPAIGNS.FIELD_SCHEDULE_HINT') }}
              </span>
            </label>
          </div>

          <div class="mt-5 flex justify-end gap-2">
            <Button
              :label="t('DISPARADOR.CAMPAIGNS.CANCEL')"
              variant="ghost"
              size="sm"
              :disabled="isSaving"
              @click="closeCreate"
            />
            <Button
              :label="t('DISPARADOR.CAMPAIGNS.SUBMIT')"
              size="sm"
              :is-loading="isSaving"
              @click="createCampaign"
            />
          </div>
        </div>
      </div>
    </TeleportWithDirection>
  </div>
</template>
