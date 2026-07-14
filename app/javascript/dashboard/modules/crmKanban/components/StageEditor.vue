<script setup>
import { computed, ref, watch } from 'vue';
import Draggable from 'vuedraggable';
import { useMapGetter } from 'dashboard/composables/store';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue']);

const labels = useMapGetter('labels/getLabels');
const teams = useMapGetter('teams/getTeams');

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

const teamOptions = computed(() =>
  teams.value.map(team => ({
    value: team.id,
    label: team.name,
  }))
);

const syncFromProps = () => {
  localStages.value = props.modelValue.map(stage => ({
    label_id: stage.label_id,
    label: stage.label,
    responsible_team_id: stage.responsible_team_id || '',
    can_resolve: Boolean(stage.can_resolve),
    auto_resolve_on_enter: Boolean(stage.auto_resolve_on_enter),
    clear_assignment_on_resolve: Boolean(stage.clear_assignment_on_resolve),
  }));
};

const emitUpdate = () => {
  emit(
    'update:modelValue',
    localStages.value.map((stage, index) => ({
      label_id: stage.label_id,
      position: index,
      label: stage.label,
      responsible_team_id: stage.responsible_team_id
        ? Number(stage.responsible_team_id)
        : null,
      can_resolve: Boolean(stage.can_resolve),
      auto_resolve_on_enter: Boolean(stage.auto_resolve_on_enter),
      clear_assignment_on_resolve: Boolean(stage.clear_assignment_on_resolve),
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
    responsible_team_id: '',
    can_resolve: false,
    auto_resolve_on_enter: false,
    clear_assignment_on_resolve: false,
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
  <div class="flex flex-col gap-2">
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
      class="flex flex-col gap-1.5 min-h-0 max-h-56 overflow-y-auto rounded-lg border border-n-weak bg-n-alpha-2 p-1.5"
    >
      <div
        v-if="localStages.length === 0"
        class="py-4 text-sm text-center text-n-slate-11"
      >
        {{ $t('CRM_KANBAN.SETTINGS.NO_STAGES') }}
      </div>

      <Draggable
        v-else
        v-model="localStages"
        item-key="label_id"
        class="flex flex-col gap-1.5"
        @end="onDragEnd"
      >
        <template #item="{ element, index }">
          <div
            class="flex flex-col gap-2 p-2 border rounded-lg border-n-weak bg-n-solid-1"
          >
            <div class="flex items-center gap-2">
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

            <div class="pl-6 flex flex-col gap-1.5">
              <div>
                <label class="block mb-0.5 text-xs text-n-slate-11">
                  {{ $t('CRM_KANBAN.SETTINGS.STAGE.TEAM') }}
                </label>
                <!-- Native select: avoids ComboBox being clipped by overflow-y-auto -->
                <select
                  v-model="element.responsible_team_id"
                  class="w-full appearance-none rounded-lg border-0 outline-1 outline -outline-offset-1 outline-n-weak hover:outline-n-slate-6 focus:outline-n-blue-9 bg-n-surface-1 py-1.5 px-2.5 text-sm text-n-slate-12 capitalize"
                  @change="emitUpdate"
                >
                  <option value="">
                    {{ $t('CRM_KANBAN.SETTINGS.STAGE.TEAM_PLACEHOLDER') }}
                  </option>
                  <option
                    v-for="team in teamOptions"
                    :key="team.value"
                    :value="team.value"
                  >
                    {{ team.label }}
                  </option>
                </select>
                <p
                  v-if="teamOptions.length === 0"
                  class="mt-0.5 text-xs text-n-slate-11"
                >
                  {{ $t('CRM_KANBAN.SETTINGS.STAGE.NO_TEAMS') }}
                </p>
              </div>

              <label class="flex items-center gap-2 cursor-pointer">
                <Checkbox
                  v-model="element.can_resolve"
                  @update:model-value="emitUpdate"
                />
                <span class="text-sm text-n-slate-12">
                  {{ $t('CRM_KANBAN.SETTINGS.STAGE.CAN_RESOLVE') }}
                </span>
              </label>

              <label class="flex items-center gap-2 cursor-pointer">
                <Checkbox
                  v-model="element.auto_resolve_on_enter"
                  @update:model-value="emitUpdate"
                />
                <span class="text-sm text-n-slate-12">
                  {{ $t('CRM_KANBAN.SETTINGS.STAGE.AUTO_RESOLVE') }}
                </span>
              </label>

              <label class="flex items-center gap-2 cursor-pointer">
                <Checkbox
                  v-model="element.clear_assignment_on_resolve"
                  @update:model-value="emitUpdate"
                />
                <span class="text-sm text-n-slate-12">
                  {{ $t('CRM_KANBAN.SETTINGS.STAGE.CLEAR_ASSIGNMENT') }}
                </span>
              </label>
            </div>
          </div>
        </template>
      </Draggable>
    </div>
  </div>
</template>
