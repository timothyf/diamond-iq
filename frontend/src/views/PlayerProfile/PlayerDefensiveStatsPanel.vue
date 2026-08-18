<script setup>
import { inject } from 'vue'

const { player, defensiveStats, sectionLoading, displayValue } = inject('player-profile-context')

function formatGames(value) {
  if (value === null || value === undefined || value === '') return '—'

  const number = Number(value)
  return Number.isFinite(number) ? Math.round(number).toString() : '—'
}
function formatInnings(value) {
  if (value === null || value === undefined || value === '') return '—'

  const number = Number(value)
  return Number.isFinite(number) ? number.toFixed(1) : '—'
}


function formatFieldingPercentage(value) {
  if (value === null || value === undefined || value === '') return '—'

  const number = Number(value)
  return Number.isFinite(number) ? number.toFixed(3) : '—'
}

function formatRuns(value) {
  if (value === null || value === undefined || value === '') return '—'

  const number = Number(value)
  return Number.isFinite(number) ? number.toFixed(2) : '—'
}
</script>

<template>
  <section
    v-if="player && defensiveStats"
    id="player-profile-panel-defensive-stats"
    class="profile-stat-table defensive-stats-panel"
    role="tabpanel"
    aria-labelledby="player-profile-tab-defensive-stats"
    data-test="defensive-stats-panel"
  >
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">Defense and position coverage</p>
        <h2>Defensive Stats</h2>
      </div>
      <span>{{ defensiveStats.season || 'Career' }}</span>
    </header>

    <p v-if="sectionLoading('defensive_stats').value" class="profile-empty">Loading defensive statistics…</p>
    <template v-else>
      <div v-if="defensiveStats.seasons.length" class="advanced-table-wrap">
        <table class="advanced-table">
          <thead>
            <tr>
              <th>Season</th>
              <th>Position</th>
              <th>Games</th>
              <th>Innings</th>
              <th>Fielding percentage</th>
              <th>Defensive Runs Saved</th>
              <th>Outs Above Average</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="season in defensiveStats.seasons" :key="season.season">
              <tr
                v-for="positionRow in season.positions"
                :key="`${season.season}-${positionRow.position}`"
                class="defensive-position-row"
              >
                <td>{{ season.season }}</td>
                <th scope="row">{{ positionRow.position }}</th>
                <td>{{ formatGames(positionRow.games) }}</td>
                <td>{{ formatInnings(positionRow.innings) }}</td>
                <td>{{ formatFieldingPercentage(positionRow.fieldingPercentage) }}</td>
                <td>{{ formatRuns(positionRow.defensiveRunsSaved) }}</td>
                <td>{{ formatRuns(positionRow.outsAboveAverage) }}</td>
              </tr>
              <tr class="advanced-table__season-total">
                <th scope="row">{{ season.season }}</th>
                <th scope="row">Season total</th>
                <td>{{ formatGames(season.games) }}</td>
                <td>—</td>
                <td>{{ formatFieldingPercentage(season.fieldingPercentage) }}</td>
                <td>{{ formatRuns(season.defensiveRunsSaved) }}</td>
                <td>{{ formatRuns(season.outsAboveAverage) }}</td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
      <p v-else class="profile-empty">No defensive statistics have been imported for this player yet.</p>
    </template>
  </section>
</template>
