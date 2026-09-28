<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import inboxMemberAccessApi from '../api';

const { t } = useI18n();

const loading = ref(true);
const saving = ref(false);
const inboxes = ref([]);
const agents = ref([]);
const selectedInboxId = ref(null);
const memberIds = ref([]);

const selectedInbox = computed(() =>
  inboxes.value.find(inbox => inbox.id === selectedInboxId.value)
);

const agentsById = computed(() =>
  Object.fromEntries(agents.value.map(agent => [agent.id, agent]))
);

const members = computed(() =>
  memberIds.value.map(id => agentsById.value[id]).filter(Boolean)
);

const agentsToAdd = computed(() =>
  agents.value.filter(agent => !memberIds.value.includes(agent.id))
);

const load = async () => {
  loading.value = true;
  try {
    const { data } = await inboxMemberAccessApi.get();
    inboxes.value = data.inboxes || [];
    agents.value = data.agents || [];
    if (!selectedInboxId.value && inboxes.value.length) {
      selectedInboxId.value = inboxes.value[0].id;
    }
  } catch {
    useAlert(t('INBOX_MEMBER_ACCESS.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
};

watch(selectedInbox, inbox => {
  memberIds.value = inbox ? [...inbox.member_ids] : [];
});

const addAgent = event => {
  const id = Number(event.target.value);
  event.target.value = '';
  if (!id || memberIds.value.includes(id)) return;
  memberIds.value = [...memberIds.value, id];
};

const removeAgent = id => {
  memberIds.value = memberIds.value.filter(memberId => memberId !== id);
};

const save = async () => {
  if (!selectedInboxId.value) return;
  saving.value = true;
  try {
    const { data } = await inboxMemberAccessApi.updateMembers(
      selectedInboxId.value,
      memberIds.value
    );
    inboxes.value = inboxes.value.map(inbox =>
      inbox.id === data.id ? data : inbox
    );
    memberIds.value = [...data.member_ids];
    useAlert(t('INBOX_MEMBER_ACCESS.SAVED'));
  } catch {
    useAlert(t('INBOX_MEMBER_ACCESS.SAVE_ERROR'));
  } finally {
    saving.value = false;
  }
};

onMounted(load);
</script>

<template>
  <section class="flex flex-col w-full h-full bg-n-background">
    <header class="flex flex-col gap-1 px-6 py-5 border-b border-n-weak">
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('INBOX_MEMBER_ACCESS.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('INBOX_MEMBER_ACCESS.DESCRIPTION') }}
      </p>
    </header>

    <div v-if="loading" class="p-6 text-sm text-n-slate-11">
      {{ t('INBOX_MEMBER_ACCESS.TITLE') }}
    </div>
    <div v-else-if="!inboxes.length" class="p-6 text-sm text-n-slate-11">
      {{ t('INBOX_MEMBER_ACCESS.EMPTY_INBOXES') }}
    </div>
    <div v-else class="flex flex-col gap-6 max-w-3xl p-6">
      <label class="flex flex-col gap-2 text-sm text-n-slate-12">
        {{ t('INBOX_MEMBER_ACCESS.INBOX') }}
        <select
          v-model="selectedInboxId"
          class="h-10 px-3 border rounded-lg border-n-weak bg-n-background text-n-slate-12"
        >
          <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }}
          </option>
        </select>
      </label>

      <div class="flex flex-col gap-3">
        <span class="text-sm text-n-slate-12">
          {{ t('INBOX_MEMBER_ACCESS.AGENTS') }}
        </span>
        <p v-if="!members.length" class="text-sm text-n-slate-11">
          {{ t('INBOX_MEMBER_ACCESS.NO_MEMBERS') }}
        </p>
        <ul v-else class="flex flex-col border rounded-lg border-n-weak">
          <li
            v-for="agent in members"
            :key="agent.id"
            class="flex items-center justify-between px-3 py-2 border-b border-n-weak last:border-b-0"
          >
            <span class="text-sm text-n-slate-12">{{ agent.name }}</span>
            <Button
              variant="faded"
              color="slate"
              size="sm"
              type="button"
              icon="i-lucide-x"
              @click="removeAgent(agent.id)"
            />
          </li>
        </ul>

        <label class="flex flex-col gap-2 text-sm text-n-slate-12">
          {{ t('INBOX_MEMBER_ACCESS.ADD_AGENT') }}
          <select
            class="h-10 px-3 border rounded-lg border-n-weak bg-n-background text-n-slate-12"
            :disabled="!agentsToAdd.length"
            @change="addAgent"
          >
            <option value="">
              {{
                agentsToAdd.length
                  ? t('INBOX_MEMBER_ACCESS.ADD_AGENT')
                  : t('INBOX_MEMBER_ACCESS.EMPTY_AGENTS')
              }}
            </option>
            <option
              v-for="agent in agentsToAdd"
              :key="agent.id"
              :value="agent.id"
            >
              {{ agent.name }}
            </option>
          </select>
        </label>
      </div>

      <div>
        <Button
          type="button"
          :label="t('INBOX_MEMBER_ACCESS.SAVE')"
          :is-loading="saving"
          @click="save"
        />
      </div>
    </div>
  </section>
</template>
