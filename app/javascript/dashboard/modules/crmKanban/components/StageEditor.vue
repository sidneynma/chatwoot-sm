<script setup>
import { computed, ref, watch } from 'vue';
import Draggable from 'vuedraggable';
import { useMapGetter } from 'dashboard/composables/store';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue']);

const labels = useMapGetter('labels/getLabels');

const selectedLabelId = ref(null);
const localStages = ref([]);

const availableLabels = computed(() => {
  const usedIds = new Set(localStages.value.map(stage => stage.label_id));
  return labels.value
    .filter(label => !usedIds.has(label.id))
    .map(label => ({
      value: label.id,
      label: label.title,
    }));
});

const syncFromProps = () => {
  localStages.value = props.modelValue.map(stage => ({ ...stage }));
};

const emitUpdate = () => {
  emit(
    'update:modelValue',
    localStages.value.map((stage, index) => ({
      label_id: stage.label_id,
      position: index,
      label: stage.label,
    }))
  );
};

const addStage = () => {
  if (!selectedLabelId.value) return;

  const label = labels.value.find(item => item.id === selectedLabelId.value);
  if (!label) return;

  localStages.value.push({
    label_id: label.id,
    label: {
      id: label.id,
      title: label.title,
      color: label.color,
    },
  });
  selectedLabelId.value = null;
  emitUpdate();
};

const removeStage = index => {
  localStages.value.splice(index, 1);
  emitUpdate();
};

const onDragEnd = () => {
  emitUpdate();
};

watch(() => props.modelValue, syncFromProps, { immediate: true, deep: true });
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex items-end gap-2">
      <div class="flex-1">
        <label class="block mb-1 text-sm text-n-slate-11">
          {{ $t('CRM_KANBAN.SETTINGS.ADD_STAGE') }}
        </label>
        <ComboBox
          v-model="selectedLabelId"
          :options="availableLabels"
          :placeholder="$t('CRM_KANBAN.SETTINGS.ADD_STAGE_PLACEHOLDER')"
        />
      </div>
      <button
        type="button"
        class="px-3 py-2 text-sm font-medium text-n-brand border border-n-brand rounded-lg hover:bg-n-alpha-2"
        :disabled="!selectedLabelId"
        @click="addStage"
      >
        {{ $t('CRM_KANBAN.ACTIONS.ADD') }}
      </button>
    </div>

    <div
      v-if="localStages.length === 0"
      class="py-6 text-sm text-center text-n-slate-11"
    >
      {{ $t('CRM_KANBAN.SETTINGS.NO_STAGES') }}
    </div>

    <Draggable
      v-else
      v-model="localStages"
      item-key="label_id"
      class="flex flex-col gap-2"
      @end="onDragEnd"
    >
      <template #item="{ element, index }">
        <div
          class="flex items-center gap-3 p-3 border rounded-lg border-n-weak bg-n-solid-1"
        >
          <Icon
            icon="i-woot-drag-indicator"
            class="size-4 text-n-slate-11 cursor-move shrink-0"
          />
          <span
            class="size-3 rounded-sm shrink-0"
            :style="{ backgroundColor: element.label?.color }"
          />
          <span class="flex-1 text-sm capitalize text-n-slate-12">
            {{ element.label?.title }}
          </span>
          <button
            type="button"
            class="text-n-slate-11 hover:text-n-ruby-11"
            @click="removeStage(index)"
          >
            <Icon icon="i-lucide-trash-2" class="size-4" />
          </button>
        </div>
      </template>
    </Draggable>
  </div>
</template>
