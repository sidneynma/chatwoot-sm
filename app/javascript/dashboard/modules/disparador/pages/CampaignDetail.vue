<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import DisparadorAPI from '../api';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const campaignId = computed(() => Number(route.params.campaignId));
const campaign = ref(null);
const stats = ref({});
const recipients = ref([]);
const isLoading = ref(true);
const isDispatching = ref(false);
const isRefreshing = ref(false);
const showTemplate = ref(false);
const dispatchMode = ref('meta_direct');
let pollTimer = null;

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

const statusLabel = status =>
  t(`DISPARADOR.CAMPAIGNS.STATUS.${status}`, status);

const recipientStatusLabel = status =>
  t(`DISPARADOR.RECIPIENT_STATUS.${status}`, status);

const formatDateTime = value => {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const formatDateTimeH = value => {
  const s = formatDateTime(value);
  return s === '—' ? s : `${s}h`;
};

const ratePct = (num, den) => {
  const n = Number(num) || 0;
  const d = Number(den) || 0;
  if (!d) return 0;
  return Math.round((n / d) * 1000) / 10;
};

const formatPct = value => {
  const p = Number(value) || 0;
  if (p <= 0) return '0%';
  return Number.isInteger(p) ? `${p}%` : `${p.toFixed(1)}%`;
};

const channelLabel = channel => {
  const c = String(channel || '').toLowerCase();
  if (c === 'evolution') return t('DISPARADOR.DETAIL.CHANNEL_EVOLUTION');
  if (c === 'whatsapp') return t('DISPARADOR.DETAIL.CHANNEL_WHATSAPP');
  return channel || '—';
};

const dispatchModeLabel = computed(() => {
  if (dispatchMode.value === 'conversation') {
    return t('DISPARADOR.DETAIL.MODE_CONVERSATION');
  }
  return t('DISPARADOR.DETAIL.MODE_META_DIRECT');
});

const messageInterval = computed(() => {
  const meta = campaign.value?.metadata || {};
  const delay =
    meta.evolution_delay_seconds ??
    meta.send_interval_seconds ??
    meta.message_interval_seconds;
  if (delay === undefined || delay === null || delay === '') {
    if (campaign.value?.channel === 'evolution') return 15;
    return null;
  }
  return Number(delay);
});

const showInterval = computed(
  () => campaign.value?.channel === 'evolution' || messageInterval.value != null
);

const campaignStatusClass = status => {
  const map = {
    draft: 'bg-n-slate-3 text-n-slate-11',
    scheduled: 'bg-n-amber-3 text-n-amber-11',
    running: 'bg-n-brand/15 text-n-brand',
    paused: 'bg-n-slate-3 text-n-slate-11',
    completed: 'bg-n-teal-3 text-n-teal-11',
    cancelled: 'bg-n-slate-3 text-n-slate-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
  };
  return map[status] || 'bg-n-slate-3 text-n-slate-11';
};

const recipientStatusClass = status => {
  const map = {
    pending: 'bg-n-slate-3 text-n-slate-11',
    queued: 'bg-n-slate-3 text-n-slate-11',
    sent: 'bg-n-blue-3 text-n-blue-11',
    delivered: 'bg-n-teal-3 text-n-teal-11',
    read: 'bg-n-teal-3 text-n-teal-11',
    replied: 'bg-n-brand/15 text-n-brand',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
    opted_out: 'bg-n-amber-3 text-n-amber-11',
    bounced: 'bg-n-ruby-3 text-n-ruby-11',
    cancelled: 'bg-n-slate-3 text-n-slate-11',
  };
  return map[status] || 'bg-n-slate-3 text-n-slate-11';
};

const detailCards = computed(() => {
  const rec = Number(stats.value.total_recipients) || 0;
  const sent = Number(stats.value.sent_count) || 0;
  const delivered = Number(stats.value.delivered_count) || 0;
  const read = Number(stats.value.read_count) || 0;
  const replied = Number(stats.value.replied_count) || 0;
  const failed = Number(stats.value.failed_count) || 0;
  const totalEnvios = sent + failed;

  return [
    {
      key: 'total',
      label: t('DISPARADOR.DETAIL.STATS.TOTAL'),
      value: rec,
      pct: null,
      positive: true,
      accent: false,
      icon: 'i-lucide-users',
    },
    {
      key: 'sent',
      label: t('DISPARADOR.DETAIL.STATS.SENT'),
      value: sent,
      pct: ratePct(sent, rec),
      positive: true,
      accent: false,
      icon: 'i-lucide-send',
    },
    {
      key: 'delivered',
      label: t('DISPARADOR.DETAIL.STATS.DELIVERED'),
      value: delivered,
      pct: ratePct(delivered, sent || rec),
      positive: true,
      accent: false,
      icon: 'i-lucide-check-check',
    },
    {
      key: 'read',
      label: t('DISPARADOR.DETAIL.STATS.READ'),
      value: read,
      pct: ratePct(read, sent || rec),
      positive: true,
      accent: false,
      icon: 'i-lucide-eye',
    },
    {
      key: 'replied',
      label: t('DISPARADOR.DETAIL.STATS.REPLIED'),
      value: replied,
      pct: stats.value.reply_rate ?? ratePct(replied, sent || rec),
      positive: true,
      accent: false,
      icon: 'i-lucide-message-circle',
    },
    {
      key: 'failed',
      label: t('DISPARADOR.DETAIL.STATS.FAILED'),
      value: failed,
      pct: ratePct(failed, rec),
      positive: false,
      accent: false,
      icon: 'i-lucide-circle-alert',
    },
    {
      key: 'total_envios',
      label: t('DISPARADOR.DETAIL.STATS.TOTAL_SENDS'),
      value: totalEnvios,
      pct: ratePct(totalEnvios, rec),
      positive: true,
      accent: true,
      icon: 'i-lucide-mail',
    },
  ];
});

const templatePreview = computed(() => {
  if (!campaign.value) return '';
  const meta = campaign.value.metadata?.template || {};
  const name = meta.name || campaign.value.template_name;
  const lang = meta.language;
  const body =
    campaign.value.message_template ||
    meta.body ||
    t('DISPARADOR.DETAIL.NO_TEMPLATE');
  const header = [name, lang].filter(Boolean).join(' · ');
  return header ? `${header}\n\n${body}` : body;
});

const loadAll = async ({ quiet = false } = {}) => {
  if (!quiet) isLoading.value = true;
  try {
    const [campaignRes, statsRes, recipientsRes] = await Promise.all([
      DisparadorAPI.getCampaign(campaignId.value),
      DisparadorAPI.getStats(campaignId.value),
      DisparadorAPI.getRecipients(campaignId.value, { limit: 200 }),
    ]);
    campaign.value = campaignRes.data;
    stats.value = {
      ...(statsRes.data.payload || {}),
      reply_rate: campaignRes.data?.reply_rate,
    };
    // Prefer campaign payload counts when stats payload is thin
    if (!stats.value.total_recipients && campaignRes.data) {
      stats.value = {
        total_recipients: campaignRes.data.total_recipients,
        sent_count: campaignRes.data.sent_count,
        delivered_count: campaignRes.data.delivered_count,
        read_count: campaignRes.data.read_count,
        replied_count: campaignRes.data.replied_count,
        failed_count: campaignRes.data.failed_count,
        pending_count: campaignRes.data.pending_count,
        queued_count: campaignRes.data.queued_count,
        reply_rate: campaignRes.data.reply_rate,
        ...stats.value,
      };
    }
    recipients.value = recipientsRes.data.payload || [];
    dispatchMode.value =
      campaign.value.dispatch_mode ||
      campaign.value.metadata?.dispatch_mode ||
      'meta_direct';
  } catch (error) {
    useAlert(t('DISPARADOR.CAMPAIGNS.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
    isRefreshing.value = false;
  }
};

const goBack = () => {
  router.push(accountScopedRoute('disparador_campaigns_index'));
};

const stopPolling = () => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
};

const startPolling = () => {
  stopPolling();
  pollTimer = setInterval(async () => {
    if (!campaign.value || campaign.value.status !== 'running') {
      stopPolling();
      return;
    }
    try {
      const { data } = await DisparadorAPI.getDispatchStatus(campaignId.value);
      const payload = data.payload || {};
      stats.value = {
        ...stats.value,
        ...payload,
        sent_count: payload.sent,
        failed_count: payload.failed,
        delivered_count: payload.delivered,
        read_count: payload.read,
        replied_count: payload.replied,
        pending_count: payload.pending,
        queued_count: payload.queued,
        total_recipients: payload.total,
      };
      if (payload.campaign_status) {
        campaign.value = {
          ...campaign.value,
          status: payload.campaign_status,
        };
      }
      if (payload.campaign_status !== 'running') {
        await loadAll({ quiet: true });
        stopPolling();
      }
    } catch {
      // ignore poll errors
    }
  }, 2500);
};

const startDispatch = async ({ retry = false } = {}) => {
  isDispatching.value = true;
  try {
    if (retry) {
      await DisparadorAPI.retryFailed(campaignId.value, {
        dispatch_mode: dispatchMode.value,
      });
    } else {
      await DisparadorAPI.dispatchCampaign(campaignId.value, {
        dispatch_mode: dispatchMode.value,
      });
    }
    await loadAll({ quiet: true });
    startPolling();
  } catch (error) {
    useAlert(t('DISPARADOR.DETAIL.DISPATCH_ERROR'));
  } finally {
    isDispatching.value = false;
  }
};

const archiveToggle = async () => {
  try {
    if (campaign.value.archived_at) {
      await DisparadorAPI.unarchiveCampaign(campaignId.value);
    } else {
      await DisparadorAPI.archiveCampaign(campaignId.value);
    }
    await loadAll({ quiet: true });
  } catch (error) {
    useAlert(t('DISPARADOR.CAMPAIGNS.SAVE_ERROR'));
  }
};

const refresh = async () => {
  isRefreshing.value = true;
  await loadAll({ quiet: true });
};

const syncStatus = async () => {
  isRefreshing.value = true;
  await loadAll({ quiet: true });
  useAlert(t('DISPARADOR.DETAIL.SYNC_DONE'));
};

const downloadBlob = (blob, filename) => {
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  window.URL.revokeObjectURL(url);
};

const exportExcel = () => {
  const header = ['Nome', 'Telefone', 'Status', 'Erro'];
  const rows = recipients.value.map(r =>
    [
      r.name || '',
      r.phone || '',
      recipientStatusLabel(r.status),
      (r.error_message || '').replace(/"/g, '""'),
    ]
      .map(cell => `"${cell}"`)
      .join(',')
  );
  const csv = `\uFEFF${[header.join(','), ...rows].join('\n')}`;
  downloadBlob(
    new Blob([csv], { type: 'text/csv;charset=utf-8' }),
    `campanha_${campaignId.value}_destinatarios.csv`
  );
};

const exportPdf = () => {
  const rows = recipients.value
    .map(
      r =>
        `<tr>
          <td>${r.name || ''}</td>
          <td>${r.phone || ''}</td>
          <td>${recipientStatusLabel(r.status)}</td>
          <td>${r.error_message || ''}</td>
        </tr>`
    )
    .join('');
  const html = `<!DOCTYPE html><html><head><title>${campaign.value?.name || ''}</title>
    <style>
      body{font-family:Arial,sans-serif;padding:24px;color:#111}
      h1{font-size:18px;margin:0 0 8px}
      .meta{font-size:12px;color:#555;margin-bottom:16px}
      table{width:100%;border-collapse:collapse;font-size:12px}
      th,td{border:1px solid #ddd;padding:8px;text-align:left}
      th{background:#f5f5f5}
    </style></head><body>
    <h1>${campaign.value?.name || ''}</h1>
    <div class="meta">${statusLabel(campaign.value?.status)} · ${campaign.value?.inbox_name || ''}</div>
    <table>
      <thead><tr>
        <th>${t('DISPARADOR.DETAIL.COL_NAME')}</th>
        <th>${t('DISPARADOR.DETAIL.COL_PHONE')}</th>
        <th>${t('DISPARADOR.DETAIL.COL_STATUS')}</th>
        <th>${t('DISPARADOR.DETAIL.COL_ERROR')}</th>
      </tr></thead>
      <tbody>${rows || `<tr><td colspan="4">${t('DISPARADOR.DETAIL.NO_RECIPIENTS')}</td></tr>`}</tbody>
    </table>
    </body></html>`;
  const win = window.open('', '_blank');
  if (!win) return;
  win.document.write(html);
  win.document.close();
  win.focus();
  win.print();
};

const progressPercent = computed(() => {
  const total = stats.value.total_recipients || 0;
  if (!total) return 0;
  const done = (stats.value.sent_count || 0) + (stats.value.failed_count || 0);
  return Math.min(100, Math.round((done / total) * 100));
});

const canDispatch = computed(() => {
  if (!campaign.value) return false;
  if (campaign.value.archived_at) return false;
  return !['completed', 'cancelled'].includes(campaign.value.status);
});

const showDispatchMode = computed(() => {
  if (!campaign.value) return false;
  if (campaign.value.channel && campaign.value.channel !== 'whatsapp') {
    return false;
  }
  return canDispatch.value || campaign.value.status === 'scheduled';
});

const timelineText = computed(() => {
  if (!campaign.value?.started_at) return '';
  let text = `${t('DISPARADOR.DETAIL.STARTED')} ${formatDateTimeH(campaign.value.started_at)}`;
  if (campaign.value.completed_at) {
    text += ` · ${t('DISPARADOR.DETAIL.FINISHED_AT')} ${formatDateTimeH(campaign.value.completed_at)}`;
  }
  return text;
});

watch(
  () => campaign.value?.status,
  status => {
    if (status === 'running') startPolling();
  }
);

onMounted(async () => {
  await loadAll();
  if (campaign.value?.status === 'running') startPolling();
});

onUnmounted(stopPolling);
</script>

<template>
  <div
    class="flex h-full w-full min-w-0 flex-1 flex-col overflow-hidden bg-n-background text-n-slate-12"
  >
    <div class="flex-1 overflow-y-auto">
      <div
        v-if="isLoading"
        class="flex min-h-[40vh] items-center justify-center"
      >
        <Spinner />
      </div>

      <div
        v-else-if="campaign"
        class="flex w-full min-w-0 flex-col gap-5 px-6 py-5"
      >
        <div>
          <button
            type="button"
            class="mb-3 inline-flex items-center gap-1 text-sm text-n-slate-11 hover:text-n-brand"
            @click="goBack"
          >
            {{ t('DISPARADOR.DETAIL.BACK') }}
          </button>

          <div class="flex flex-wrap items-center gap-2">
            <h1 class="text-xl font-semibold">
              {{ campaign.name }}
            </h1>
            <span
              class="inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium"
              :class="campaignStatusClass(campaign.status)"
            >
              {{ statusLabel(campaign.status) }}
            </span>
          </div>

          <div
            class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-n-slate-11"
          >
            <span>
              <strong class="font-medium text-n-slate-12">
                {{ t('DISPARADOR.DETAIL.META_CHANNEL') }}
              </strong>
              {{ channelLabel(campaign.channel) }}
            </span>
            <span class="text-n-slate-8">·</span>
            <span>
              <strong class="font-medium text-n-slate-12">
                {{ t('DISPARADOR.DETAIL.META_INBOX') }}
              </strong>
              {{ campaign.inbox_name || t('DISPARADOR.DETAIL.EMPTY_VALUE') }}
            </span>
            <template v-if="showInterval">
              <span class="text-n-slate-8">·</span>
              <span>
                <strong class="font-medium text-n-slate-12">
                  {{ t('DISPARADOR.DETAIL.META_INTERVAL') }}
                </strong>
                {{
                  t('DISPARADOR.DETAIL.INTERVAL_SECONDS', {
                    n: messageInterval,
                  })
                }}
              </span>
            </template>
            <template v-if="campaign.channel !== 'evolution'">
              <span class="text-n-slate-8">·</span>
              <span>
                <strong class="font-medium text-n-slate-12">
                  {{ t('DISPARADOR.DETAIL.META_DISPATCH') }}
                </strong>
                {{ dispatchModeLabel }}
              </span>
            </template>
          </div>

          <div
            v-if="timelineText"
            class="mt-3 rounded-lg border border-n-teal-6/40 bg-n-teal-3/40 px-4 py-2.5 text-sm text-n-teal-12"
          >
            {{ timelineText }}
          </div>

          <div
            v-else-if="campaign.scheduled_at && !campaign.started_at"
            class="mt-3 rounded-lg border border-n-weak bg-n-solid-1 px-4 py-2.5 text-sm text-n-slate-12"
          >
            {{ t('DISPARADOR.DETAIL.SCHEDULED_FOR') }}
            {{ formatDateTime(campaign.scheduled_at) }}
          </div>
        </div>

        <div v-if="showDispatchMode" class="max-w-md">
          <label class="mb-1.5 block text-xs font-medium text-n-slate-11">
            {{ t('DISPARADOR.DETAIL.DISPATCH_MODE') }}
          </label>
          <ComboBox v-model="dispatchMode" :options="modeOptions" />
          <p class="mt-1 text-xs text-n-slate-11">
            {{ t('DISPARADOR.DETAIL.DISPATCH_MODE_HINT') }}
          </p>
        </div>

        <div
          class="grid w-full grid-cols-2 gap-3 md:grid-cols-4 xl:grid-cols-7"
        >
          <div
            v-for="card in detailCards"
            :key="card.key"
            class="flex flex-col gap-2 rounded-xl border p-4"
            :class="
              card.accent
                ? 'border-n-brand bg-n-brand text-white'
                : 'border-n-weak bg-n-solid-1'
            "
          >
            <div class="flex items-start justify-between gap-2">
              <p
                class="text-[11px] font-semibold uppercase tracking-wide"
                :class="card.accent ? 'text-white/80' : 'text-n-slate-11'"
              >
                {{ card.label }}
              </p>
              <span
                v-if="card.pct == null"
                class="text-[11px]"
                :class="card.accent ? 'text-white/70' : 'text-n-slate-10'"
              >
                —
              </span>
              <span
                v-else
                class="rounded-full px-1.5 py-0.5 text-[10px] font-semibold"
                :class="
                  card.accent
                    ? 'bg-white/20 text-white'
                    : card.positive
                      ? 'bg-n-teal-3 text-n-teal-11'
                      : 'bg-n-ruby-3 text-n-ruby-11'
                "
              >
                {{ formatPct(card.pct) }}
              </span>
            </div>
            <div class="flex items-end justify-between gap-2">
              <p class="text-2xl font-semibold tabular-nums">
                {{ card.value }}
              </p>
              <span
                class="inline-flex size-8 shrink-0 items-center justify-center rounded-lg"
                :class="
                  card.accent
                    ? 'bg-white/20 text-white'
                    : 'bg-n-alpha-2 text-n-slate-11'
                "
              >
                <span :class="card.icon" class="size-4" />
              </span>
            </div>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-2">
          <Button
            v-if="canDispatch && campaign.status !== 'completed'"
            :label="
              campaign.status === 'scheduled'
                ? t('DISPARADOR.DETAIL.DISPATCH_NOW')
                : t('DISPARADOR.DETAIL.DISPATCH_PENDING')
            "
            size="sm"
            :is-loading="isDispatching"
            @click="startDispatch()"
          />
          <Button
            v-if="(stats.failed_count || 0) > 0"
            :label="t('DISPARADOR.DETAIL.RETRY_FAILED')"
            size="sm"
            :is-loading="isDispatching"
            @click="startDispatch({ retry: true })"
          />
          <Button
            :label="t('DISPARADOR.DETAIL.SYNC_STATUS')"
            variant="outline"
            size="sm"
            :is-loading="isRefreshing"
            @click="syncStatus"
          />
          <Button
            :label="t('DISPARADOR.DETAIL.REFRESH')"
            variant="outline"
            size="sm"
            :is-loading="isRefreshing"
            @click="refresh"
          />
          <Button
            :label="t('DISPARADOR.DETAIL.SHOW_TEMPLATE')"
            variant="outline"
            size="sm"
            @click="showTemplate = !showTemplate"
          />
          <Button
            :label="t('DISPARADOR.DETAIL.EXCEL')"
            variant="outline"
            size="sm"
            @click="exportExcel"
          />
          <Button
            :label="t('DISPARADOR.DETAIL.PDF')"
            variant="outline"
            size="sm"
            @click="exportPdf"
          />
          <Button
            :label="
              campaign.archived_at
                ? t('DISPARADOR.CAMPAIGNS.UNARCHIVE')
                : t('DISPARADOR.CAMPAIGNS.ARCHIVE')
            "
            variant="ghost"
            size="sm"
            @click="archiveToggle"
          />
        </div>

        <div
          v-if="campaign.status === 'running'"
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
        >
          <div class="mb-2 flex justify-between text-sm">
            <span>{{ t('DISPARADOR.DETAIL.PROGRESS') }}</span>
            <span>
              {{
                t('DISPARADOR.DETAIL.PROGRESS_PERCENT', { n: progressPercent })
              }}
            </span>
          </div>
          <div class="h-2 overflow-hidden rounded-full bg-n-alpha-2">
            <div
              class="h-full rounded-full bg-n-brand transition-all"
              :style="{ width: `${progressPercent}%` }"
            />
          </div>
        </div>

        <div
          v-if="showTemplate"
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
        >
          <p class="mb-2 text-sm font-medium">
            {{ t('DISPARADOR.DETAIL.TEMPLATE_TITLE') }}
          </p>
          <pre
            class="whitespace-pre-wrap break-words text-sm text-n-slate-12"
            >{{ templatePreview }}</pre
          >
        </div>

        <div
          class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
        >
          <div class="border-b border-n-weak px-4 py-3 text-sm font-medium">
            {{ t('DISPARADOR.DETAIL.RECIPIENTS') }}
          </div>
          <div class="overflow-x-auto">
            <table class="w-full min-w-[640px] text-left text-sm">
              <thead class="border-b border-n-weak text-n-slate-11">
                <tr>
                  <th class="px-4 py-2 font-medium">
                    {{ t('DISPARADOR.DETAIL.COL_NAME') }}
                  </th>
                  <th class="px-4 py-2 font-medium">
                    {{ t('DISPARADOR.DETAIL.COL_PHONE') }}
                  </th>
                  <th class="px-4 py-2 font-medium">
                    {{ t('DISPARADOR.DETAIL.COL_STATUS') }}
                  </th>
                  <th class="px-4 py-2 font-medium">
                    {{ t('DISPARADOR.DETAIL.COL_ERROR') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in recipients"
                  :key="row.id"
                  class="border-b border-n-weak last:border-0"
                >
                  <td class="px-4 py-2.5">
                    {{ row.name || '—' }}
                  </td>
                  <td class="px-4 py-2.5 font-mono text-xs">
                    {{ row.phone }}
                  </td>
                  <td class="px-4 py-2.5">
                    <span
                      class="inline-flex rounded-full px-2 py-0.5 text-xs font-medium"
                      :class="recipientStatusClass(row.status)"
                    >
                      {{ recipientStatusLabel(row.status) }}
                    </span>
                  </td>
                  <td class="px-4 py-2.5 text-n-ruby-11">
                    {{ row.error_message || '' }}
                  </td>
                </tr>
                <tr v-if="!recipients.length">
                  <td colspan="4" class="px-4 py-8 text-center text-n-slate-11">
                    {{ t('DISPARADOR.DETAIL.NO_RECIPIENTS') }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
