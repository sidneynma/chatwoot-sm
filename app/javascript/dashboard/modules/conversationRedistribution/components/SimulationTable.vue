<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  assignments: {
    type: Array,
    default: () => [],
  },
  limit: {
    type: Number,
    default: 100,
  },
});

const { t } = useI18n();

const visibleAssignments = computed(() =>
  props.assignments.slice(0, props.limit)
);

const hasMore = computed(
  () => props.assignments.length > visibleAssignments.value.length
);
</script>

<template>
  <div class="overflow-x-auto rounded-lg border border-n-weak">
    <table class="min-w-full text-sm">
      <thead class="bg-n-alpha-1 text-n-slate-11">
        <tr>
          <th class="px-4 py-3 text-left font-medium">
            {{ t('CONVERSATION_REDISTRIBUTION.SIMULATION.TABLE.CONVERSATION') }}
          </th>
          <th class="px-4 py-3 text-left font-medium">
            {{
              t('CONVERSATION_REDISTRIBUTION.SIMULATION.TABLE.CURRENT_AGENT')
            }}
          </th>
          <th class="px-4 py-3 text-left font-medium">
            {{ t('CONVERSATION_REDISTRIBUTION.SIMULATION.TABLE.NEW_AGENT') }}
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-n-weak">
        <tr
          v-for="row in visibleAssignments"
          :key="row.conversation_id"
          class="text-n-slate-12"
        >
          <td class="px-4 py-3">
            {{
              t('CONVERSATION_REDISTRIBUTION.SIMULATION.TABLE.DISPLAY_ID', {
                displayId: row.display_id,
              })
            }}
          </td>
          <td class="px-4 py-3">
            {{
              row.current_assignee?.name ||
              t('CONVERSATION_REDISTRIBUTION.UNASSIGNED')
            }}
          </td>
          <td class="px-4 py-3">{{ row.new_assignee?.name }}</td>
        </tr>
      </tbody>
    </table>
    <p
      v-if="hasMore"
      class="px-4 py-3 text-xs text-n-slate-11 border-t border-n-weak"
    >
      {{
        t('CONVERSATION_REDISTRIBUTION.SIMULATION.TABLE.TRUNCATED', {
          shown: visibleAssignments.length,
          total: assignments.length,
        })
      }}
    </p>
  </div>
</template>
