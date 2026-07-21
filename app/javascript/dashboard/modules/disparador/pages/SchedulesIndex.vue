<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import DisparadorAPI from '../api';

const { t } = useI18n();
const { accountId } = useAccount();

const items = ref([]);
const scope = ref('mine');
const isLoading = ref(true);
const statusFilter = ref('pending');
const editing = ref(null);
const editDate = ref('');
const editMessage = ref('');
const isSaving = ref(false);
let pollTimer = null;

const statusOptions = computed(() => [
  { value: 'pending', label: t('DISPARADOR.SCHEDULES.FILTER_PENDING') },
  { value: 'sent', label: t('DISPARADOR.SCHEDULES.FILTER_SENT') },
  { value: 'failed', label: t('DISPARADOR.SCHEDULES.FILTER_FAILED') },
  { value: '', label: t('DISPARADOR.SCHEDULES.FILTER_ALL') },
]);

const scopeHint = computed(() =>
  scope.value === 'all'
    ? t('DISPARADOR.SCHEDULES.SCOPE_ALL')
    : t('DISPARADOR.SCHEDULES.SCOPE_MINE')
);

const statusLabel = status => {
  const st = status === 'queued' ? 'pending' : status;
  return t(`DISPARADOR.SCHEDULES.STATUS.${st}`, st);
};

const statusClass = status => {
  const st = status === 'queued' ? 'pending' : status;
  const map = {
    pending: 'bg-n-amber-3 text-n-amber-11',
    sent: 'bg-n-teal-3 text-n-teal-11',
    delivered: 'bg-n-teal-3 text-n-teal-11',
    read: 'bg-n-brand/10 text-n-brand',
    replied: 'bg-n-teal-3 text-n-teal-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
    cancelled: 'bg-n-slate-3 text-n-slate-11',
  };
  return map[st] || 'bg-n-slate-3 text-n-slate-11';
};

const channelLabel = channel =>
  channel === 'evolution'
    ? t('DISPARADOR.DETAIL.CHANNEL_EVOLUTION')
    : t('DISPARADOR.DETAIL.CHANNEL_WHATSAPP');

const formatDateTime = value => {
  if (!value) return '—';
  return new Date(value).toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const toDatetimeLocal = value => {
  if (!value) return '';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

const previewText = item => {
  if (item.message_type === 'template' && item.template_name) {
    return `Template: ${item.template_name}`;
  }
  const msg = item.message || '';
  return msg.length > 80 ? `${msg.slice(0, 79)}…` : msg || '—';
};

const conversationUrl = conversationId => {
  if (!conversationId || !accountId.value) return null;
  return `/app/accounts/${accountId.value}/conversations/${conversationId}`;
};

const loadSchedules = async ({ quiet = false } = {}) => {
  if (!quiet) isLoading.value = true;
  try {
    const { data } = await DisparadorAPI.getSchedules({
      status: statusFilter.value || undefined,
      limit: 200,
    });
    items.value = data.payload || [];
    scope.value = data.scope || 'mine';
  } catch (error) {
    if (!quiet) useAlert(t('DISPARADOR.SCHEDULES.LOAD_ERROR'));
  } finally {
    if (!quiet) isLoading.value = false;
  }
};

const stopPolling = () => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
};

const startPolling = () => {
  stopPolling();
  pollTimer = setInterval(() => {
    loadSchedules({ quiet: true });
  }, 5000);
};

const openEdit = item => {
  editing.value = item;
  editDate.value = toDatetimeLocal(item.scheduled_at);
  editMessage.value = item.message || '';
};

const closeEdit = () => {
  editing.value = null;
  editDate.value = '';
  editMessage.value = '';
};

const saveEdit = async () => {
  if (!editing.value) return;
  if (!editDate.value) {
    useAlert(t('DISPARADOR.SCHEDULES.DATE_REQUIRED'));
    return;
  }
  const payload = {
    scheduled_at: new Date(editDate.value).toISOString(),
  };
  if (editing.value.message_type !== 'template') {
    if (!editMessage.value.trim()) {
      useAlert(t('DISPARADOR.SCHEDULES.MESSAGE_REQUIRED'));
      return;
    }
    payload.message = editMessage.value.trim();
  }

  isSaving.value = true;
  try {
    await DisparadorAPI.updateSchedule(editing.value.id, payload);
    useAlert(t('DISPARADOR.SCHEDULES.UPDATE_OK'));
    closeEdit();
    await loadSchedules();
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
    await loadSchedules();
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('DISPARADOR.SCHEDULES.SAVE_ERROR')
    );
  }
};

onMounted(() => {
  loadSchedules();
  startPolling();
});

onUnmounted(stopPolling);
</script>

<template>
  <div
    class="flex h-full w-full min-w-0 flex-1 flex-col overflow-hidden bg-n-background text-n-slate-12"
  >
    <div class="flex-1 overflow-y-auto">
      <div class="flex w-full min-w-0 flex-col gap-5 px-6 py-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 class="text-xl font-semibold">
              {{ t('DISPARADOR.SCHEDULES.TITLE') }}
            </h1>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('DISPARADOR.SCHEDULES.DESCRIPTION') }}
            </p>
            <p class="mt-1 text-xs text-n-slate-11">
              {{ scopeHint }}
            </p>
          </div>
          <Button
            :label="t('DISPARADOR.SCHEDULES.REFRESH')"
            variant="outline"
            size="sm"
            :is-loading="isLoading"
            @click="() => loadSchedules()"
          />
        </div>

        <div
          class="flex flex-wrap items-end gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-4"
        >
          <label
            class="flex min-w-[160px] flex-col gap-1 text-xs font-medium text-n-slate-11"
          >
            {{ t('DISPARADOR.SCHEDULES.FILTER_STATUS') }}
            <select
              v-model="statusFilter"
              class="h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              @change="() => loadSchedules()"
            >
              <option
                v-for="opt in statusOptions"
                :key="String(opt.value)"
                :value="opt.value"
              >
                {{ opt.label }}
              </option>
            </select>
          </label>
        </div>

        <div
          v-if="editing"
          class="rounded-xl border-2 border-n-brand bg-n-solid-1 p-4"
        >
          <h2 class="text-sm font-semibold">
            {{ t('DISPARADOR.SCHEDULES.EDIT_TITLE', { id: editing.id }) }}
          </h2>
          <div class="mt-3 grid gap-3 md:grid-cols-2">
            <label class="flex flex-col gap-1 text-sm">
              <span>{{ t('DISPARADOR.SCHEDULES.FIELD_DATETIME') }}</span>
              <input
                v-model="editDate"
                type="datetime-local"
                class="h-9 rounded-lg border border-n-weak bg-n-solid-2 px-3 outline-none focus:border-n-brand"
              />
            </label>
            <div
              v-if="editing.message_type === 'template'"
              class="text-sm text-n-slate-11"
            >
              <p class="font-medium text-n-slate-12">
                {{ t('DISPARADOR.SCHEDULES.FIELD_TEMPLATE') }}
              </p>
              <p class="mt-1">
                {{ editing.template_name || '—' }}
              </p>
              <p class="mt-1 text-xs">
                {{ t('DISPARADOR.SCHEDULES.TEMPLATE_EDIT_HINT') }}
              </p>
            </div>
            <label v-else class="flex flex-col gap-1 text-sm md:col-span-2">
              <span>{{ t('DISPARADOR.SCHEDULES.FIELD_MESSAGE') }}</span>
              <textarea
                v-model="editMessage"
                rows="3"
                class="rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm outline-none focus:border-n-brand"
              />
            </label>
          </div>
          <div class="mt-3 flex gap-2">
            <Button
              :label="t('DISPARADOR.SCHEDULES.SAVE')"
              size="sm"
              :is-loading="isSaving"
              @click="saveEdit"
            />
            <Button
              :label="t('DISPARADOR.SCHEDULES.CLOSE')"
              variant="ghost"
              size="sm"
              @click="closeEdit"
            />
          </div>
        </div>

        <div
          v-if="isLoading"
          class="flex min-h-[30vh] items-center justify-center"
        >
          <Spinner />
        </div>

        <div
          v-else-if="!items.length"
          class="rounded-xl border border-dashed border-n-weak bg-n-solid-1 px-6 py-16 text-center text-sm text-n-slate-11"
        >
          {{ t('DISPARADOR.SCHEDULES.EMPTY') }}
        </div>

        <div
          v-else
          class="w-full overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
        >
          <div class="w-full overflow-x-auto">
            <table class="w-full min-w-[960px] text-left text-sm">
              <thead
                class="border-b border-n-weak bg-n-alpha-1 text-n-slate-11"
              >
                <tr>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.SCHEDULES.COL_DATETIME') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.SCHEDULES.COL_CONTACT') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.SCHEDULES.COL_INBOX') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.SCHEDULES.COL_MESSAGE') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.SCHEDULES.COL_STATUS') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.SCHEDULES.COL_CONVERSATION') }}
                  </th>
                  <th class="px-4 py-3 font-medium">
                    {{ t('DISPARADOR.SCHEDULES.COL_ACTIONS') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="item in items"
                  :key="item.id"
                  class="border-b border-n-weak last:border-0"
                >
                  <td class="px-4 py-3 whitespace-nowrap">
                    {{ formatDateTime(item.scheduled_at) }}
                  </td>
                  <td class="px-4 py-3">
                    <div class="font-medium">
                      {{ item.contact_name || '—' }}
                    </div>
                    <div class="font-mono text-xs text-n-slate-11">
                      {{ item.contact_phone || '' }}
                    </div>
                  </td>
                  <td class="px-4 py-3">
                    <div>{{ item.inbox_name || '—' }}</div>
                    <div class="text-xs text-n-slate-11">
                      {{ channelLabel(item.channel) }}
                    </div>
                  </td>
                  <td class="max-w-xs truncate px-4 py-3">
                    {{ previewText(item) }}
                  </td>
                  <td class="px-4 py-3">
                    <span
                      class="inline-flex rounded-full px-2 py-0.5 text-xs font-medium"
                      :class="statusClass(item.status)"
                    >
                      {{ statusLabel(item.status) }}
                    </span>
                  </td>
                  <td class="px-4 py-3">
                    <a
                      v-if="conversationUrl(item.conversation_id)"
                      :href="conversationUrl(item.conversation_id)"
                      class="text-n-brand hover:underline"
                    >
                      {{ item.conversation_id }}
                    </a>
                    <span v-else>—</span>
                  </td>
                  <td class="px-4 py-3">
                    <div
                      v-if="item.status === 'pending'"
                      class="flex flex-wrap gap-1"
                    >
                      <Button
                        :label="t('DISPARADOR.SCHEDULES.EDIT')"
                        variant="ghost"
                        size="sm"
                        @click="openEdit(item)"
                      />
                      <Button
                        :label="t('DISPARADOR.SCHEDULES.CANCEL')"
                        variant="ghost"
                        size="sm"
                        @click="cancelItem(item)"
                      />
                    </div>
                    <span v-else class="text-n-slate-11">—</span>
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
