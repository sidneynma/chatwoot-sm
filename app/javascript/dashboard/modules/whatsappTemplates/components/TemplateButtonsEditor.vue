<script setup>
import { computed, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  buttons: {
    type: Array,
    default: () => [],
  },
  errors: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update:buttons']);

const QUICK_REPLY_LIMIT = 3;
const CTA_LIMIT = 2;

const { t } = useI18n();

const buttonsList = computed({
  get: () => props.buttons,
  set: value => emit('update:buttons', value),
});

const isQuickReplyMode = computed(() =>
  buttonsList.value.some(button => button.type === 'QUICK_REPLY')
);

const isCtaMode = computed(() =>
  buttonsList.value.some(button =>
    ['URL', 'PHONE_NUMBER'].includes(button.type)
  )
);

const addButtonOptions = computed(() => {
  if (!buttonsList.value.length) {
    return [
      {
        type: 'QUICK_REPLY',
        icon: 'i-lucide-reply',
        label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_QUICK_REPLY'),
      },
      {
        type: 'URL',
        icon: 'i-lucide-external-link',
        label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_URL'),
      },
      {
        type: 'PHONE_NUMBER',
        icon: 'i-lucide-phone',
        label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_PHONE'),
      },
    ];
  }

  if (isQuickReplyMode.value) {
    if (buttonsList.value.length >= QUICK_REPLY_LIMIT) return [];

    return [
      {
        type: 'QUICK_REPLY',
        icon: 'i-lucide-reply',
        label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_QUICK_REPLY'),
      },
    ];
  }

  if (isCtaMode.value) {
    if (buttonsList.value.length >= CTA_LIMIT) return [];

    const options = [
      {
        type: 'URL',
        icon: 'i-lucide-external-link',
        label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_URL'),
      },
    ];

    if (!buttonsList.value.some(button => button.type === 'PHONE_NUMBER')) {
      options.push({
        type: 'PHONE_NUMBER',
        icon: 'i-lucide-phone',
        label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_PHONE'),
      });
    }

    return options;
  }

  return [];
});

const canAddButton = computed(() => addButtonOptions.value.length > 0);

const createButton = type => {
  if (type === 'QUICK_REPLY') {
    return { type: 'QUICK_REPLY', text: '' };
  }

  return {
    type,
    text: '',
    url: '',
    phone_number: '',
    url_example: '',
  };
};

const scrollToButton = async index => {
  await nextTick();
  document
    .getElementById(`template-button-${index}`)
    ?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
};

const addButton = async type => {
  const nextIndex = buttonsList.value.length;
  buttonsList.value = [...buttonsList.value, createButton(type)];
  await scrollToButton(nextIndex);
};

const removeButton = index => {
  buttonsList.value = buttonsList.value.filter((_, i) => i !== index);
};

const updateButton = (index, patch) => {
  buttonsList.value = buttonsList.value.map((button, i) =>
    i === index ? { ...button, ...patch } : button
  );
};

const buttonTypeLabel = type => {
  const labels = {
    QUICK_REPLY: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_QUICK_REPLY'),
    URL: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_URL'),
    PHONE_NUMBER: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.TYPE_PHONE'),
  };

  return labels[type] || type;
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

    <div v-if="buttonsList.length" class="flex flex-col gap-3">
      <div
        v-for="(button, index) in buttonsList"
        :id="`template-button-${index}`"
        :key="`${button.type}-${index}`"
        class="flex flex-col gap-2 p-3 rounded-lg border border-n-weak"
      >
        <div class="flex items-center justify-between gap-2">
          <p class="text-xs font-medium text-n-slate-12">
            {{
              t(
                'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.ITEM_LABEL_WITH_TYPE',
                {
                  index: index + 1,
                  type: buttonTypeLabel(button.type),
                }
              )
            }}
          </p>
          <Button
            type="button"
            size="xs"
            variant="ghost"
            color="ruby"
            icon="i-lucide-trash-2"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.REMOVE')"
            @click="removeButton(index)"
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
            t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.URL_EXAMPLE_PLACEHOLDER')
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
      </div>
    </div>

    <div v-if="errors.buttons" class="text-sm text-n-ruby-9">
      {{ errors.buttons }}
    </div>

    <div v-if="canAddButton" class="flex flex-col gap-2">
      <p v-if="buttonsList.length" class="text-xs font-medium text-n-slate-11">
        {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.ADD') }}
      </p>

      <div class="flex flex-col gap-1">
        <button
          v-for="option in addButtonOptions"
          :key="option.type"
          type="button"
          class="flex items-center w-full gap-2 px-3 py-2 text-sm text-left transition-colors rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-2"
          @click="addButton(option.type)"
        >
          <Icon :icon="option.icon" class="size-4 shrink-0 text-n-slate-11" />
          {{ option.label }}
        </button>
      </div>
    </div>
  </div>
</template>
