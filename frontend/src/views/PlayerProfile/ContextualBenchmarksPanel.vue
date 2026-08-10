<script setup>
import { computed, inject } from 'vue'

const {
  player, titleize, contextualMetricLabel, contextualValue, peerAverage, peerLabel,
  percentileStyle, benchmarkPeriodLabel,
} = inject('player-profile-context')

const metricOrder = [
  'average_exit_velocity',
  'maximum_exit_velocity',
  'barrel_percentage',
  'hard_hit_percentage',
  'average_bat_speed',
  'ops',
  'batter_whiff_percentage',
  'batter_chase_percentage',
]

const benchmarkMetrics = computed(() => [...player.value.contextualBenchmarks.metrics]
  .sort((left, right) => {
    const leftIndex = metricOrder.indexOf(left.metricKey)
    const rightIndex = metricOrder.indexOf(right.metricKey)
    return (leftIndex === -1 ? metricOrder.length : leftIndex) - (rightIndex === -1 ? metricOrder.length : rightIndex)
  }))
</script>

<template>
  <section class="profile-panel contextual-panel" data-test="contextual-benchmarks">
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">League Context</p>
        <h2>Benchmarks & percentiles</h2>
      </div>
      <span>{{ benchmarkPeriodLabel }}</span>
    </header>

    <div v-if="benchmarkMetrics.length" class="context-percentile-board">
      <div class="context-percentile-board__scale" aria-hidden="true">
        <span>Poor</span>
        <span>Average</span>
        <span>Great</span>
      </div>

      <div class="context-percentile-board__metrics">
        <article
          v-for="metric in benchmarkMetrics"
          :key="`${metric.metricKey}-${metric.dimensionValue || 'all'}`"
          class="context-percentile-row"
          :style="percentileStyle(metric.percentile)"
        >
          <div class="context-percentile-row__metric">
            <strong>{{ contextualMetricLabel(metric) }}</strong>
            <small>
              {{ titleize(metric.metricGroup) }} · MLB {{ contextualValue(metric.mlbAverage, metric.unit) }}
              <template v-if="peerAverage(metric) !== null && peerAverage(metric) !== undefined">
                · {{ peerLabel(metric) }} {{ contextualValue(peerAverage(metric), metric.unit) }}
              </template>
            </small>
          </div>

          <div
            class="context-percentile-row__gauge"
            role="img"
            :aria-label="`${contextualMetricLabel(metric)} percentile: ${Math.round(metric.percentile)}`"
          >
            <span class="context-percentile-row__fill"></span>
            <span class="percentile-pill">{{ Math.round(metric.percentile) }}</span>
          </div>

          <div class="context-percentile-row__value">
            <strong>{{ contextualValue(metric.rawValue, metric.unit) }}</strong>
            <small>{{ Number(metric.sampleSize || 0).toLocaleString() }} sample</small>
          </div>
        </article>
      </div>
    </div>
    <p v-else class="profile-empty">
      Benchmark context will appear after daily analytics have been calculated for multiple players.
    </p>
  </section>
</template>
