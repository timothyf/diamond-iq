<script setup>
import { inject } from 'vue'

const {
  player, titleize, contextualMetricLabel, contextualValue, peerAverage, peerLabel,
  percentileStyle, signedContextualValue, benchmarkPeriodLabel,
} = inject('player-profile-context')
</script>

<template>
  <section class="profile-panel contextual-panel" data-test="contextual-benchmarks">
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">P1.5 context</p>
        <h2>Benchmarks & percentiles</h2>
      </div>
      <span>{{ benchmarkPeriodLabel }}</span>
    </header>

    <div v-if="player.contextualBenchmarks.metrics.length" class="context-table-wrap">
      <table class="context-table">
        <thead>
          <tr>
            <th>Metric</th>
            <th>Player</th>
            <th>MLB average</th>
            <th>Position / role</th>
            <th>Percentile</th>
            <th>Previous-period change</th>
            <th>Sample</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="metric in player.contextualBenchmarks.metrics" :key="`${metric.metricKey}-${metric.dimensionValue || 'all'}`">
            <th>
              <strong>{{ contextualMetricLabel(metric) }}</strong>
              <small>{{ titleize(metric.metricGroup) }}</small>
            </th>
            <td><strong>{{ contextualValue(metric.rawValue, metric.unit) }}</strong></td>
            <td>
              {{ contextualValue(metric.mlbAverage, metric.unit) }}
              <small>{{ metric.mlbPlayerCount }} players</small>
            </td>
            <td>
              {{ contextualValue(peerAverage(metric), metric.unit) }}
              <small>{{ peerLabel(metric) }}</small>
            </td>
            <td>
              <span class="percentile-pill" :style="percentileStyle(metric.percentile)">
                P{{ Math.round(metric.percentile) }}
              </span>
            </td>
            <td>
              {{ signedContextualValue(metric.changeValue, metric.unit) }}
              <small v-if="metric.previousValue !== null && metric.previousValue !== undefined">
                from {{ contextualValue(metric.previousValue, metric.unit) }}
              </small>
            </td>
            <td>{{ Number(metric.sampleSize || 0).toLocaleString() }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else class="profile-empty">
      Benchmark context will appear after daily analytics have been calculated for multiple players.
    </p>
  </section>
</template>

