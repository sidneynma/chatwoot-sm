<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import MessageBubble from './MessageBubble.vue';
import Composer from './Composer.vue';

const props = defineProps({
  room: { type: Object, default: null },
  messages: { type: Array, default: () => [] },
  isAdmin: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
  hasMore: { type: Boolean, default: false },
});

const emit = defineEmits([
  'send',
  'load-more',
  'edit-group',
  'delete-group',
  'close',
]);

const { t } = useI18n();
const scroller = ref(null);

const canSend = computed(() => props.room?.can_send !== false);
const peerInactive = computed(() => Boolean(props.room?.peer_inactive));

const roomMeta = computed(() => {
  if (!props.room) return '';
  const parts = [
    props.room.room_type === 'group'
      ? t('INTERNAL_CHAT.GROUP')
      : t('INTERNAL_CHAT.DIRECT'),
  ];
  if (props.room.members?.length) {
    parts.push(String(props.room.members.length));
  }
  if (peerInactive.value) {
    parts.push(t('INTERNAL_CHAT.AGENT_INACTIVE_LABEL'));
  }
  return parts.join(' · ');
});

const scrollToBottom = async () => {
  await nextTick();
  if (!scroller.value) return;
  scroller.value.scrollTop = scroller.value.scrollHeight;
};

watch(
  () => props.messages.length,
  () => scrollToBottom()
);

onMounted(scrollToBottom);
</script>

<template>
  <section class="flex h-full min-h-0 min-w-0 flex-1 flex-col bg-n-background">
    <header
      v-if="room"
      class="flex items-center justify-between border-b border-n-weak px-4 py-3"
    >
      <div>
        <h2 class="text-base font-medium text-n-slate-12">{{ room.name }}</h2>
        <p class="text-xs text-n-slate-11">{{ roomMeta }}</p>
      </div>
      <div class="flex items-center gap-2">
        <template v-if="isAdmin && room.room_type === 'group'">
          <Button
            :label="t('INTERNAL_CHAT.EDIT_GROUP')"
            size="sm"
            variant="ghost"
            @click="emit('edit-group')"
          />
          <Button
            :label="t('INTERNAL_CHAT.DELETE_GROUP')"
            size="sm"
            color="ruby"
            variant="ghost"
            @click="emit('delete-group')"
          />
        </template>
        <Button
          v-tooltip.top="t('INTERNAL_CHAT.CLOSE')"
          icon="i-lucide-x"
          size="sm"
          variant="ghost"
          :aria-label="t('INTERNAL_CHAT.CLOSE')"
          @click="emit('close')"
        />
      </div>
    </header>

    <div ref="scroller" class="flex-1 overflow-y-auto px-4 py-4">
      <div v-if="hasMore" class="mb-4 flex justify-center">
        <Button
          :label="t('INTERNAL_CHAT.LOAD_MORE')"
          size="sm"
          variant="faded"
          :is-loading="loading"
          @click="emit('load-more')"
        />
      </div>
      <p
        v-if="!messages.length && !loading"
        class="py-16 text-center text-sm text-n-slate-11"
      >
        {{ t('INTERNAL_CHAT.EMPTY_MESSAGES') }}
      </p>
      <MessageBubble
        v-for="message in messages"
        :key="message.id"
        :message="message"
      />
    </div>

    <div
      v-if="room && peerInactive"
      class="border-t border-n-weak bg-n-alpha-2 px-4 py-3 text-center text-sm text-n-slate-11"
    >
      {{ t('INTERNAL_CHAT.AGENT_INACTIVE') }}
    </div>
    <Composer
      v-else-if="room && canSend"
      @send="payload => emit('send', payload)"
    />
  </section>
</template>
