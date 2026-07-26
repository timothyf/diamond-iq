<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { formatTwoDecimalPitchingRate } from '../utils/baseballStatFormatting'

const props = defineProps({
  reportId: { type: [String, Number], required: true },
})

const report = ref(null)
const loading = ref(false)
const error = ref('')
const snapshot = computed(() => report.value?.snapshot || {})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const response = await fetch(`/api/opponent_reports/${encodeURIComponent(props.reportId)}`, {
      headers: { Accept: 'application/json' },
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.message || 'Unable to load opponent report.')
    report.value = payload.data
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    .format(new Date(`${value}T12:00:00`))
}

function formatTimestamp(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
  }).format(new Date(value))
}

function decimal(value, digits = 1) {
  const number = Number(value)
  return Number.isFinite(number) ? number.toFixed(digits) : '—'
}

function changeLabel(change) {
  const value = Number(change.change)
  if (!Number.isFinite(value)) return '—'
  return `${value > 0 ? '+' : ''}${value.toFixed(1)}${change.unit === 'mph' ? ' mph' : ' pts'}`
}

onMounted(load)
watch(() => props.reportId, load)
</script>

<template>
  <main class="report-shell">
    <div v-if="loading" class="report-state">Loading saved report…</div>
    <div v-else-if="error" class="report-state report-state--error">{{ error }}</div>
    <template v-else-if="report">
      <RouterLink class="report-back" :to="{ name: 'team-profile', params: { id: report.team.id } }">
        ← {{ report.team.name }}
      </RouterLink>

      <header class="report-hero">
        <div>
          <p>Opponent report · Saved snapshot</p>
          <h1>{{ report.title }}</h1>
          <span>{{ formatDate(report.series_starts_on) }} – {{ formatDate(report.series_ends_on) }}</span>
        </div>
        <div class="report-stamp">
          <small>Generated</small>
          <strong>{{ formatTimestamp(report.generated_at) }}</strong>
          <span>Data is preserved as of this time</span>
        </div>
      </header>

      <section class="report-panel report-series">
        <header><p>Series plan</p><h2>{{ snapshot.opponent?.name }}</h2></header>
        <div>
          <article v-for="game in snapshot.series || []" :key="game.id">
            <strong>{{ formatDate(game.official_date) }}</strong>
            <span>{{ game.venue_name || 'Venue TBD' }}</span>
            <small>
              {{ game.away_team?.abbreviation }} {{ game.away_probable_pitcher?.full_name || 'TBD' }}
              vs {{ game.home_team?.abbreviation }} {{ game.home_probable_pitcher?.full_name || 'TBD' }}
            </small>
          </article>
        </div>
      </section>

      <section class="report-panel">
        <header><p>Recent form</p><h2>Opponent performance</h2></header>
        <dl class="report-metrics">
          <div><dt>Record</dt><dd>{{ snapshot.recent_performance?.wins }}–{{ snapshot.recent_performance?.losses }}</dd></div>
          <div><dt>Runs / G</dt><dd>{{ decimal(snapshot.recent_performance?.runs_per_game, 2) }}</dd></div>
          <div><dt>OPS</dt><dd>{{ decimal(snapshot.recent_performance?.ops, 3) }}</dd></div>
          <div><dt>ERA</dt><dd>{{ formatTwoDecimalPitchingRate(snapshot.recent_performance?.era) }}</dd></div>
        </dl>
      </section>

      <section
        v-for="starter in snapshot.probable_starters || []"
        :key="starter.player.id"
        class="report-panel report-starter"
      >
        <header>
          <div><p>Pitcher plan</p><h2>{{ starter.player.full_name }}</h2></div>
          <span>{{ starter.throws || '—' }}HP · {{ starter.sample_size }} pitches</span>
        </header>
        <div class="report-columns">
          <div>
            <h3>Repertoire</h3>
            <table>
              <thead><tr><th>Pitch</th><th>Usage</th><th>Velo</th><th>Movement</th><th>Evidence</th></tr></thead>
              <tbody>
                <tr v-for="pitch in starter.repertoire" :key="pitch.pitch_type">
                  <th>{{ pitch.pitch_name }}</th>
                  <td>{{ decimal(pitch.usage_percentage) }}%</td>
                  <td>{{ decimal(pitch.average_velocity) }} mph</td>
                  <td>{{ decimal(pitch.horizontal_break) }} / {{ decimal(pitch.vertical_break) }} in</td>
                  <td>
                    <RouterLink
                      v-for="item in pitch.evidence || []"
                      :key="item.pitch_id"
                      :to="{ name: 'game-summary', params: { id: item.game_id }, hash: `#pitch-${item.pitch_id}` }"
                    >Pitch →</RouterLink>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <aside>
            <h3>Handedness</h3>
            <article v-for="split in starter.handedness_splits" :key="split.batter_hand">
              <strong>vs {{ split.batter_hand }}HB</strong>
              <span>{{ split.plate_appearances }} PA · {{ decimal(split.strikeout_rate) }}% K · {{ decimal(split.whiff_rate) }}% whiff</span>
              <RouterLink
                v-if="split.evidence?.[0]"
                :to="{ name: 'game-summary', params: { id: split.evidence[0].game_id }, hash: `#plate-appearance-${split.evidence[0].plate_appearance_id}` }"
              >Supporting PA →</RouterLink>
            </article>
            <h3>Recent changes</h3>
            <article v-for="change in starter.recent_changes" :key="change.key">
              <strong>{{ change.label }}</strong><span>{{ changeLabel(change) }}</span>
              <RouterLink
                v-if="change.evidence?.[0]"
                :to="{ name: 'game-summary', params: { id: change.evidence[0].game_id }, hash: `#pitch-${change.evidence[0].pitch_id}` }"
              >Supporting pitch →</RouterLink>
            </article>
          </aside>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.report-shell { min-height: calc(100vh - 74px); padding: 2.5rem 1.25rem 5rem; background: radial-gradient(circle at 85% 0,rgba(24,77,116,.2),transparent 30%),linear-gradient(180deg,#f7f1e3,#ead8b6); }
.report-shell > * { width: min(1280px,calc(100vw - 2.5rem)); margin-inline: auto; }
.report-back { display: inline-block; width: auto; margin-bottom: 1rem; color: #6d2a25; font-weight: 800; text-decoration: none; }
.report-hero,.report-panel { border: 1px solid rgba(16,38,61,.13); border-radius: 24px; background: rgba(255,252,244,.94); box-shadow: 0 18px 45px rgba(64,43,20,.1); }
.report-hero { display: flex; justify-content: space-between; gap: 2rem; padding: 2rem; color: #fffaf0; background: #10263d; }
.report-hero p,.report-panel > header p { margin: 0 0 .3rem; color: #b79569; font-size: .7rem; font-weight: 900; letter-spacing: .1em; text-transform: uppercase; }
.report-hero h1,.report-panel h2 { font-family: 'Avenir Next Condensed',sans-serif; text-transform: uppercase; }
.report-hero h1 { font-size: clamp(2rem,5vw,4.5rem); line-height: .95; }
.report-hero span { color: #c8d3da; }
.report-stamp { align-self: center; padding: 1rem; border: 1px solid rgba(255,255,255,.16); border-radius: 16px; text-align: right; }
.report-stamp small,.report-stamp strong,.report-stamp span { display: block; }
.report-stamp small { color: #b79569; text-transform: uppercase; }
.report-stamp span { margin-top: .2rem; font-size: .7rem; }
.report-panel { margin-top: 1rem; padding: 1.4rem; }
.report-panel > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; margin-bottom: 1rem; }
.report-panel h2 { color: #10263d; font-size: 2rem; }
.report-series > div,.report-metrics { display: grid; grid-template-columns: repeat(auto-fit,minmax(180px,1fr)); gap: .7rem; }
.report-series article,.report-metrics div,.report-columns aside article { padding: .8rem; border-radius: 14px; background: rgba(16,38,61,.05); }
.report-series strong,.report-series span,.report-series small { display: block; }
.report-series span,.report-series small { margin-top: .2rem; color: #667680; }
.report-metrics dt { color: #71808c; font-size: .7rem; font-weight: 900; text-transform: uppercase; }
.report-metrics dd { margin-top: .25rem; color: #8d392e; font-size: 1.5rem; font-weight: 900; }
.report-columns { display: grid; grid-template-columns: minmax(0,1.7fr) minmax(260px,.7fr); gap: 1rem; }
.report-columns h3 { margin: .4rem 0 .6rem; color: #173652; font-size: .75rem; letter-spacing: .08em; text-transform: uppercase; }
table { width: 100%; border-collapse: collapse; font-size: .78rem; }
th,td { padding: .65rem; border-bottom: 1px solid rgba(16,38,61,.1); text-align: right; }
th:first-child { text-align: left; }
thead { color: #697784; background: #e7edf1; }
td a,.report-columns aside a { display: block; color: #8d392e; font-size: .68rem; font-weight: 850; }
.report-columns aside { display: grid; align-content: start; gap: .5rem; }
.report-columns aside article strong,.report-columns aside article span { display: block; }
.report-columns aside article span { margin: .2rem 0; color: #667680; font-size: .75rem; }
.report-state { display: grid; min-height: 50vh; place-items: center; }
.report-state--error { color: #7d291f; }
@media (max-width: 760px) { .report-hero { flex-direction: column; } .report-stamp { align-self: stretch; text-align: left; } .report-columns { grid-template-columns: 1fr; } }
</style>
