<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import {
  detectParameterFormat,
  extractVariablesInOrder,
  NAMED_VARIABLE_REGEX,
} from '../templateVariables';

const props = defineProps({
  open: {
    type: Boolean,
    default: false,
  },
  isCreating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:open', 'submit']);

const { t } = useI18n();

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

const headerVariables = computed(() =>
  extractVariablesInOrder(form.value.header_text)
);

const bodyVariables = computed(() =>
  extractVariablesInOrder(form.value.body_text)
);

const templateVariables = computed(() => [
  ...headerVariables.value,
  ...bodyVariables.value.filter(
    variable => !headerVariables.value.includes(variable)
  ),
]);

const parameterFormat = computed(() =>
  detectParameterFormat(templateVariables.value)
);

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

  if (parameterFormat.value === 'MIXED') {
    errors.value.body = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.MIXED_VARIABLES'
    );
  } else if (parameterFormat.value === 'NAMED') {
    const invalidNamed = templateVariables.value.find(
      variable => !NAMED_VARIABLE_REGEX.test(variable)
    );
    if (invalidNamed) {
      errors.value.body = t(
        'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.NAMED_FORMAT',
        { variable: `{{${invalidNamed}}}` }
      );
    }
  }

  const missingExample = templateVariables.value.some(
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

  const variableExamples = Object.fromEntries(
    templateVariables.value.map(variable => [
      variable,
      exampleValues.value[variable]?.trim() || '',
    ])
  );

  const payload = {
    name: form.value.name.trim(),
    category: form.value.category,
    language: form.value.language,
    header_text: form.value.header_text.trim(),
    body_text: form.value.body_text.trim(),
    footer_text: form.value.footer_text.trim(),
    variable_examples: variableExamples,
  };

  if (parameterFormat.value) {
    payload.parameter_format = parameterFormat.value;
  }

  emit('submit', payload);
};

const close = () => {
  emit('update:open', false);
};

watch(
  () => props.open,
  isOpen => {
    if (isOpen) resetForm();
  }
);
</script>

<template>
  <TeleportWithDirection to="body">
    <div
      v-if="open"
      class="fixed inset-0 z-[100000] flex items-center justify-center p-4 bg-n-alpha-black1 backdrop-blur-sm"
      @click.self="close"
    >
      <div
        class="flex flex-col w-full max-w-2xl max-h-[90vh] gap-6 p-6 overflow-y-auto rounded-xl border shadow-xl border-n-weak bg-n-alpha-3 backdrop-blur-[100px]"
        role="dialog"
        aria-modal="true"
        :aria-label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.TITLE')"
        @click.stop
      >
        <div class="flex flex-col gap-2">
          <h3 class="text-base font-medium leading-6 text-n-slate-12">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.DESCRIPTION') }}
          </p>
        </div>

        <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
          <Input
            v-model="form.name"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.NAME_LABEL')"
            :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.NAME_PLACEHOLDER')"
            :message="
              errors.name || t('WHATSAPP_TEMPLATES.ADMIN.CREATE.NAME_HINT')
            "
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
            :placeholder="
              t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_PLACEHOLDER')
            "
          />

          <TextArea
            v-model="form.body_text"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BODY_LABEL')"
            :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BODY_PLACEHOLDER')"
            :max-length="1024"
            :message="
              errors.body || t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BODY_HINT')
            "
            :message-type="errors.body ? 'error' : 'info'"
            auto-height
          />

          <Input
            v-model="form.footer_text"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.FOOTER_LABEL')"
            :placeholder="
              t('WHATSAPP_TEMPLATES.ADMIN.CREATE.FOOTER_PLACEHOLDER')
            "
          />

          <div v-if="templateVariables.length" class="flex flex-col gap-2">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.EXAMPLES_TITLE') }}
            </label>
            <Input
              v-for="variable in templateVariables"
              :key="variable"
              v-model="exampleValues[variable]"
              :label="`{{${variable}}}`"
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

          <div class="flex items-center justify-between w-full gap-3 pt-2">
            <Button
              type="button"
              variant="faded"
              color="slate"
              class="w-full"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.CANCEL')"
              @click="close"
            />
            <Button
              type="submit"
              color="blue"
              class="w-full"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.SUBMIT')"
              :is-loading="isCreating"
              :disabled="isCreating"
            />
          </div>
        </form>
      </div>
    </div>
  </TeleportWithDirection>
</template>
