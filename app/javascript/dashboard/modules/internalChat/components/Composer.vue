<script setup>
import { computed, defineAsyncComponent, onBeforeUnmount, ref } from 'vue';
import { onClickOutside } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import { useAccount } from 'dashboard/composables/useAccount';

const emit = defineEmits(['send']);

const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);

const { t } = useI18n();
const { accountId } = useAccount();

const content = ref('');
const pendingFiles = ref([]);
const showEmojiPicker = ref(false);
const isRecording = ref(false);
const mediaRecorder = ref(null);
const recordedChunks = ref([]);
const fileInput = ref(null);
const sending = ref(false);
const emojiButtonWrap = ref(null);

onClickOutside(emojiButtonWrap, () => {
  showEmojiPicker.value = false;
});

const canSend = computed(
  () =>
    !sending.value &&
    (content.value.trim().length > 0 || pendingFiles.value.length > 0)
);

const addEmoji = emoji => {
  content.value += emoji?.value || emoji || '';
  showEmojiPicker.value = false;
};

const onPickFiles = async event => {
  const files = Array.from(event.target.files || []);
  event.target.value = '';
  const uploads = await Promise.all(
    files.map(file => uploadFile(file, accountId.value))
  );
  uploads.forEach((uploaded, index) => {
    pendingFiles.value.push({
      name: files[index].name,
      blobSignedId: uploaded.blobId,
      previewUrl: uploaded.fileUrl,
      isVoice: false,
    });
  });
};

const removePending = index => {
  pendingFiles.value.splice(index, 1);
};

const startRecording = async () => {
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  recordedChunks.value = [];
  const recorder = new MediaRecorder(stream);
  mediaRecorder.value = recorder;
  recorder.ondataavailable = event => {
    if (event.data.size) recordedChunks.value.push(event.data);
  };
  recorder.onstop = async () => {
    stream.getTracks().forEach(track => track.stop());
    const blob = new Blob(recordedChunks.value, { type: 'audio/webm' });
    const file = new File([blob], `voice-${Date.now()}.webm`, {
      type: 'audio/webm',
    });
    const uploaded = await uploadFile(file, accountId.value);
    pendingFiles.value.push({
      name: file.name,
      blobSignedId: uploaded.blobId,
      previewUrl: uploaded.fileUrl,
      isVoice: true,
    });
    isRecording.value = false;
  };
  recorder.start();
  isRecording.value = true;
};

const stopRecording = () => {
  mediaRecorder.value?.stop();
};

onBeforeUnmount(() => {
  if (mediaRecorder.value?.state === 'recording') {
    mediaRecorder.value.stream?.getTracks?.().forEach(track => track.stop());
    mediaRecorder.value.stop();
  }
});

const send = async () => {
  if (!canSend.value) return;
  sending.value = true;
  const snapshot = {
    content: content.value.trim(),
    files: [...pendingFiles.value],
  };
  try {
    await new Promise((resolve, reject) => {
      emit('send', {
        content: snapshot.content,
        blobSignedIds: snapshot.files.map(file => file.blobSignedId),
        isVoice: snapshot.files.some(file => file.isVoice),
        onSuccess: resolve,
        onError: reject,
      });
    });
    content.value = '';
    pendingFiles.value = [];
    showEmojiPicker.value = false;
  } catch {
    // Keep draft so the user can retry.
  } finally {
    sending.value = false;
  }
};
</script>

<template>
  <footer class="relative z-30 border-t border-n-weak bg-n-solid-1 p-3">
    <div v-if="pendingFiles.length" class="mb-2 flex flex-wrap gap-2">
      <div
        v-for="(file, index) in pendingFiles"
        :key="`${file.blobSignedId}-${index}`"
        class="flex items-center gap-2 rounded-lg bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-12"
      >
        <span class="max-w-40 truncate">{{ file.name }}</span>
        <button
          type="button"
          class="i-lucide-x size-3.5"
          @click="removePending(index)"
        />
      </div>
    </div>

    <div class="relative flex items-end gap-2">
      <div ref="emojiButtonWrap" class="relative">
        <Button
          icon="i-lucide-smile"
          size="sm"
          variant="ghost"
          :aria-label="t('EMOJI.TITLE', 'Emoji')"
          @click="showEmojiPicker = !showEmojiPicker"
        />
        <EmojiIconPicker
          v-if="showEmojiPicker"
          mode="emoji"
          class="!bottom-full !top-auto !z-50 mb-1.5 ltr:!left-0 rtl:!right-0"
          @select="addEmoji"
        />
      </div>

      <input
        ref="fileInput"
        type="file"
        class="hidden"
        multiple
        @change="onPickFiles"
      />
      <Button
        icon="i-lucide-paperclip"
        size="sm"
        variant="ghost"
        :aria-label="t('INTERNAL_CHAT.ATTACH')"
        @click="fileInput?.click()"
      />

      <Button
        v-if="!isRecording"
        icon="i-lucide-mic"
        size="sm"
        variant="ghost"
        :aria-label="t('INTERNAL_CHAT.RECORD_AUDIO')"
        @click="startRecording"
      />
      <Button
        v-else
        icon="i-lucide-square"
        size="sm"
        color="ruby"
        :label="t('INTERNAL_CHAT.STOP_RECORDING')"
        @click="stopRecording"
      />

      <textarea
        v-model="content"
        rows="1"
        class="max-h-32 min-h-[40px] flex-1 resize-none rounded-xl border border-n-weak bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
        :placeholder="t('INTERNAL_CHAT.PLACEHOLDER')"
        @keydown.enter.exact.prevent="send"
      />

      <Button
        icon="i-lucide-send"
        size="sm"
        color="blue"
        :disabled="!canSend"
        :is-loading="sending"
        :aria-label="t('INTERNAL_CHAT.SEND')"
        @click="send"
      />
    </div>
  </footer>
</template>
