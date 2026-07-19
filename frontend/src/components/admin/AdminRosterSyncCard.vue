<script setup>
import { ref } from 'vue'
import { formatDate } from '../../utils/adminFormatting'
import AdminSyncProgress from './AdminSyncProgress.vue'
import AdminTaskCard from './AdminTaskCard.vue'

defineProps({ options: { type: Object, required: true }, teams: { type: Array, default: () => [] }, coverage: { type: Object, required: true }, task: { type: Object, default: null }, active: { type: Boolean, default: false }, starting: { type: Boolean, default: false }, anyActionRunning: { type: Boolean, default: false }, error: { type: String, default: '' }, maxSeason: { type: Number, required: true } })
const emit = defineEmits(['submit', 'cancel-active'])
const syncButton = ref(null)
defineExpose({ focusSyncButton: () => syncButton.value?.focus() })
</script>

<template>
  <AdminTaskCard data-test="roster-sync-form" source="Current roster state" title="MLB 40-man roster synchronization" command="mlb_roster:sync" description="Downloads MLB 40-man rosters and updates player profiles, roster status, and dated team memberships for the selected season." @submit.prevent="emit('submit')">
    <p class="admin-card__coverage" data-test="roster-database-coverage"><strong>Database coverage:</strong> <template v-if="coverage.earliestDate && coverage.latestDate">{{ formatDate(coverage.earliestDate) }}–{{ formatDate(coverage.latestDate) }}</template><template v-else>No dated roster memberships stored</template></p>
    <div class="admin-fields admin-fields--three">
      <label><span>Team selection</span><select v-model="options.teamScope" data-test="roster-team-scope"><option value="all">All MLB teams</option><option value="american">American League</option><option value="national">National League</option><option value="team">Specific team</option></select></label>
      <label v-if="options.teamScope === 'team'" class="admin-field--wide"><span>MLB team</span><select v-model="options.teamMlbId" data-test="roster-team" required><option value="" disabled>Select a team</option><option v-for="team in teams" :key="team.mlbId" :value="String(team.mlbId)">{{ team.abbreviation }} · {{ team.name }} ({{ team.league === 'american' ? 'AL' : 'NL' }})</option></select></label>
      <label><span>Season</span><input v-model.number="options.season" type="number" min="1876" :max="maxSeason" required /></label>
    </div>
    <p class="admin-card__hint" data-test="roster-coverage-policy">Synchronizes MLB's 40-man roster only. Completed seasons use the final stored regular-season game date; the current season uses today. Historical roster construction will be handled as a separate transaction-based workflow.</p>
    <button ref="syncButton" class="admin-button" type="submit" :disabled="anyActionRunning">{{ starting ? 'Starting synchronization…' : active ? 'Synchronization in progress…' : 'Synchronize team roster' }}</button>
    <AdminSyncProgress v-if="task" :task="task" :active="active" test-id="roster-sync-progress" aria-label="Roster synchronization" item-noun="teams" current-item-label="Current team" cancel-item-noun="team" @cancel="emit('cancel-active')" />
    <p v-if="error" class="admin-message admin-message--error" role="alert">{{ error }}</p>
  </AdminTaskCard>
</template>
