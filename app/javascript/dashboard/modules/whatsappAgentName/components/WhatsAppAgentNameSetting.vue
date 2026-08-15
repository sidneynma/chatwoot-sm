<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useConfig } from 'dashboard/composables/useConfig';

import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import WhatsappAgentNameAPI from '../api';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const { isEnterprise } = useConfig();
const enabled = ref(
  props.inbox.provider_config?.include_agent_name_in_messages || false
);
const isUpdating = ref(false);

watch(
  () => props.inbox.provider_config?.include_agent_name_in_messages,
  value => {
    enabled.value = value || false;
  }
);

const updateSetting = async value => {
  if (isUpdating.value) return;

  const previousValue = enabled.value;
  enabled.value = value;
  isUpdating.value = true;

  try {
    await WhatsappAgentNameAPI.update(props.inbox.id, value);
    await store.dispatch('inboxes/get', props.inbox.id);
    useAlert(t('WHATSAPP_AGENT_NAME.SUCCESS'));
  } catch {
    enabled.value = previousValue;
    useAlert(t('WHATSAPP_AGENT_NAME.ERROR'));
  } finally {
    isUpdating.value = false;
  }
};
</script>

<template>
  <div
    v-show="isEnterprise"
    :class="{ 'pointer-events-none opacity-60': isUpdating }"
  >
    <SettingsToggleSection
      :model-value="enabled"
      :header="t('WHATSAPP_AGENT_NAME.TITLE')"
      :description="t('WHATSAPP_AGENT_NAME.DESCRIPTION')"
      :hide-toggle="isUpdating"
      @update:model-value="updateSetting"
    >
      <template v-if="isUpdating" #hiddenToggle>
        <Spinner class="size-4 text-n-slate-11" />
      </template>
    </SettingsToggleSection>
  </div>
</template>
