<script setup>
import { ref } from 'vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TemplateHeaderMediaUpload from 'dashboard/modules/whatsappTemplates/components/TemplateHeaderMediaUpload.vue';

defineProps({
  template: {
    type: Object,
    default: () => ({}),
  },
  contactName: {
    type: String,
    default: '',
  },
  agentName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['sendMessage', 'resetTemplate']);

const templateParser = ref(null);
const isUploadingMedia = ref(false);

const handleSendMessage = payload => {
  emit('sendMessage', payload);
};

const handleResetTemplate = () => {
  emit('resetTemplate');
};

const handleMediaUploaded = media => {
  templateParser.value?.updateMediaUrl(media.media_url || media.url);
  if (media.media_type === 'document') {
    templateParser.value?.updateMediaName(
      media.media_name || media.original_filename
    );
  }
};
</script>

<template>
  <div class="w-full">
    <WhatsAppTemplateParser
      ref="templateParser"
      :template="template"
      :contact-name="contactName"
      :agent-name="agentName"
      @send-message="handleSendMessage"
      @reset-template="handleResetTemplate"
    >
      <template #actions="{ sendMessage, resetTemplate, disabled }">
        <div class="flex flex-col gap-4">
          <TemplateHeaderMediaUpload
            :template="template"
            @uploaded="handleMediaUploaded"
            @uploading="isUploadingMedia = $event"
          />
          <footer class="flex justify-end gap-2">
            <NextButton
              faded
              slate
              type="reset"
              :label="$t('WHATSAPP_TEMPLATES.PARSER.GO_BACK_LABEL')"
              @click="resetTemplate"
            />
            <NextButton
              type="button"
              :label="$t('WHATSAPP_TEMPLATES.PARSER.SEND_MESSAGE_LABEL')"
              :disabled="disabled || isUploadingMedia"
              @click="sendMessage"
            />
          </footer>
        </div>
      </template>
    </WhatsAppTemplateParser>
  </div>
</template>
