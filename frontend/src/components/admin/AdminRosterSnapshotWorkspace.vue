<script setup>
import { computed } from 'vue'

const props = defineProps({
  options: { type: Object, required: true },
  teams: { type: Array, default: () => [] },
  snapshots: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  error: { type: String, default: '' },
  anyActionRunning: { type: Boolean, default: false },
  runningTask: { type: String, default: '' },
  maxDate: { type: String, required: true },
})
const emit = defineEmits(['sync', 'load'])

const activeSnapshot = computed(
  () => props.snapshots.find((snapshot) => snapshot.roster_type === 'active') || null,
)
const fortyManSnapshot = computed(
  () => props.snapshots.find((snapshot) => snapshot.roster_type === '40Man') || null,
)
const selectedSnapshots = computed(() => [activeSnapshot.value, fortyManSnapshot.value])

function formatDate(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    .format(new Date(`${value}T12:00:00`))
}

function formatTimestamp(value) {
  if (!value) return 'Unavailable'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
  }).format(new Date(value))
}
</script>

<template>
  <section class="roster-snapshot-workspace" data-test="roster-snapshot-workspace">
    <div class="admin-card__title">
      <div><p>Dated reference data</p><h3>Active and 40-man roster snapshots</h3></div>
      <span class="admin-chip">Independent snapshots</span>
    </div>
    <p class="admin-card__hint">Retrieve both MLB roster views for an exact date without changing historical team memberships.</p>

    <form class="roster-snapshot-controls" data-test="roster-snapshot-form" @submit.prevent="emit('sync')">
      <label>
        <span>MLB team</span>
        <select v-model="options.teamMlbId" data-test="snapshot-team" required>
          <option value="" disabled>Select a team</option>
          <option v-for="team in teams" :key="team.mlbId" :value="String(team.mlbId)">{{ team.abbreviation }} · {{ team.name }}</option>
        </select>
      </label>
      <label><span>Snapshot date</span><input v-model="options.snapshotOn" type="date" :max="maxDate" required /></label>
      <button class="admin-button" type="submit" :disabled="anyActionRunning || !options.teamMlbId || !options.snapshotOn">
        {{ runningTask === 'mlb_roster_snapshots_sync' ? 'Retrieving snapshots…' : 'Retrieve and store snapshots' }}
      </button>
      <button class="admin-button admin-button--secondary" type="button" :disabled="anyActionRunning || !options.teamMlbId || !options.snapshotOn" @click="emit('load')">
        {{ loading ? 'Loading snapshots…' : 'View stored snapshots' }}
      </button>
    </form>

    <p v-if="error" class="admin-message admin-message--error" role="alert">{{ error }}</p>
    <p v-else-if="!loading && !snapshots.length" class="roster-snapshot-empty">Select a team and date to retrieve new snapshots or view snapshots already stored.</p>
    <div v-else class="roster-snapshot-grid">
      <article v-for="snapshot in selectedSnapshots" :key="snapshot?.roster_type || 'missing'" class="roster-snapshot-panel">
        <template v-if="snapshot">
          <header>
            <div><span>{{ snapshot.roster_type === 'active' ? 'Active roster' : '40-man roster' }}</span><small>{{ formatDate(snapshot.snapshot_on) }}</small></div>
            <strong>{{ snapshot.players.length }} players</strong>
          </header>
          <div class="roster-snapshot-table-wrap">
            <table>
              <thead><tr><th>#</th><th>Player</th><th>Pos</th><th>Status</th></tr></thead>
              <tbody>
                <tr v-for="player in snapshot.players" :key="player.mlb_id">
                  <td>{{ player.jersey_number || '—' }}</td>
                  <td>
                    <RouterLink v-if="player.player_id" :to="{ name: 'player-profile', params: { id: player.player_id } }">{{ player.full_name }}</RouterLink>
                    <span v-else>{{ player.full_name }}</span>
                  </td>
                  <td>{{ player.position_code || '—' }}</td>
                  <td>{{ player.status_description || 'Unknown' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <footer>Synced {{ formatTimestamp(snapshot.last_synced_at) }} · {{ snapshot.source_name }}</footer>
        </template>
        <p v-else>No snapshot is stored for this roster view.</p>
      </article>
    </div>
  </section>
</template>

<style>
.roster-snapshot-workspace { margin-top: 1.25rem; padding: 1.35rem; border: 1px solid rgba(16,38,61,.12); border-radius: 20px; background: rgba(255,252,244,.86); }
.roster-snapshot-workspace > .admin-card__hint { margin: .6rem 0 1rem; }
.roster-snapshot-controls { display: grid; gap: .75rem; grid-template-columns: minmax(220px, 1.4fr) minmax(170px, .8fr) auto auto; align-items: end; }
.roster-snapshot-controls label { display: flex; flex-direction: column; gap: .35rem; }
.roster-snapshot-controls label > span { color: #465662; font-size: .72rem; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; }
.roster-snapshot-controls input, .roster-snapshot-controls select { width: 100%; min-height: 42px; color: #8f2d24; border-color: rgba(143,45,36,.2); background: #f7e7e3; }
.roster-snapshot-empty { margin-top: 1rem; padding: 1rem; border-radius: 12px; color: #61707b; background: rgba(231,237,241,.7); }
.roster-snapshot-grid { display: grid; gap: 1rem; grid-template-columns: repeat(2, minmax(0, 1fr)); margin-top: 1.25rem; }
.roster-snapshot-panel { min-width: 0; overflow: hidden; border: 1px solid rgba(16,38,61,.12); border-radius: 16px; background: #fffdf7; }
.roster-snapshot-panel > header { display: flex; justify-content: space-between; gap: 1rem; align-items: center; padding: .85rem 1rem; color: #10263d; background: #e7edf1; }
.roster-snapshot-panel > header div { display: flex; flex-direction: column; }
.roster-snapshot-panel > header span { font-weight: 900; }
.roster-snapshot-panel > header small, .roster-snapshot-panel > footer { color: #61707b; font-size: .72rem; }
.roster-snapshot-table-wrap { max-height: 430px; overflow: auto; }
.roster-snapshot-panel table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.roster-snapshot-panel th, .roster-snapshot-panel td { padding: .62rem .7rem; border-bottom: 1px solid rgba(16,38,61,.08); text-align: left; }
.roster-snapshot-panel th { position: sticky; top: 0; color: #61707b; background: #fffdf7; font-size: .66rem; letter-spacing: .05em; text-transform: uppercase; }
.roster-snapshot-panel a { color: #8f2d24; font-weight: 800; }
.roster-snapshot-panel > footer, .roster-snapshot-panel > p { padding: .75rem 1rem; }
@media (max-width: 1000px) { .roster-snapshot-controls { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 680px) { .roster-snapshot-controls, .roster-snapshot-grid { grid-template-columns: 1fr; } }
</style>
