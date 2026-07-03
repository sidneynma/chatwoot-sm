<script setup>
import { computed } from 'vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { dynamicTime } from 'shared/helpers/timeHelper';

const props = defineProps({
  conversation: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['open']);

const contactName = computed(
  () =>
    props.conversation.contact?.name ||
    props.conversation.contact?.email ||
    props.conversation.contact?.phone_number ||
    '—'
);

const assigneeName = computed(() => props.conversation.assignee?.name);

const lastMessagePreview = computed(() => {
  const content = props.conversation.last_message?.content;
  if (!content) return '';
  return content.length > 80 ? `${content.slice(0, 80)}…` : content;
});

const openConversation = () => {
  emit('open', props.conversation);
};
</script>

<template>
  <button
    type="button"
    class="flex flex-col gap-2 w-full p-3 text-left bg-n-solid-1 border border-n-weak rounded-xl hover:border-n-brand transition-colors cursor-pointer"
    @click="openConversation"
  >
    <div class="flex items-start justify-between gap-2">
      <div class="flex items-center gap-2 min-w-0">
        <Avatar
          :name="contactName"
          :src="conversation.contact?.thumbnail"
          :size="24"
        />
        <span class="text-sm font-medium text-n-slate-12 truncate">
          {{ contactName }}
        </span>
      </div>
      <span
        v-if="conversation.unread_count"
        class="shrink-0 min-w-5 h-5 px-1.5 flex items-center justify-center text-xs font-medium text-n-slate-1 bg-n-brand rounded-full"
      >
        {{ conversation.unread_count }}
      </span>
    </div>

    <p v-if="lastMessagePreview" class="text-xs text-n-slate-11 line-clamp-2">
      {{ lastMessagePreview }}
    </p>

    <div
      class="flex items-center justify-between gap-2 text-xs text-n-slate-11"
    >
      <div v-if="assigneeName" class="flex items-center gap-1 min-w-0">
        <Avatar
          :name="assigneeName"
          :src="conversation.assignee?.thumbnail"
          :size="16"
        />
        <span class="truncate">{{ assigneeName }}</span>
      </div>
      <span v-else class="italic">{{ $t('CRM_KANBAN.BOARD.UNASSIGNED') }}</span>
      <span v-if="conversation.timestamp" class="shrink-0">
        {{ dynamicTime(conversation.timestamp) }}
      </span>
    </div>
  </button>
</template>
