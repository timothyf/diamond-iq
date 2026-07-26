<script setup>
import { onMounted, ref, watch } from 'vue'

const props = defineProps({ scenarioId: { type: [String, Number], required: true } })
const scenario = ref(null)
const error = ref('')

async function load() {
  error.value = ''
  try {
    const response = await fetch(`/api/lineup_scenarios/${encodeURIComponent(props.scenarioId)}`, { headers: { Accept: 'application/json' } })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.message || 'Unable to load lineup scenario.')
    scenario.value = payload.data
  } catch (requestError) {
    error.value = requestError.message
  }
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(new Date(`${value}T12:00:00`))
}

onMounted(load)
watch(() => props.scenarioId, load)
</script>

<template>
  <main class="scenario-shell">
    <p v-if="error" class="scenario-state">{{ error }}</p>
    <template v-else-if="scenario">
      <RouterLink :to="{ name: 'team-profile', params: { id: scenario.team_id } }">← Back to team</RouterLink>
      <section>
        <p>Saved lineup scenario · constraint validated</p>
        <h1>{{ scenario.name }}</h1>
        <span>{{ formatDate(scenario.scenario_date) }}</span>
        <p v-if="scenario.notes" class="scenario-notes">{{ scenario.notes }}</p>
        <section class="scenario-score" data-test="scenario-score">
          <header><strong>Transparent evaluation</strong><b>{{ scenario.total_score ?? '—' }}/100</b></header>
          <p>
            Opponent {{ scenario.score_breakdown?.opponent ?? '—' }} ·
            Park {{ scenario.score_breakdown?.park ?? '—' }} ·
            Platoon {{ scenario.score_breakdown?.platoon ?? '—' }} ·
            Recent {{ scenario.score_breakdown?.recent_performance ?? '—' }} ·
            Reliability {{ scenario.score_breakdown?.reliability ?? '—' }}
          </p>
          <small>Weights: 20% opponent · 15% park · 25% platoon · 20% recent · 20% reliability</small>
          <small>Inputs: {{ scenario.evaluation_inputs?.opponent || 'Opponent not specified' }} · {{ scenario.evaluation_inputs?.pitcher_hand || '—' }}HP · park {{ scenario.evaluation_inputs?.park_factor ?? '—' }}</small>
        </section>
        <table>
          <thead><tr><th>Order</th><th>Player</th><th>Defense</th></tr></thead>
          <tbody>
            <tr v-for="entry in scenario.entries" :key="entry.id">
              <th>{{ entry.batting_slot }}</th>
              <td><RouterLink :to="{ name: 'player-profile', params: { id: entry.player.id } }">{{ entry.player.full_name }}</RouterLink></td>
              <td>{{ entry.defensive_position }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
    <p v-else class="scenario-state">Loading lineup scenario…</p>
  </main>
</template>

<style scoped>
.scenario-shell { width: min(860px,calc(100% - 2rem)); min-height: calc(100vh - 74px); margin: 0 auto; padding: 2.5rem 0; color: #10263d; }
.scenario-shell > a { color: #8d392e; font-weight: 850; text-decoration: none; }
.scenario-shell section { margin-top: 1rem; padding: 2rem; border: 1px solid #d9d7ce; border-radius: 24px; background: #fffaf0; box-shadow: 0 16px 40px rgba(16,38,61,.08); }
.scenario-shell section > p:first-child { color: #a93627; font-size: .7rem; font-weight: 900; letter-spacing: .1em; text-transform: uppercase; }
h1 { margin: .3rem 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: clamp(2.5rem,7vw,5rem); line-height: .9; text-transform: uppercase; }
.scenario-notes { padding: .75rem; border-radius: 10px; background: #edf3ee; }
.scenario-score { margin-top: 1rem; padding: .9rem; border-radius: 14px; background: #edf3ee; }
.scenario-score header { display: flex; justify-content: space-between; gap: 1rem; }
.scenario-score b { color: #20543c; font-size: 1.2rem; }
.scenario-score p,.scenario-score small { display: block; margin: .35rem 0 0; color: #526572; font-size: .78rem; }
table { width: 100%; margin-top: 1.2rem; border-collapse: collapse; }
th,td { padding: .7rem; border-bottom: 1px solid #e4e1d9; text-align: left; }
thead { color: #68747e; font-size: .7rem; text-transform: uppercase; }
tbody th { color: #fffaf0; background: #173652; text-align: center; }
td a { color: #20543c; font-weight: 900; }
.scenario-state { padding-top: 4rem; text-align: center; }
</style>
