<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import Button from 'dashboard/components-next/button/Button.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import WhatsappTemplatesAPI from '../api';
import TemplateButtonsEditor from '../components/TemplateButtonsEditor.vue';
import {
  detectParameterFormat,
  extractVariablesInOrder,
  NAMED_VARIABLE_REGEX,
  nextPositionalVariable,
} from '../templateVariables';

const props = defineProps({
  open: {
    type: Boolean,
    default: false,
  },
  inboxId: {
    type: [Number, String],
    default: null,
  },
  isCreating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:open', 'submit']);

const { t } = useI18n();

const NAME_REGEX = /^[a-z0-9_]+$/;
const MEDIA_HEADER_TYPES = ['IMAGE', 'VIDEO', 'DOCUMENT'];

const formatTemplateName = value =>
  value
    .toLowerCase()
    .replace(/\s+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');

const form = ref({
  name: '',
  category: 'UTILITY',
  language: 'pt_BR',
  header_type: 'NONE',
  header_text: '',
  body_text: '',
  footer_text: '',
});

const updateTemplateName = value => {
  form.value.name = formatTemplateName(value);
};

const headerMediaFile = ref(null);
const mediaInputRef = ref(null);
const isUploadingMedia = ref(false);
const exampleValues = ref({});
const errors = ref({});
const variableMode = ref('POSITIONAL');
const namedVariableInput = ref('');
const templateButtons = ref([]);

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

const headerTypeOptions = computed(() => [
  {
    value: 'NONE',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_TYPE_NONE'),
  },
  {
    value: 'TEXT',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_TYPE_TEXT'),
  },
  {
    value: 'IMAGE',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_TYPE_IMAGE'),
  },
  {
    value: 'VIDEO',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_TYPE_VIDEO'),
  },
  {
    value: 'DOCUMENT',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_TYPE_DOCUMENT'),
  },
  {
    value: 'LOCATION',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_TYPE_LOCATION'),
  },
]);

const isMediaHeader = computed(() =>
  MEDIA_HEADER_TYPES.includes(form.value.header_type)
);

const showTextHeader = computed(() => form.value.header_type === 'TEXT');

const isLocationHeader = computed(() => form.value.header_type === 'LOCATION');

const mediaAccept = computed(() => {
  const acceptMap = {
    IMAGE: 'image/jpeg,image/png',
    VIDEO: 'video/mp4',
    DOCUMENT: 'application/pdf,.pdf',
  };
  return acceptMap[form.value.header_type] || '';
});

const mediaHint = computed(() => {
  const hintMap = {
    IMAGE: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_MEDIA_HINT_IMAGE'),
    VIDEO: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_MEDIA_HINT_VIDEO'),
    DOCUMENT: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_MEDIA_HINT_DOCUMENT'),
  };
  return hintMap[form.value.header_type] || '';
});

const headerVariables = computed(() =>
  showTextHeader.value ? extractVariablesInOrder(form.value.header_text) : []
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

const isSubmitting = computed(() => props.isCreating || isUploadingMedia.value);

const variableTypeOptions = computed(() => [
  {
    value: 'POSITIONAL',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.VARIABLE_TYPE_POSITIONAL'),
  },
  {
    value: 'NAMED',
    label: t('WHATSAPP_TEMPLATES.ADMIN.CREATE.VARIABLE_TYPE_NAMED'),
  },
]);

const canUseVariableMode = mode => {
  if (!bodyVariables.value.length) return true;

  const format = detectParameterFormat(bodyVariables.value);
  if (!format || format === 'MIXED') return false;

  return format === mode;
};

const insertBodyVariable = token => {
  const current = form.value.body_text;
  const separator =
    current.length && !current.endsWith(' ') && !current.endsWith('\n')
      ? ' '
      : '';
  form.value.body_text = `${current}${separator}{{${token}}}`;
};

const addPositionalVariable = () => {
  delete errors.value.namedVariable;
  delete errors.value.variableMode;

  if (!canUseVariableMode('POSITIONAL')) {
    errors.value.variableMode = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VARIABLE_MIXED_BLOCKED'
    );
    return;
  }

  const token = nextPositionalVariable(bodyVariables.value);
  insertBodyVariable(token);
};

const addNamedVariable = () => {
  delete errors.value.namedVariable;
  delete errors.value.variableMode;

  const name = namedVariableInput.value.trim();
  if (!name) return;

  if (!NAMED_VARIABLE_REGEX.test(name)) {
    errors.value.namedVariable = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.NAMED_VARIABLE_INVALID'
    );
    return;
  }

  if (!canUseVariableMode('NAMED')) {
    errors.value.variableMode = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VARIABLE_MIXED_BLOCKED'
    );
    return;
  }

  if (bodyVariables.value.includes(name)) {
    errors.value.namedVariable = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.NAMED_VARIABLE_EXISTS',
      { name }
    );
    return;
  }

  insertBodyVariable(name);
  namedVariableInput.value = '';
};

const resetForm = () => {
  form.value = {
    name: '',
    category: 'UTILITY',
    language: 'pt_BR',
    header_type: 'NONE',
    header_text: '',
    body_text: '',
    footer_text: '',
  };
  headerMediaFile.value = null;
  if (mediaInputRef.value) mediaInputRef.value.value = '';
  exampleValues.value = {};
  errors.value = {};
  variableMode.value = 'POSITIONAL';
  namedVariableInput.value = '';
  templateButtons.value = [];
};

const onMediaFileChange = event => {
  headerMediaFile.value = event.target.files?.[0] || null;
};

const createTemplateButton = type => {
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

const addTemplateButton = async type => {
  const nextIndex = templateButtons.value.length;
  templateButtons.value = [
    ...templateButtons.value,
    createTemplateButton(type),
  ];
  await nextTick();
  document
    .getElementById(`template-button-${nextIndex}`)
    ?.scrollIntoView({ behavior: 'smooth', block: 'center' });
};

const removeTemplateButton = index => {
  templateButtons.value = templateButtons.value.filter((_, i) => i !== index);
};

const updateTemplateButton = ({ index, patch }) => {
  templateButtons.value = templateButtons.value.map((button, i) =>
    i === index ? { ...button, ...patch } : button
  );
};

const validateButtons = () => {
  if (!templateButtons.value.length) return;

  const types = templateButtons.value.map(button => button.type);
  const hasQuickReply = types.includes('QUICK_REPLY');
  const hasCta = types.some(type => ['URL', 'PHONE_NUMBER'].includes(type));

  if (hasQuickReply && hasCta) {
    errors.value.buttons = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.MIXED_TYPES'
    );
    return;
  }

  if (hasQuickReply) {
    templateButtons.value.forEach((button, index) => {
      if (!button.text?.trim()) {
        errors.value[`button_${index}_text`] = t(
          'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.TEXT_REQUIRED'
        );
      } else if (button.text.trim().length > 25) {
        errors.value[`button_${index}_text`] = t(
          'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.TEXT_LENGTH'
        );
      }
    });
    return;
  }

  const phoneCount = templateButtons.value.filter(
    button => button.type === 'PHONE_NUMBER'
  ).length;

  if (phoneCount > 1) {
    errors.value.buttons = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.PHONE_LIMIT'
    );
  }

  templateButtons.value.forEach((button, index) => {
    if (!button.text?.trim()) {
      errors.value[`button_${index}_text`] = t(
        'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.TEXT_REQUIRED'
      );
    } else if (button.text.trim().length > 25) {
      errors.value[`button_${index}_text`] = t(
        'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.TEXT_LENGTH'
      );
    }

    if (button.type === 'URL') {
      if (!button.url?.trim()) {
        errors.value[`button_${index}_url`] = t(
          'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.URL_REQUIRED'
        );
      } else if (
        /\{\{[^}]+\}\}/.test(button.url) &&
        !button.url_example?.trim()
      ) {
        errors.value[`button_${index}_url_example`] = t(
          'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.URL_EXAMPLE_REQUIRED'
        );
      }
    }

    if (button.type === 'PHONE_NUMBER') {
      const phone = button.phone_number?.trim();
      if (!phone) {
        errors.value[`button_${index}_phone`] = t(
          'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.PHONE_REQUIRED'
        );
      } else if (!/^\+[1-9]\d{6,14}$/.test(phone)) {
        errors.value[`button_${index}_phone`] = t(
          'WHATSAPP_TEMPLATES.ADMIN.CREATE.BUTTONS.VALIDATION.PHONE_FORMAT'
        );
      }
    }
  });
};

const validate = () => {
  errors.value = {};

  if (!form.value.name.trim()) {
    errors.value.name = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.NAME_REQUIRED'
    );
  } else if (!NAME_REGEX.test(formatTemplateName(form.value.name))) {
    errors.value.name = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.NAME_FORMAT'
    );
  }

  if (!form.value.body_text.trim()) {
    errors.value.body = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.BODY_REQUIRED'
    );
  }

  if (isMediaHeader.value && !headerMediaFile.value) {
    errors.value.header_media = t(
      'WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.MEDIA_REQUIRED'
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

  validateButtons();

  return Object.keys(errors.value).length === 0;
};

const handleSubmit = async () => {
  if (!validate()) return;

  let headerHandle;

  if (isMediaHeader.value) {
    if (!props.inboxId) return;

    isUploadingMedia.value = true;
    try {
      const { data } = await WhatsappTemplatesAPI.uploadMedia(
        props.inboxId,
        headerMediaFile.value,
        form.value.header_type
      );
      headerHandle = data.header_handle;
    } catch (error) {
      useAlert(
        error?.response?.data?.error ||
          t('WHATSAPP_TEMPLATES.ADMIN.CREATE.VALIDATION.MEDIA_UPLOAD_FAILED')
      );
      return;
    } finally {
      isUploadingMedia.value = false;
    }
  }

  const variableExamples = Object.fromEntries(
    templateVariables.value.map(variable => [
      variable,
      exampleValues.value[variable]?.trim() || '',
    ])
  );

  const payload = {
    name: formatTemplateName(form.value.name),
    category: form.value.category,
    language: form.value.language,
    body_text: form.value.body_text.trim(),
    footer_text: form.value.footer_text.trim(),
    variable_examples: variableExamples,
  };

  if (parameterFormat.value) {
    payload.parameter_format = parameterFormat.value;
  }

  if (isMediaHeader.value) {
    payload.header_format = form.value.header_type;
    payload.header_handle = headerHandle;
  } else if (isLocationHeader.value) {
    payload.header_format = 'LOCATION';
  } else if (showTextHeader.value && form.value.header_text.trim()) {
    payload.header_text = form.value.header_text.trim();
  }

  if (templateButtons.value.length) {
    payload.buttons = templateButtons.value.map(button => {
      if (button.type === 'QUICK_REPLY') {
        return {
          type: 'QUICK_REPLY',
          text: button.text.trim(),
        };
      }

      const ctaButton = {
        type: button.type,
        text: button.text.trim(),
      };

      if (button.type === 'URL') {
        ctaButton.url = button.url.trim();
        if (button.url_example?.trim()) {
          ctaButton.example = [button.url_example.trim()];
        }
      } else {
        ctaButton.phone_number = button.phone_number.trim();
      }

      return ctaButton;
    });
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

watch(
  () => form.value.header_type,
  () => {
    form.value.header_text = '';
    headerMediaFile.value = null;
    if (mediaInputRef.value) mediaInputRef.value.value = '';
    delete errors.value.header_media;
  }
);
</script>

<template>
  <TeleportWithDirection to="body">
    <div
      v-if="open"
      class="fixed inset-0 z-[100000] flex items-center justify-center p-3 bg-n-alpha-black1 backdrop-blur-sm"
      @click.self="close"
    >
      <div
        class="flex flex-col w-full max-w-xl max-h-[calc(100vh-1.5rem)] gap-3 p-4 overflow-y-auto rounded-xl border shadow-xl border-n-weak bg-n-alpha-3 backdrop-blur-[100px]"
        role="dialog"
        aria-modal="true"
        :aria-label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.TITLE')"
        @click.stop
      >
        <div class="flex flex-col gap-1">
          <h3 class="text-sm font-medium leading-5 text-n-slate-12">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.TITLE') }}
          </h3>
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.DESCRIPTION') }}
          </p>
        </div>

        <form class="flex flex-col gap-3" @submit.prevent="handleSubmit">
          <Input
            :model-value="form.name"
            :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.NAME_LABEL')"
            :placeholder="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.NAME_PLACEHOLDER')"
            :message="
              errors.name || t('WHATSAPP_TEMPLATES.ADMIN.CREATE.NAME_HINT')
            "
            :message-type="errors.name ? 'error' : 'info'"
            @update:model-value="updateTemplateName"
          />

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
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

          <div
            class="flex flex-col gap-2 p-3 rounded-xl border border-n-weak bg-n-surface-1"
          >
            <p class="text-xs font-medium text-n-slate-12">
              {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_SECTION_TITLE') }}
            </p>

            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_TYPE_LABEL') }}
              </label>
              <Select
                v-model="form.header_type"
                :options="headerTypeOptions"
                class="!w-full"
              />
              <p class="text-xs text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_TYPE_HINT') }}
              </p>
            </div>

            <Input
              v-if="showTextHeader"
              v-model="form.header_text"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_LABEL')"
              :placeholder="
                t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_PLACEHOLDER')
              "
            />

            <p v-if="isLocationHeader" class="text-sm text-n-slate-11">
              {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_LOCATION_HINT') }}
            </p>

            <div v-if="isMediaHeader" class="flex flex-col gap-2">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_MEDIA_LABEL') }}
              </label>
              <p class="text-sm text-n-slate-11">
                {{ mediaHint }}
              </p>
              <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
                <input
                  ref="mediaInputRef"
                  type="file"
                  :accept="mediaAccept"
                  class="hidden"
                  @change="onMediaFileChange"
                />
                <Button
                  type="button"
                  variant="outline"
                  color="slate"
                  :label="
                    t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_MEDIA_CHOOSE')
                  "
                  @click="mediaInputRef?.click()"
                />
                <span
                  v-if="headerMediaFile"
                  class="text-sm truncate text-n-slate-12"
                >
                  {{
                    t('WHATSAPP_TEMPLATES.ADMIN.CREATE.HEADER_MEDIA_SELECTED', {
                      fileName: headerMediaFile.name,
                    })
                  }}
                </span>
              </div>
              <span v-if="errors.header_media" class="text-sm text-n-ruby-9">
                {{ errors.header_media }}
              </span>
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <TextArea
              v-model="form.body_text"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BODY_LABEL')"
              :placeholder="
                t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BODY_PLACEHOLDER')
              "
              :max-length="1024"
              :message="
                errors.body ||
                errors.variableMode ||
                t('WHATSAPP_TEMPLATES.ADMIN.CREATE.BODY_HINT')
              "
              :message-type="
                errors.body || errors.variableMode ? 'error' : 'info'
              "
              auto-height
            />

            <div
              class="flex flex-col gap-2 p-3 rounded-lg border border-n-weak bg-n-surface-1"
            >
              <div class="flex flex-col gap-1">
                <label class="text-xs font-medium text-n-slate-12">
                  {{ t('WHATSAPP_TEMPLATES.ADMIN.CREATE.VARIABLE_TYPE_LABEL') }}
                </label>
                <Select
                  v-model="variableMode"
                  :options="variableTypeOptions"
                  class="!w-full"
                />
              </div>

              <div
                v-if="variableMode === 'POSITIONAL'"
                class="flex items-center"
              >
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  color="slate"
                  icon="i-lucide-plus"
                  :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.ADD_VARIABLE')"
                  @click="addPositionalVariable"
                />
              </div>

              <div v-else class="flex flex-col gap-2 sm:flex-row sm:items-end">
                <Input
                  v-model="namedVariableInput"
                  class="flex-1"
                  :placeholder="
                    t(
                      'WHATSAPP_TEMPLATES.ADMIN.CREATE.NAMED_VARIABLE_PLACEHOLDER'
                    )
                  "
                  :message="errors.namedVariable"
                  :message-type="errors.namedVariable ? 'error' : 'info'"
                  @keyup.enter.prevent="addNamedVariable"
                />
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  color="slate"
                  icon="i-lucide-plus"
                  :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.ADD_VARIABLE')"
                  @click="addNamedVariable"
                />
              </div>
            </div>
          </div>

          <div
            class="flex flex-col gap-2 p-3 rounded-xl border border-n-weak bg-n-surface-1"
          >
            <TemplateButtonsEditor
              :buttons="templateButtons"
              :errors="errors"
              @add="addTemplateButton"
              @remove="removeTemplateButton"
              @update="updateTemplateButton"
            />
          </div>

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

          <div class="flex items-center justify-between w-full gap-2 pt-1">
            <Button
              type="button"
              size="sm"
              variant="faded"
              color="slate"
              class="w-full"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.CANCEL')"
              @click="close"
            />
            <Button
              type="submit"
              size="sm"
              color="blue"
              class="w-full"
              :label="t('WHATSAPP_TEMPLATES.ADMIN.CREATE.SUBMIT')"
              :is-loading="isSubmitting"
              :disabled="isSubmitting"
            />
          </div>
        </form>
      </div>
    </div>
  </TeleportWithDirection>
</template>
