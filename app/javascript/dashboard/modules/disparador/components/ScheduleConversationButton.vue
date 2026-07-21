<script setup>
/**
 * Merge-safe schedule trigger for conversations.
 * Wired in ConversationHeader next to Call — not inside MoreActions.
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import ScheduleConversationModal from './ScheduleConversationModal.vue';

defineProps({
  conversation: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const showModal = ref(false);

const getAccount = useMapGetter('accounts/getAccount');
const accountId = useMapGetter('getCurrentAccountId');

const schedulesEnabled = computed(() => {
  const account =
    typeof getAccount.value === 'function'
      ? getAccount.value(accountId.value)
      : null;
  return Boolean(account?.chatolhe_modules?.mensagens_agendadas);
});

const open = () => {
  showModal.value = true;
};

const close = () => {
  showModal.value = false;
};
</script>

<template>
  <template v-if="schedulesEnabled">
    <Button
      v-tooltip.bottom="t('DISPARADOR.SCHEDULES.MENU_ACTION')"
      sm
      ghost
      slate
      icon="i-lucide-calendar-clock"
      class="rounded-md"
      @click="open"
    />
    <ScheduleConversationModal
      :show="showModal"
      :conversation="conversation"
      @close="close"
    />
  </template>
</template>
