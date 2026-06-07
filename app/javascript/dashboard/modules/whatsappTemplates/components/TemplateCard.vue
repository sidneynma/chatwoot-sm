<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import TemplatePreview from 'dashboard/components-next/template-preview/TemplatePreview.vue';
import { TemplateNormalizer } from 'dashboard/services/TemplateNormalizer';
import { PLATFORMS } from 'dashboard/services/TemplateConstants';
import {
  getTemplateBody,
  getTemplateButtons,
  getTemplateFooter,
  getTemplateHeader,
} from '../templateDisplay';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
  canManage: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['delete']);

const { t } = useI18n();

const isExpanded = ref(false);

const status = computed(() => (props.template.status || '').toUpperCase());

const statusLabel = computed(() =>
  t(`WHATSAPP_TEMPLATES.ADMIN.STATUS.${status.value}`, status.value)
);

const statusClass = computed(() => {
  switch (status.value) {
    case 'APPROVED':
      return 'bg-n-teal-3 text-n-teal-11';
    case 'PENDING':
    case 'IN_APPEAL':
    case 'PENDING_DELETION':
      return 'bg-n-amber-3 text-n-amber-11';
    case 'REJECTED':
    case 'DISABLED':
    case 'PAUSED':
      return 'bg-n-ruby-3 text-n-ruby-11';
    default:
      return 'bg-n-slate-3 text-n-slate-11';
  }
});

const categoryLabel = computed(() => {
  const category = (props.template.category || '').toUpperCase();
  return t(`WHATSAPP_TEMPLATES.ADMIN.CATEGORY.${category}`, category);
});

const variables = computed(() =>
  TemplateNormalizer.extractWhatsAppVariables(props.template)
);

const rejectedReason = computed(
  () => props.template.rejected_reason || props.template.reason || ''
);

const header = computed(() => getTemplateHeader(props.template));
const body = computed(() => getTemplateBody(props.template));
const footer = computed(() => getTemplateFooter(props.template));
const buttons = computed(() => getTemplateButtons(props.template));
</script>

<template>
  <div class="rounded-xl border border-n-weak bg-n-surface-1">
    <div class="flex items-start gap-3 p-4">
      <button
        class="flex flex-1 flex-col gap-2 text-left"
        @click="isExpanded = !isExpanded"
      >
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-base font-medium text-n-slate-12">
            {{ template.name }}
          </span>
          <span
            class="px-2 py-0.5 rounded-md text-xs font-medium"
            :class="statusClass"
          >
            {{ statusLabel }}
          </span>
          <span
            v-if="template.category"
            class="px-2 py-0.5 rounded-md text-xs font-medium bg-n-blue-3 text-n-blue-11"
          >
            {{ categoryLabel }}
          </span>
          <span
            v-if="template.language"
            class="px-2 py-0.5 rounded-md text-xs font-medium bg-n-slate-3 text-n-slate-11"
          >
            {{ template.language }}
          </span>
        </div>
        <p v-if="body" class="text-sm text-n-slate-11 line-clamp-2">
          {{ body }}
        </p>
        <p v-if="rejectedReason" class="text-xs text-n-ruby-11">
          {{ t('WHATSAPP_TEMPLATES.ADMIN.CARD.REASON') }}: {{ rejectedReason }}
        </p>
      </button>

      <div class="flex items-center gap-1">
        <button
          class="p-1.5 rounded-md hover:bg-n-alpha-2 text-n-slate-11"
          @click="isExpanded = !isExpanded"
        >
          <Icon
            :icon="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
            class="size-4"
          />
        </button>
        <button
          v-if="canManage"
          class="p-1.5 rounded-md hover:bg-n-ruby-3 text-n-ruby-11"
          :title="t('WHATSAPP_TEMPLATES.ADMIN.CARD.DELETE')"
          @click="emit('delete', template)"
        >
          <Icon icon="i-lucide-trash-2" class="size-4" />
        </button>
      </div>
    </div>

    <div
      v-if="isExpanded"
      class="grid grid-cols-1 gap-6 p-4 border-t border-n-weak lg:grid-cols-2"
    >
      <div>
        <p class="mb-2 text-xs font-medium uppercase text-n-slate-10">
          {{ t('WHATSAPP_TEMPLATES.ADMIN.CARD.PREVIEW') }}
        </p>
        <TemplatePreview
          :template="template"
          :variables="variables"
          :platform="PLATFORMS.WHATSAPP"
        />
      </div>

      <div class="flex flex-col gap-3">
        <div v-if="header">
          <p class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CARD.HEADER') }}
          </p>
          <p class="text-sm text-n-slate-12">{{ header }}</p>
        </div>
        <div v-if="body">
          <p class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CARD.BODY') }}
          </p>
          <p class="text-sm text-n-slate-12 whitespace-pre-wrap">{{ body }}</p>
        </div>
        <div v-if="footer">
          <p class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CARD.FOOTER') }}
          </p>
          <p class="text-sm text-n-slate-12">{{ footer }}</p>
        </div>
        <div v-if="buttons">
          <p class="text-xs font-medium uppercase text-n-slate-10">
            {{ t('WHATSAPP_TEMPLATES.ADMIN.CARD.BUTTONS') }}
          </p>
          <p class="text-sm text-n-slate-12">{{ buttons }}</p>
        </div>
      </div>
    </div>
  </div>
</template>
