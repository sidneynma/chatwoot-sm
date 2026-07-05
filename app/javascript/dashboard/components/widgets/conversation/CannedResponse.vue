<script>
import { mapGetters } from 'vuex';
import MentionBox from '../mentions/MentionBox.vue';
import { filterCannedResponsesForInbox } from 'dashboard/modules/inboxScopedResources';

export default {
  components: { MentionBox },
  props: {
    searchKey: {
      type: String,
      default: '',
    },
    inboxId: {
      type: Number,
      default: null,
    },
  },
  emits: ['replace'],
  computed: {
    ...mapGetters({
      cannedMessages: 'getCannedResponses',
    }),
    scopedCannedMessages() {
      return filterCannedResponsesForInbox(this.cannedMessages, this.inboxId);
    },
    items() {
      return this.scopedCannedMessages.map(cannedMessage => ({
        label: cannedMessage.short_code,
        key: cannedMessage.short_code,
        description: cannedMessage.content,
      }));
    },
  },
  watch: {
    searchKey() {
      this.fetchCannedResponses();
    },
  },
  mounted() {
    this.fetchCannedResponses();
  },
  methods: {
    fetchCannedResponses() {
      this.$store.dispatch('getCannedResponse', { searchKey: this.searchKey });
    },
    handleMentionClick(item = {}) {
      this.$emit('replace', item.description);
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <MentionBox
    v-if="items.length"
    :items="items"
    @mention-select="handleMentionClick"
  />
</template>
