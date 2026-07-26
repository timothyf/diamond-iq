<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import PlayerComparisonPicker from '../components/PlayerComparisonPicker.vue'
import { usePlayerProfile } from '../composables/usePlayerProfile'
import { formatBaseballStatValue } from '../utils/baseballStatFormatting'

const route = useRoute()
const router = useRouter()
const leftId = ref(route.query.left ? String(route.query.left) : '')
const rightId = ref(route.query.right ? String(route.query.right) : '')
const { player: leftPlayer, loading: leftLoading, error: leftError } = usePlayerProfile(leftId)
const { player: rightPlayer, loading: rightLoading, error: rightError } = usePlayerProfile(rightId)

const ready = computed(() => Boolean(
  leftPlayer.value &&
  rightPlayer.value &&
  String(leftPlayer.value.id) !== String(rightPlayer.value.id)
))
const sameCategory = computed(() =>
  ready.value && leftPlayer.value.seasonOverview.category === rightPlayer.value.seasonOverview.category,
)
const seasonRows = computed(() => alignedRows('season'))
const careerRows = computed(() => alignedRows('career'))
const LOWER_IS_BETTER = {
  batting: new Set(['strikeouts', 'caughtstealing']),
  pitching: new Set(['l', 'era', 'hits', 'runs', 'er', 'homeruns', 'hitbypitch', 'baseonballs', 'whip', 'avg']),
}
const DECIMAL_STAT_KEYS = new Set([
  'avg', 'obp', 'slg', 'ops', 'era', 'whip', 'inningspitched', 'ip',
  'k/9', 'bb/9', 'k/bb', 'hr/9', 'h/9',
])

watch([leftId, rightId], () => {
  const query = {}
  if (leftId.value) query.left = leftId.value
  if (rightId.value) query.right = rightId.value
  router.replace({ name: 'player-comparison', query })
})

function alignedRows(scope) {
  if (!ready.value) return []
  const leftStats = scope === 'season' ? leftPlayer.value.seasonOverview.stats : leftPlayer.value.careerOverview.stats
  const rightStats = scope === 'season' ? rightPlayer.value.seasonOverview.stats : rightPlayer.value.careerOverview.stats
  const definitions = new Map()
  for (const stat of [...leftStats, ...rightStats]) {
    if (!definitions.has(stat.key)) definitions.set(stat.key, stat.label)
  }
  const leftValues = Object.fromEntries(leftStats.map((stat) => [stat.key, stat.value]))
  const rightValues = Object.fromEntries(rightStats.map((stat) => [stat.key, stat.value]))
  return [...definitions].map(([key, label]) => ({ key, label, left: leftValues[key], right: rightValues[key] }))
}

function selectPlayer(side, player) {
  if (side === 'left') leftId.value = String(player.id)
  else rightId.value = String(player.id)
}

function clearPlayer(side) {
  if (side === 'left') leftId.value = ''
  else rightId.value = ''
}

function statValue(key, value) {
  if (value === null || value === undefined) return '—'

  const number = Number(value)
  const normalizedKey = String(key).trim().toLowerCase()
  if (!DECIMAL_STAT_KEYS.has(normalizedKey) && Number.isInteger(number)) {
    return number.toLocaleString('en-US')
  }

  return formatBaseballStatValue(key, value)
}

function comparisonClass(row, side, scope) {
  const left = Number(row.left)
  const right = Number(row.right)
  if (!Number.isFinite(left) || !Number.isFinite(right) || left === right) return ''

  const leftCategory = scope === 'season'
    ? leftPlayer.value?.seasonOverview.category
    : leftPlayer.value?.careerOverview.category
  const rightCategory = scope === 'season'
    ? rightPlayer.value?.seasonOverview.category
    : rightPlayer.value?.careerOverview.category
  if (!leftCategory || leftCategory !== rightCategory) return ''

  const lowerIsBetter = LOWER_IS_BETTER[leftCategory]?.has(String(row.key).toLowerCase()) === true
  const leftIsBetter = lowerIsBetter ? left < right : left > right
  const sideIsBetter = side === 'left' ? leftIsBetter : !leftIsBetter
  return sideIsBetter ? 'is-better' : 'is-lesser'
}
</script>

<template>
  <main class="comparison-shell">
    <header class="comparison-hero">
      <p>Player intelligence</p>
      <h1>Side-by-side comparison</h1>
      <span>Select two players to align current-season and career performance.</span>
    </header>

    <section class="comparison-selectors" aria-label="Players to compare">
      <PlayerComparisonPicker label="Player A" :selected-player="leftPlayer" :excluded-player-id="rightId" @select="selectPlayer('left', $event)" @clear="clearPlayer('left')" />
      <div class="comparison-versus" aria-hidden="true">VS</div>
      <PlayerComparisonPicker label="Player B" :selected-player="rightPlayer" :excluded-player-id="leftId" @select="selectPlayer('right', $event)" @clear="clearPlayer('right')" />
    </section>

    <div v-if="leftLoading || rightLoading" class="comparison-state">Loading player profiles…</div>
    <div v-else-if="leftError && leftId || rightError && rightId" class="comparison-state comparison-state--error">{{ leftError || rightError }}</div>
    <section v-else-if="!ready" class="comparison-state">Choose two different players to begin the comparison.</section>

    <template v-else>
      <section class="comparison-identities" data-test="comparison-identities">
        <article v-for="player in [leftPlayer, rightPlayer]" :key="player.id">
          <RouterLink :to="{ name: 'player-profile', params: { id: player.id } }">{{ player.fullName }}</RouterLink>
          <span>{{ player.displayTeam?.name || player.team?.name || 'Team unavailable' }}</span>
          <small>{{ player.positions?.primary?.abbreviation || '—' }} · Age {{ player.profile?.age || '—' }}</small>
        </article>
      </section>

      <p v-if="!sameCategory" class="comparison-note">
        These players have different primary roles; unmatched statistics are shown as unavailable.
      </p>

      <section class="comparison-table-panel" data-test="season-comparison">
        <header><div><p>Current production</p><h2>Season comparison</h2></div><span>{{ leftPlayer.seasonOverview.season || '—' }} / {{ rightPlayer.seasonOverview.season || '—' }}</span></header>
        <table>
          <thead><tr><th>{{ leftPlayer.fullName }}</th><th>Statistic</th><th>{{ rightPlayer.fullName }}</th></tr></thead>
          <tbody>
            <tr v-for="row in seasonRows" :key="row.key" :data-test="`season-stat-${row.key}`">
              <td :class="comparisonClass(row, 'left', 'season')">{{ statValue(row.key, row.left) }}</td>
              <th>{{ row.label }}</th>
              <td :class="comparisonClass(row, 'right', 'season')">{{ statValue(row.key, row.right) }}</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="comparison-table-panel" data-test="career-comparison">
        <header><div><p>Career ledger</p><h2>Career comparison</h2></div><span>{{ leftPlayer.careerOverview.seasonCount }} / {{ rightPlayer.careerOverview.seasonCount }} seasons</span></header>
        <table>
          <thead><tr><th>{{ leftPlayer.fullName }}</th><th>Statistic</th><th>{{ rightPlayer.fullName }}</th></tr></thead>
          <tbody>
            <tr v-for="row in careerRows" :key="row.key" :data-test="`career-stat-${row.key}`">
              <td :class="comparisonClass(row, 'left', 'career')">{{ statValue(row.key, row.left) }}</td>
              <th>{{ row.label }}</th>
              <td :class="comparisonClass(row, 'right', 'career')">{{ statValue(row.key, row.right) }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
  </main>
</template>

<style scoped>
.comparison-shell { width: min(1180px,calc(100% - 2rem)); margin: 0 auto; padding: 2.2rem 0 5rem; color: #10263d; }
.comparison-hero { padding: 2rem; border-radius: 28px; color: #fffaf0; background: linear-gradient(120deg,#10263d,#1f506b); }
.comparison-hero p,.comparison-table-panel header p { margin: 0; color: #e8b276; font-size: .7rem; font-weight: 900; letter-spacing: .14em; text-transform: uppercase; }
.comparison-hero h1 { margin: .25rem 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: clamp(2.8rem,6vw,5rem); line-height: .95; text-transform: uppercase; }
.comparison-hero span { color: #d4dde2; }
.comparison-selectors { display: grid; grid-template-columns: minmax(0,1fr) 54px minmax(0,1fr); gap: .75rem; align-items: center; margin-top: 1rem; }
.comparison-versus { display: grid; width: 48px; height: 48px; place-items: center; border-radius: 50%; color: #fff; background: #a93627; font-weight: 900; }
.comparison-state { margin-top: 1rem; padding: 2rem; border: 1px dashed rgba(16,38,61,.2); border-radius: 18px; color: #687781; background: rgba(255,252,245,.75); text-align: center; }
.comparison-state--error { color: #8f2d24; }
.comparison-identities { display: grid; grid-template-columns: 1fr 1fr; gap: .8rem; margin-top: 1rem; }
.comparison-identities article { padding: 1rem; border-radius: 16px; color: #fffaf0; background: #10263d; }
.comparison-identities article:last-child { text-align: right; }
.comparison-identities a,.comparison-identities span,.comparison-identities small { display: block; }
.comparison-identities a { color: inherit; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.55rem; font-weight: 900; text-transform: uppercase; }
.comparison-identities span { margin-top: .15rem; color: #d5dde2; }
.comparison-identities small { margin-top: .3rem; color: #9fb0bc; }
.comparison-note { padding: .75rem 1rem; border-radius: 12px; color: #71521f; background: #fbefce; font-size: .78rem; }
.comparison-table-panel { margin-top: 1rem; padding: 1rem; border: 1px solid rgba(16,38,61,.12); border-radius: 20px; background: rgba(255,252,245,.84); }
.comparison-table-panel > header { display: flex; justify-content: space-between; gap: 1rem; align-items: end; padding-bottom: .8rem; }
.comparison-table-panel h2 { margin: .15rem 0 0; font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.8rem; text-transform: uppercase; }
.comparison-table-panel header > span { color: #6d7a83; font-size: .72rem; font-weight: 800; }
.comparison-table-panel table { width: 100%; border-collapse: collapse; }
.comparison-table-panel th,.comparison-table-panel td { width: 33.333%; padding: .7rem; border-top: 1px solid rgba(16,38,61,.09); text-align: center; }
.comparison-table-panel thead th { color: #6d7a83; font-size: .7rem; text-transform: uppercase; }
.comparison-table-panel tbody td { font-family: 'Avenir Next Condensed',sans-serif; font-size: 1.2rem; font-weight: 900; }
.comparison-table-panel tbody td.is-better { color: #17613d; background: rgba(42,145,91,.12); }
.comparison-table-panel tbody td.is-lesser { color: #982f27; background: rgba(181,61,48,.1); }
.comparison-table-panel tbody th { color: #61717d; font-size: .72rem; text-transform: uppercase; }
@media (max-width: 650px) { .comparison-selectors { grid-template-columns: 1fr; } .comparison-versus { margin: 0 auto; } .comparison-table-panel { overflow-x: auto; } .comparison-table-panel table { min-width: 560px; } }
</style>
