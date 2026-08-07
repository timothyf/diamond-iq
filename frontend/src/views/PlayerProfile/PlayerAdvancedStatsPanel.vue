<script setup>
import { inject } from 'vue'

const {
  player, sectionLoading, careerRangeLabel, advancedTableRows, advancedStatValue,
} = inject('player-profile-context')
</script>

<template>
  <section
    v-if="player && player.advancedStats"
    id="player-profile-panel-advanced-stats"
    class="profile-stat-table advanced-stats-panel"
    role="tabpanel"
    aria-labelledby="player-profile-tab-advanced-stats"
    data-test="advanced-stats-panel"
  >
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">Plate-discipline & production</p>
        <h2>Advanced Stats</h2>
      </div>
      <span>{{ careerRangeLabel }}</span>
    </header>

    <p v-if="sectionLoading('advanced_stats').value" class="profile-empty">Loading advanced statistics…</p>
    <div v-else-if="player.advancedStats.seasons.length" class="advanced-stat-groups">
      <article
        v-for="group in player.advancedStats.groups"
        :key="group.key"
        class="advanced-stat-group"
        :data-test="`advanced-stat-group-${group.key}`"
      >
        <h3>{{ group.label }}</h3>
        <p v-if="group.description" class="advanced-stat-group__description">{{ group.description }}</p>
        <div class="advanced-table-wrap">
          <table class="advanced-table">
            <thead>
              <tr>
                <th>Season</th>
                <th>Team</th>
                <th v-for="column in group.columns" :key="column.key" class="advanced-table__metric-heading">
                  {{ column.label }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="seasonRow in advancedTableRows"
                :key="`${group.key}-${seasonRow.season}-${seasonRow.teamLabel}`"
                :class="{ 'advanced-table__season-total': seasonRow.isSeasonTotal }"
              >
                <th>{{ seasonRow.season }}</th>
                <td>{{ seasonRow.teamLabel }}</td>
                <td v-for="column in group.columns" :key="column.key">
                  {{ advancedStatValue(column, seasonRow.values[column.key]) }}
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <th>Career</th>
                <td>Total</td>
                <td v-for="column in group.columns" :key="column.key">
                  {{ advancedStatValue(column, player.advancedStats.career.values[column.key]) }}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      </article>
    </div>
    <p v-else class="profile-empty">No advanced statistics have been imported for this player yet.</p>
  </section>
</template>

