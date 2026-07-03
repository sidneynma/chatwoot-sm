<script setup>
import Draggable from 'vuedraggable';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  stage: {
    type: Object,
    required: true,
  },
  isMoving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['cardChange', 'openConversation']);

const onChange = event => {
  emit('cardChange', { event, stage: props.stage });
};

const openConversation = conversation => {
  emit('openConversation', conversation);
};
</script>

<template>
  <div class="flex flex-col w-72 shrink-0 h-full">
    <div
      class="flex items-center justify-between gap-2 px-3 py-2 mb-2 rounded-lg bg-n-alpha-2"
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

    <Draggable
      :list="stage.conversations"
      :group="{ name: 'crm-kanban', pull: !isMoving, put: !isMoving }"
      item-key="id"
      class="flex flex-col gap-2 flex-1 min-h-32 p-2 rounded-xl bg-n-slate-2 border border-n-weak"
      :disabled="isMoving"
      @change="onChange"
    >
      <template #item="{ element }">
        <KanbanCard :conversation="element" @open="openConversation" />
      </template>
    </Draggable>
  </div>
</template>
