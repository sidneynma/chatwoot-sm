<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

defineProps({
  isCreating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);

const NAME_REGEX = /^[a-z0-9_]+$/;

const form = ref({
  name: '',
  category: 'UTILITY',
  language: 'pt_BR',
  header_text: '',
  body_text: '',
  footer_text: '',
});

const exampleValues = ref({});
const errors = ref({});

const categoryOptions = computed(() => [
  { value: 'UTILITY', label: t('WHATSAPP_TEMPLATES.ADMIN.CATEGORY.UTILITY') },
  {
    value: 'MARKETING',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CATEGORY.MARKETING'),
  },
  {
    value: 'AUTHENTICATION',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CATEGORY.AUTHENTICATION'),
  },
]);

const languageOptions = [
  { value: 'pt_BR', label: 'Português (BR)' },
  { value: 'en', label: 'English' },
  { value: 'en_US', label: 'English (US)' },
  { value: 'es', label: 'Español' },
  { value: 'es_ES', label: 'Español (ES)' },
  { value: 'es_MX', label: 'Español (MX)' },
];

const bodyVariables = computed(() => {
  const matches = form.value.body_text.match(/\{\{(\d+)\}\}/g) || [];
  return [...new Set(matches.map(match => match.replace(/[{}]/g, '')))].sort(
    (a, b) => Number(a) - Number(b)
  );
});

const resetForm = () => {
  form.value = {
    name: '',
    category: 'UTILITY',
    language: 'pt_BR',
    header_text: '',
    body_text: '',
    footer_text: '',
  };
  exampleValues.value = {};
  errors.value = {};
};

const validate = () => {
  errors.value = {};

  if (!form.value.name.trim()) {
    errors.value.name = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.NAME_REQUIRED'
    );
  } else if (!NAME_REGEX.test(form.value.name.trim())) {
    errors.value.name = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.NAME_FORMAT'
    );
  }

  if (!form.value.body_text.trim()) {
    errors.value.body = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.BODY_REQUIRED'
    );
  }

  const missingExample = bodyVariables.value.some(
    variable => !exampleValues.value[variable]?.trim()
  );
  if (missingExample) {
    errors.value.examples = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.EXAMPLES_REQUIRED'
    );
  }

  return Object.keys(errors.value).length === 0;
};

const handleSubmit = () => {
  if (!validate()) return;

  const payload = {
    name: form.value.name.trim(),
    category: form.value.category,
    language: form.value.language,
    header_text: form.value.header_text.trim(),
    body_text: form.value.body_text.trim(),
    footer_text: form.value.footer_text.trim(),
    body_examples: bodyVariables.value.map(
      variable => exampleValues.value[variable]?.trim() || ''
    ),
  };

  emit('submit', payload);
};

const open = () => {
  resetForm();
  nextTick(() => dialogRef.value?.open());
};

const close = () => {
  dialogRef.value?.close();
};

defineExpose({ dialogRef, open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="2xl"
    overflow-y-auto
    :title="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.TITLE')"
    :description="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.DESCRIPTION')"
    :confirm-button-label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.SUBMIT')"
    :cancel-button-label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.CANCEL')"
    :is-loading="isCreating"
    :disable-confirm-button="isCreating"
    @confirm="handleSubmit"
    @close="resetForm"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="form.name"
        :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.NAME_LABEL')"
        :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.NAME_PLACEHOLDER')"
        :message="errors.name || t('WHATSAPP_TEMPLATES.ADMIN.CREATE.NAME_HINT')"
        :message-type="errors.name ? 'error' : 'info'"
      />

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.CATEGORY_LABEL') }}
          </label>
          <Select
            v-model="form.category"
            :options="categoryOptions"
            class="!w-full"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.LANGUAGE_LABEL') }}
          </label>
          <Select
            v-model="form.language"
            :options="languageOptions"
            class="!w-full"
          />
        </div>
      </div>

      <Input
        v-model="form.header_text"
        :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_LABEL')"
        :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_PLACEHOLDER')"
      />

      <TextArea
        v-model="form.body_text"
        :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BODY_LABEL')"
        :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BODY_PLACEHOLDER')"
        :max-length="1024"
        :message="errors.body || t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BODY_HINT')"
        :message-type="errors.body ? 'error' : 'info'"
        auto-height
      />

      <Input
        v-model="form.footer_text"
        :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.FOOTER_LABEL')"
        :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.FOOTER_PLACEHOLDER')"
      />

      <div v-if="bodyVariables.length" class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.EXAMPLES_TITLE') }}
        </label>
        <Input
          v-for="variable in bodyVariables"
          :key="variable"
          v-model="exampleValues[variable]"
          :placeholder="
            t('WHATSAPP_TEMPLATES.ADMIN.CREATE.EXAMPLE_PLACEHOLDER', {
              variable: `{{${variable}}}`,
            })
          "
        />
        <span v-if="errors.examples" class="text-sm text-n-ruby-9">
          {{ errors.examples }}
        </span>
      </div>
    </div>
  </Dialog>
</template>
