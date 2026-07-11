<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  message: { type: Object, required: true },
});

const currentUserId = useMapGetter('getCurrentUserID');
const isMine = computed(() => props.message.sender?.id === currentUserId.value);

const timeLabel = computed(() => {
  if (!props.message.created_at) return '';
  return new Date(props.message.created_at * 1000).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  });
});
</script>

<template>
  <div
    class="mb-3 flex gap-2"
    :class="isMine ? 'flex-row-reverse' : 'flex-row'"
  >
    <Avatar
      v-if="!isMine"
      :name="message.sender?.name"
      :src="message.sender?.thumbnail"
      :size="28"
      rounded-full
    />
    <div
      class="max-w-[75%] rounded-xl px-3 py-2"
      :class="
        isMine
          ? 'rounded-br-sm bg-n-solid-blue text-n-slate-12'
          : 'rounded-bl-sm bg-n-slate-4 text-n-slate-12'
      "
    >
      <div v-if="!isMine" class="mb-1 text-xs font-medium text-n-slate-11">
        {{ message.sender?.name }}
      </div>
      <p v-if="message.content" class="whitespace-pre-wrap break-words text-sm">
        {{ message.content }}
      </p>
      <div
        v-for="attachment in message.attachments || []"
        :key="attachment.id"
        class="mt-2"
      >
        <img
          v-if="attachment.file_type === 'image'"
          :src="attachment.data_url"
          :alt="attachment.file_name"
          class="max-h-64 rounded-lg"
        />
        <audio
          v-else-if="attachment.file_type === 'audio'"
          :src="attachment.data_url"
          controls
          class="w-56"
        />
        <a
          v-else
          :href="attachment.data_url"
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex items-center gap-2 rounded-lg bg-n-alpha-2 px-3 py-2 text-sm underline"
        >
          <span class="i-lucide-file size-4" />
          {{ attachment.file_name }}
        </a>
      </div>
      <div class="mt-1 text-right text-[10px] text-n-slate-11">
        {{ timeLabel }}
      </div>
    </div>
  </div>
</template>
