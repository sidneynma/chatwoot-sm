<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  room: { type: Object, default: null },
});

const emit = defineEmits(['save']);
const { t } = useI18n();
const dialogRef = ref(null);
const agents = useMapGetter('agents/getAgents');
const currentUserId = useMapGetter('getCurrentUserID');

const name = ref('');
const selectedIds = ref([]);

const isEdit = computed(() => Boolean(props.room?.id));
const selectableAgents = computed(() =>
  agents.value.filter(agent => agent.id !== currentUserId.value)
);

const resetForm = () => {
  name.value = props.room?.name || '';
  selectedIds.value = (props.room?.members || [])
    .map(member => member.id)
    .filter(id => id !== currentUserId.value);
};

watch(
  () => props.room,
  () => resetForm()
);

const open = () => {
  resetForm();
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
};

const toggleMember = id => {
  if (selectedIds.value.includes(id)) {
    selectedIds.value = selectedIds.value.filter(item => item !== id);
  } else {
    selectedIds.value = [...selectedIds.value, id];
  }
};

const save = () => {
  emit('save', {
    name: name.value.trim(),
    memberIds: [...selectedIds.value, currentUserId.value],
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="lg"
    :title="
      isEdit ? t('INTERNAL_CHAT.EDIT_GROUP') : t('INTERNAL_CHAT.NEW_GROUP')
    "
    :show-confirm-button="false"
    :show-cancel-button="false"
  >
    <div class="flex flex-col gap-4">
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('INTERNAL_CHAT.GROUP_NAME') }}
        <input
          v-model="name"
          type="text"
          class="rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 outline-none focus:border-n-brand"
        />
      </label>

      <div>
        <p class="mb-2 text-sm text-n-slate-12">
          {{ t('INTERNAL_CHAT.SELECT_AGENTS') }}
        </p>
        <div
          class="max-h-64 space-y-1 overflow-y-auto rounded-lg border border-n-weak p-2"
        >
          <label
            v-for="agent in selectableAgents"
            :key="agent.id"
            class="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 hover:bg-n-alpha-2"
          >
            <input
              type="checkbox"
              :checked="selectedIds.includes(agent.id)"
              @change="toggleMember(agent.id)"
            />
            <span class="text-sm text-n-slate-12">{{
              agent.available_name || agent.name
            }}</span>
          </label>
          <p
            v-if="!selectableAgents.length"
            class="px-2 py-4 text-center text-sm text-n-slate-11"
          >
            {{ t('INTERNAL_CHAT.NO_AGENTS') }}
          </p>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          :label="t('INTERNAL_CHAT.CANCEL')"
          variant="ghost"
          @click="close"
        />
        <Button
          :label="isEdit ? t('INTERNAL_CHAT.SAVE') : t('INTERNAL_CHAT.CREATE')"
          color="blue"
          :disabled="!name.trim()"
          @click="save"
        />
      </div>
    </template>
  </Dialog>
</template>
