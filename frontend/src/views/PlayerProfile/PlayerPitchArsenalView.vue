<script setup>
import { computed, inject } from 'vue'
import ContextualBenchmarksPanel from './ContextualBenchmarksPanel.vue'

const {
  player, rangePresets, tabAnalysisOptions, updateTabAnalysisPeriod, PlayerAnalysisPeriodControls,
} = inject('player-profile-context')
const pitches = computed(() => player.value?.pitchArsenal?.pitches || [])

const columns = [
  ['usagePercentage', 'Usage%', 'percent'],
  ['pitchCount', 'Number of pitches', 'count'],
  ['averageVelocity', 'Average velocity', 'velocity'],
  ['maximumVelocity', 'Maximum velocity', 'velocity'],
  ['spinRate', 'Spin rate', 'integer'],
  ['activeSpin', 'Active spin', 'percent'],
  ['verticalMovement', 'Vertical movement', 'movement'],
  ['horizontalMovement', 'Horizontal movement', 'movement'],
  ['zonePercentage', 'Zone%', 'percent'],
  ['chasePercentage', 'Chase%', 'percent'],
  ['whiffPercentage', 'Whiff%', 'percent'],
  ['hardHitPercentage', 'Hard-hit%', 'percent'],
  ['runValue', 'Run value', 'run'],
]

function formatValue(value, unit) {
  if (value === null || value === undefined) return '—'
  if (unit === 'count') return Number(value).toLocaleString()
  if (unit === 'percent') return `${Number(value).toFixed(1)}%`
  if (unit === 'velocity') return `${Number(value).toFixed(1)} mph`
  if (unit === 'movement') return `${Number(value).toFixed(1)} in`
  if (unit === 'integer') return Math.round(Number(value)).toLocaleString()
  return Number(value).toFixed(2)
}
</script>

<template>
  <section id="player-page-panel-pitch-arsenal" class="profile-page-content" data-test="player-page-panel-pitch-arsenal" role="tabpanel" aria-labelledby="player-page-tab-pitch-arsenal">
    <component
      :is="PlayerAnalysisPeriodControls"
      :options="tabAnalysisOptions['pitch-arsenal']"
      :range-presets="rangePresets"
      label="Pitch arsenal analysis period"
      @change="updateTabAnalysisPeriod('pitch-arsenal', $event)"
    />
    <header class="profile-page-content__header">
      <div>
        <p class="eyebrow">Pitcher analysis</p>
        <h2>Pitch arsenal and effectiveness</h2>
      </div>
      <span v-if="player?.pitchArsenal?.available">{{ pitches.reduce((total, pitch) => total + pitch.pitchCount, 0).toLocaleString() }} pitches</span>
    </header>

    <div v-if="pitches.length" class="pitch-arsenal-table-wrap">
      <table class="pitch-arsenal-table">
        <thead>
          <tr>
            <th>Pitch type</th>
            <th v-for="([, label]) in columns" :key="label">{{ label }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="pitch in pitches" :key="pitch.pitchType">
            <th>{{ pitch.pitchName }} <small>{{ pitch.pitchType }}</small></th>
            <td v-for="([key, , unit]) in columns" :key="key">{{ formatValue(pitch[key], unit) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else class="empty-state">Pitch-level arsenal data is not available for this pitcher.</p>

    <ContextualBenchmarksPanel
      :metric-keys="['pitch_usage_percentage']"
      title="Pitch usage benchmarks & percentiles"
      data-test="pitch-usage-percentiles"
      empty-message="Pitch-usage benchmark context will appear after daily analytics have been calculated for multiple pitchers."
    />
  </section>
</template>
