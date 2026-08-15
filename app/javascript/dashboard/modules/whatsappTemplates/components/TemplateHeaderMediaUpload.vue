<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useConfig } from 'dashboard/composables/useConfig';

import Button from 'dashboard/components-next/button/Button.vue';
import {
  COMPONENT_TYPES,
  MEDIA_FORMATS,
  findComponentByType,
} from 'dashboard/helper/templateHelper';
import WhatsappTemplatesAPI from '../api';

const props = defineProps({
  template: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['uploaded', 'uploading']);

const { t } = useI18n();
const { isEnterprise } = useConfig();
const fileInput = ref(null);
const isUploading = ref(false);
const uploadedFilename = ref('');

const headerFormat = computed(
  () =>
    findComponentByType(props.template, COMPONENT_TYPES.HEADER)?.format || ''
);

const canUploadMedia = computed(
  () => isEnterprise && MEDIA_FORMATS.includes(headerFormat.value)
);

const accept = computed(() => {
  const acceptByFormat = {
    IMAGE: 'image/jpeg,image/png,image/webp',
    VIDEO: 'video/mp4,video/3gpp',
    DOCUMENT: 'application/pdf',
  };
  return acceptByFormat[headerFormat.value.toUpperCase()] || '';
});

const uploadFile = async event => {
  const file = event.target?.files?.[0];
  if (!file) return;

  isUploading.value = true;
  emit('uploading', true);

  try {
    const { data } = await WhatsappTemplatesAPI.uploadHeaderMedia(file);
    uploadedFilename.value = data.original_filename || file.name;
    emit('uploaded', data);
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('WHATSAPP_TEMPLATES.PARSER.MEDIA_UPLOAD_ERROR')
    );
  } finally {
    isUploading.value = false;
    emit('uploading', false);
    if (event.target) event.target.value = '';
  }
};
</script>

<template>
  <div v-show="canUploadMedia" class="flex flex-col gap-2">
    <input
      ref="fileInput"
      type="file"
      class="hidden"
      :accept="accept"
      :disabled="isUploading"
      @change="uploadFile"
    />
    <div class="flex flex-wrap items-center gap-2">
      <Button
        type="button"
        variant="outline"
        color="slate"
        icon="i-lucide-upload"
        :label="
          isUploading
            ? t('WHATSAPP_TEMPLATES.PARSER.MEDIA_UPLOADING')
            : t('WHATSAPP_TEMPLATES.PARSER.MEDIA_UPLOAD_LABEL')
        "
        :disabled="isUploading"
        @click="fileInput?.click()"
      />
      <span
        v-if="uploadedFilename"
        class="min-w-0 truncate text-sm text-n-slate-11"
      >
        {{
          t('WHATSAPP_TEMPLATES.PARSER.MEDIA_UPLOAD_SUCCESS', {
            fileName: uploadedFilename,
          })
        }}
      </span>
    </div>
    <span class="text-xs text-n-slate-11">
      {{ t('WHATSAPP_TEMPLATES.PARSER.MEDIA_UPLOAD_HINT') }}
    </span>
  </div>
</template>
