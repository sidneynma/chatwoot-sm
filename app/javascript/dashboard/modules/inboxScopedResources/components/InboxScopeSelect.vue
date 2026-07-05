<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  modelValue: {
    type: [Number, String, null],
    default: null,
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const inboxes = useMapGetter('inboxes/getInboxes');

const selectedInboxId = computed({
  get: () => props.modelValue ?? '',
  set: value => {
    emit('update:modelValue', value === '' ? null : Number(value));
  },
});

const inboxOptions = computed(() => [
  {
    value: '',
    label: t('INBOX_SCOPED_RESOURCES.ALL_INBOXES'),
  },
  ...inboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  })),
]);
</script>

<template>
  <div class="w-full">
    <label class="block mb-1 text-sm font-medium text-n-slate-12">
      {{ $t('INBOX_SCOPED_RESOURCES.INBOX.LABEL') }}
    </label>
    <ComboBox
      v-model="selectedInboxId"
      :options="inboxOptions"
      :placeholder="$t('INBOX_SCOPED_RESOURCES.INBOX.PLACEHOLDER')"
    />
    <p class="mt-1 text-xs text-n-slate-11">
      {{ $t('INBOX_SCOPED_RESOURCES.INBOX.HELP') }}
    </p>
  </div>
</template>
