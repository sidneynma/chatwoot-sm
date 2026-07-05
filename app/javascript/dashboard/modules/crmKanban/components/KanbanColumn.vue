<script setup>
import { ref } from 'vue';
import Draggable from 'vuedraggable';
import KanbanCard from './KanbanCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  stage: {
    type: Object,
    required: true,
  },
  isMoving: {
    type: Boolean,
    default: false,
  },
  isLoadingMore: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['cardChange', 'openConversation', 'loadMore']);

const scrollContainer = ref(null);

const onChange = event => {
  emit('cardChange', { event, stage: props.stage });
};

const openConversation = conversation => {
  emit('openConversation', conversation);
};

const onScroll = () => {
  if (props.isLoadingMore || !props.stage.has_more) return;

  const container = scrollContainer.value;
  if (!container) return;

  const { scrollTop, scrollHeight, clientHeight } = container;
  if (scrollTop + clientHeight >= scrollHeight - 80) {
    emit('loadMore', props.stage);
  }
};
</script>

<template>
  <div class="flex flex-col w-72 shrink-0 h-full min-h-0">
    <div
      class="flex items-center justify-between gap-2 px-3 py-2 mb-2 rounded-lg bg-n-alpha-2 shrink-0"
    >
      <div class="flex items-center gap-2 min-w-0">
        <span
          class="size-2.5 shrink-0 rounded-sm"
          :style="{ backgroundColor: stage.label.color }"
        />
        <h3 class="text-sm font-medium text-n-slate-12 truncate capitalize">
          {{ stage.label.title }}
        </h3>
      </div>
      <span class="text-xs text-n-slate-11 shrink-0">
        {{ stage.total_count }}
      </span>
    </div>

    <div
      ref="scrollContainer"
      class="flex-1 min-h-0 overflow-y-auto rounded-xl bg-n-slate-2 border border-n-weak"
      @scroll="onScroll"
    >
      <Draggable
        :list="stage.conversations"
        :group="{ name: 'crm-kanban', pull: !isMoving, put: !isMoving }"
        item-key="id"
        class="flex flex-col gap-2 min-h-full p-2"
        :disabled="isMoving"
        @change="onChange"
      >
        <template #item="{ element }">
          <KanbanCard :conversation="element" @open="openConversation" />
        </template>
      </Draggable>

      <div v-if="isLoadingMore" class="flex items-center justify-center py-3">
        <Spinner :size="16" />
      </div>
    </div>
  </div>
</template>
