<script setup>
import { inject } from 'vue'

const {
  player, careerTableRows, titleize, careerRangeLabel, formatBaseballStatValue,
} = inject('player-profile-context')
</script>

<template>
  <section
    v-if="player && player.careerOverview"
    id="player-profile-panel-overview"
    class="profile-stat-table profile-career-table"
    role="tabpanel"
    aria-labelledby="player-profile-tab-overview"
  >
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">Career ledger</p>
        <h2>{{ titleize(player.careerOverview.category) }} by season</h2>
      </div>
      <span>{{ careerRangeLabel }}</span>
    </header>

    <div v-if="player.careerOverview.seasons.length" class="career-table-wrap" data-test="career-season-table">
      <table class="career-table">
        <thead>
          <tr>
            <th class="career-table__season">Season</th>
            <th class="career-table__team">Team</th>
            <th v-for="column in player.careerOverview.columns" :key="column.key" class="career-table__stat">
              {{ column.label }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="seasonRow in careerTableRows"
            :key="`${seasonRow.season}-${seasonRow.teamLabel}`"
            :class="{ 'career-table__season-total': seasonRow.isSeasonTotal }"
          >
            <th class="career-table__season">{{ seasonRow.season }}</th>
            <td class="career-table__team">{{ seasonRow.teamLabel }}</td>
            <td v-for="column in player.careerOverview.columns" :key="column.key" class="career-table__stat">
              {{ formatBaseballStatValue(column.key, seasonRow.statValues[column.key]) }}
            </td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <th class="career-table__season">Career</th>
            <td class="career-table__team">Total</td>
            <td v-for="column in player.careerOverview.columns" :key="column.key" class="career-table__stat">
              {{ formatBaseballStatValue(column.key, player.careerOverview.statValues[column.key]) }}
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
    <p v-else class="profile-empty">No season statistics have been imported for this player yet.</p>
  </section>
</template>

