<script setup>
import { ref } from 'vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useI18n } from 'vue-i18n';
import TemplateHeaderMediaUpload from 'dashboard/modules/whatsappTemplates/components/TemplateHeaderMediaUpload.vue';

const props = defineProps({
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

const emit = defineEmits(['sendMessage', 'back']);

const { t } = useI18n();
const templateParser = ref(null);
const isUploadingMedia = ref(false);

const handleSendMessage = payload => {
  emit('sendMessage', payload);
};

const handleBack = () => {
  emit('back');
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
  <div class="flex flex-col gap-4 px-4 pt-6 pb-5 items-start w-[28.75rem]">
    <div class="w-full">
      <WhatsAppTemplateParser
        ref="templateParser"
        :template="props.template"
        :contact-name="contactName"
        :agent-name="agentName"
        @send-message="handleSendMessage"
        @back="handleBack"
      >
        <template #actions="{ sendMessage, goBack, disabled }">
          <div class="flex w-full flex-col gap-4">
            <TemplateHeaderMediaUpload
              :template="props.template"
              @uploaded="handleMediaUploaded"
              @uploading="isUploadingMedia = $event"
            />
            <div class="flex w-full items-end justify-between gap-3">
              <Button
                :label="
                  t(
                    'COMPOSE_NEW_CONVERSATION.FORM.WHATSAPP_OPTIONS.TEMPLATE_PARSER.BACK'
                  )
                "
                color="slate"
                variant="faded"
                class="w-full font-medium"
                @click="goBack"
              />
              <Button
                :label="
                  t(
                    'COMPOSE_NEW_CONVERSATION.FORM.WHATSAPP_OPTIONS.TEMPLATE_PARSER.SEND_MESSAGE'
                  )
                "
                class="w-full font-medium"
                :disabled="disabled || isUploadingMedia"
                @click="sendMessage"
              />
            </div>
          </div>
        </template>
      </WhatsAppTemplateParser>
    </div>
  </div>
</template>
