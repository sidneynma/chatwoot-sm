<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  groupType: {
    type: String,
    default: 'NONE',
  },
  buttons: {
    type: Array,
    default: () => [],
  },
  errors: {
    type: Object,
    default: () => ({}),
  },
});
const emit = defineEmits(['update:groupType', 'update:buttons']);
const QUICK_REPLY_LIMIT = 3;
const CTA_LIMIT = 2;

const { t } = useI18n();

const groupTypeModel = computed({
  get: () => props.groupType,
  set: value => emit('update:groupType', value),
});

const buttonsModel = computed({
  get: () => props.buttons,
  set: value => emit('update:buttons', value),
});

const groupTypeOptions = computed(() => [
  {
    value: 'NONE',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.GROUP_NONE'),
  },
  {
    value: 'QUICK_REPLY',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.GROUP_QUICK_REPLY'),
  },
  {
    value: 'CALL_TO_ACTION',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.GROUP_CALL_TO_ACTION'),
  },
]);

const ctaTypeOptions = computed(() => [
  {
    value: 'URL',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_URL'),
  },
  {
    value: 'PHONE_NUMBER',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_PHONE'),
  },
]);

const getCtaTypeOptions = index => {
  const hasOtherPhone = buttonsModel.value.some(
    (button, buttonIndex) =>
      buttonIndex !== index && button.type === 'PHONE_NUMBER'
  );

  if (!hasOtherPhone) return ctaTypeOptions.value;

  return ctaTypeOptions.value.filter(option => option.value !== 'PHONE_NUMBER');
};

const showButtons = computed(() => groupTypeModel.value !== 'NONE');

const canAddButton = computed(() => {
  if (groupTypeModel.value === 'QUICK_REPLY') {
    return buttonsModel.value.length < QUICK_REPLY_LIMIT;
  }
  if (groupTypeModel.value === 'CALL_TO_ACTION') {
    return buttonsModel.value.length < CTA_LIMIT;
  }
  return false;
});

const createQuickReplyButton = () => ({
  type: 'QUICK_REPLY',
  text: '',
});

const createCtaButton = type => ({
  type,
  text: '',
  url: '',
  phone_number: '',
  url_example: '',
});

const onGroupTypeChange = value => {
  if (value === 'QUICK_REPLY') {
    buttonsModel.value = [createQuickReplyButton()];
  } else if (value === 'CALL_TO_ACTION') {
    buttonsModel.value = [createCtaButton('URL')];
  } else {
    buttonsModel.value = [];
  }
};

watch(groupTypeModel, (value, oldValue) => {
  if (value === oldValue) return;
  onGroupTypeChange(value);
});

const addButton = () => {
  if (!canAddButton.value) return;

  if (groupTypeModel.value === 'QUICK_REPLY') {
    buttonsModel.value = [...buttonsModel.value, createQuickReplyButton()];
    return;
  }

  const hasPhone = buttonsModel.value.some(
    button => button.type === 'PHONE_NUMBER'
  );
  buttonsModel.value = [
    ...buttonsModel.value,
    createCtaButton(hasPhone ? 'URL' : 'URL'),
  ];
};

const removeButton = index => {
  buttonsModel.value = buttonsModel.value.filter((_, i) => i !== index);
};

const updateButton = (index, patch) => {
  buttonsModel.value = buttonsModel.value.map((button, i) =>
    i === index ? { ...button, ...patch } : button
  );
};

const urlHasVariable = url => /\{\{[^}]+\}\}/.test(url || '');
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 rounded-xl border border-n-weak bg-n-surface-1"
  >
    <p class="text-xs font-medium text-n-slate-12">
      {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.SECTION_TITLE') }}
    </p>
    <p class="text-xs text-n-slate-11">
      {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.SECTION_HINT') }}
    </p>

    <div class="flex flex-col gap-1">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.GROUP_LABEL') }}
      </label>
      <ComboBox
        v-model="groupTypeModel"
        :options="groupTypeOptions"
        class="w-full"
      />
    </div>

    <div v-if="showButtons" class="flex flex-col gap-3">
      <div
        v-for="(button, index) in buttonsModel"
        :key="index"
        class="flex flex-col gap-2 p-3 rounded-lg border border-n-weak"
      >
        <div class="flex items-center justify-between gap-2">
          <p class="text-xs font-medium text-n-slate-12">
            {{
              t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.ITEM_LABEL', {
                index: index + 1,
              })
            }}
          </p>
          <Button
            v-if="buttonsModel.length > 1"
            type="button"
            size="xs"
            variant="ghost"
            color="ruby"
            icon="i-lucide-trash-2"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.REMOVE')"
            @click="removeButton(index)"
          />
        </div>

        <template v-if="groupTypeModel === 'QUICK_REPLY'">
          <Input
            :model-value="button.text"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TEXT_LABEL')"
            :placeholder="
              t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TEXT_PLACEHOLDER')
            "
            :message="errors[`button_${index}_text`]"
            :message-type="errors[`button_${index}_text`] ? 'error' : 'info'"
            @update:model-value="value => updateButton(index, { text: value })"
          />
        </template>

        <template v-else>
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_LABEL') }}
            </label>
            <Select
              :model-value="button.type"
              :options="getCtaTypeOptions(index)"
              class="!w-full"
              @update:model-value="
                value =>
                  updateButton(index, {
                    type: value,
                    url: '',
                    phone_number: '',
                    url_example: '',
                  })
              "
            />
          </div>

          <Input
            :model-value="button.text"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TEXT_LABEL')"
            :placeholder="
              t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TEXT_PLACEHOLDER')
            "
            :message="errors[`button_${index}_text`]"
            :message-type="errors[`button_${index}_text`] ? 'error' : 'info'"
            @update:model-value="value => updateButton(index, { text: value })"
          />

          <Input
            v-if="button.type === 'URL'"
            :model-value="button.url"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.URL_LABEL')"
            :placeholder="
              t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.URL_PLACEHOLDER')
            "
            :message="errors[`button_${index}_url`]"
            :message-type="errors[`button_${index}_url`] ? 'error' : 'info'"
            @update:model-value="value => updateButton(index, { url: value })"
          />

          <Input
            v-if="button.type === 'URL' && urlHasVariable(button.url)"
            :model-value="button.url_example"
            :label="
              t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.URL_EXAMPLE_LABEL')
            "
            :placeholder="
              t(
                'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.URL_EXAMPLE_PLACEHOLDER'
              )
            "
            :message="errors[`button_${index}_url_example`]"
            :message-type="
              errors[`button_${index}_url_example`] ? 'error' : 'info'
            "
            @update:model-value="
              value => updateButton(index, { url_example: value })
            "
          />

          <Input
            v-if="button.type === 'PHONE_NUMBER'"
            :model-value="button.phone_number"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.PHONE_LABEL')"
            :placeholder="
              t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.PHONE_PLACEHOLDER')
            "
            :message="errors[`button_${index}_phone`]"
            :message-type="errors[`button_${index}_phone`] ? 'error' : 'info'"
            @update:model-value="
              value => updateButton(index, { phone_number: value })
            "
          />
        </template>
      </div>

      <Button
        v-if="canAddButton"
        type="button"
        size="sm"
        variant="outline"
        color="slate"
        icon="i-lucide-plus"
        :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.ADD')"
        @click="addButton"
      />

      <span v-if="errors.buttons" class="text-sm text-n-ruby-9">
        {{ errors.buttons }}
      </span>
    </div>
  </div>
</template>
