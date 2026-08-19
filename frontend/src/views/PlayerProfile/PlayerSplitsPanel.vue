<script setup>
import { inject } from 'vue'

const {
  player, sectionLoading, showBattingIndicators, batterSplitMetrics,
  batterSplitValue, showPitchingIndicators, pitcherSplitMetrics, pitcherSplitValue, formatDate,
} = inject('player-profile-context')
</script>

<template>
  <section
    v-if="player && player.analysis && player.batterSplits && player.pitcherSplits"
    id="player-profile-panel-splits"
    class="profile-stat-table batter-splits-panel"
    role="tabpanel"
    aria-labelledby="player-profile-tab-splits"
    data-test="batter-splits"
  >
    <header class="profile-section-heading">
      <div>
        <p class="eyebrow">Matchup context</p>
        <h2>Splits</h2>
      </div>
      <span>Pitch-level sample · {{ formatDate(player.analysis?.range?.startDate) }} — {{ formatDate(player.analysis?.range?.endDate) }}</span>
    </header>

    <p v-if="sectionLoading('splits').value" class="profile-empty">Loading split statistics…</p>
    <div v-else-if="showBattingIndicators && player.batterSplits.available" class="split-role">
      <h3>As batter</h3>
      <div class="split-table-wrap">
        <table class="split-table">
          <thead>
            <tr>
              <th>Split</th>
              <th v-for="metric in batterSplitMetrics" :key="metric[0]">{{ metric[1] }}</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="dimension in player.batterSplits.dimensions" :key="dimension.key">
              <tr v-if="dimension.options?.length" class="split-category-row">
                <th :colspan="batterSplitMetrics.length + 1">{{ dimension.label }}</th>
              </tr>
              <tr v-for="option in dimension.options" :key="`${dimension.key}-${option.value}`">
                <th>{{ option.label }}</th>
                <td v-for="metric in batterSplitMetrics" :key="metric[0]">
                  {{ batterSplitValue(option.metrics[metric[0]], metric[2]) }}
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </div>

    <div v-if="!sectionLoading('splits').value && showPitchingIndicators && player.pitcherSplits.available" class="split-role">
      <h3>As pitcher</h3>
      <div class="split-table-wrap">
        <table class="split-table">
          <thead>
            <tr>
              <th>Split</th>
              <th v-for="metric in pitcherSplitMetrics" :key="metric[0]">{{ metric[1] }}</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="dimension in player.pitcherSplits.dimensions" :key="dimension.key">
              <tr v-if="dimension.options?.length" class="split-category-row">
                <th :colspan="pitcherSplitMetrics.length + 1">{{ dimension.label }}</th>
              </tr>
              <tr v-for="option in dimension.options" :key="`${dimension.key}-${option.value}`">
                <th>{{ option.label }}</th>
                <td v-for="metric in pitcherSplitMetrics" :key="metric[0]">
                  {{ pitcherSplitValue(option.metrics[metric[0]], metric[2]) }}
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </div>

    <p v-if="!sectionLoading('splits').value && !(showBattingIndicators && player.batterSplits.available) && !(showPitchingIndicators && player.pitcherSplits.available)" class="profile-empty">
      Split data is available after pitch-level analytics have been calculated for this period.
    </p>
  </section>
</template>
