<script setup>
import { inject } from 'vue'


const {
  player, selectedProfileTab, profileTabs, sectionLoading, careerTableRows, titleize, careerRangeLabel,
  formatBaseballStatValue, advancedTableRows, advancedStatValue, showBattingIndicators, batterSplitDimension,
  batterSplitMetrics, batterSplitValue, selectedBatterSplit, showPitchingIndicators, pitcherSplitDimension,
  pitcherSplitMetrics, pitcherSplitValue, selectedPitcherSplit, formatDate, similarityValue,
  contextualMetricLabel, contextualValue, peerAverage, peerLabel, percentileStyle, signedContextualValue,
  benchmarkPeriodLabel, battingMetrics, pitchingMetrics, teamHistoryLabel, SavedAnalysisControls,
  savedAnalysisState, savedAnalysisUrl, openSavedAnalysis, analysisOptions, rangePresets, selectPreset,
  customStartDate, customEndDate, applyCustomRange, updateWindow, trendEventTone, trendEventLabel,
  trendEventTitle, trendEventValue, comparisonMetrics, trendCharts, PlayerTrendChart,
} = inject('player-profile-context')
</script>

<template>
  <div id="player-page-panel-performance-trends" class="profile-page-content" role="tabpanel" aria-labelledby="player-page-tab-performance-trends">        <SavedAnalysisControls
          analysis-type="player_date_range"
          :state="savedAnalysisState"
          :reproducible-url="savedAnalysisUrl"
          compact
          @apply="openSavedAnalysis"
        />

        <section class="profile-panel analysis-controls" data-test="player-date-range-controls">
          <div>
            <p class="eyebrow">Analysis period</p>
            <div class="range-presets" role="group" aria-label="Player analysis range">
              <button v-for="preset in rangePresets" :key="preset.value" type="button"
                :class="{ 'is-active': analysisOptions.range === preset.value }" @click="selectPreset(preset.value)">
                {{ preset.label }}
              </button>
            </div>
          </div>
          <div class="custom-range">
            <label>From <input v-model="customStartDate" type="date" /></label>
            <label>Through <input v-model="customEndDate" type="date" /></label>
            <button type="button" :disabled="!customStartDate || !customEndDate" @click="applyCustomRange">Apply custom</button>
          </div>
          <div class="rolling-window-controls">
            <label>
              Batting window
              <select :value="analysisOptions.paWindow" @change="updateWindow('paWindow', $event.target.value)">
                <option :value="25">25 PA</option>
                <option :value="50">50 PA</option>
                <option :value="100">100 PA</option>
              </select>
            </label>
            <label>
              Pitching window
              <select :value="analysisOptions.pitchWindow" @change="updateWindow('pitchWindow', $event.target.value)">
                <option :value="50">50 pitches</option>
                <option :value="100">100 pitches</option>
                <option :value="250">250 pitches</option>
              </select>
            </label>
          </div>
        </section>

        <section class="profile-panel trend-panel" data-test="player-trends">
          <header class="profile-section-heading">
            <div>
              <p class="eyebrow">Rolling intelligence</p>
              <h2>Performance trends</h2>
            </div>
            <span v-if="player.analysis?.range?.startDate">
              {{ formatDate(player.analysis.range.startDate) }} — {{ formatDate(player.analysis.range.endDate) }}
            </span>
          </header>

          <div v-if="player.trendEvents?.events?.length" class="trend-events" data-test="trend-events">
            <article v-for="event in player.trendEvents.events" :key="event.id"
              :class="[
                `trend-event--${trendEventTone(event)}`,
                `trend-event--${event.severity}`,
                { 'trend-event--resolved': event.status === 'resolved' },
              ]">
              <header>
                <span>{{ trendEventLabel(event) }} · {{ event.status }}</span>
                <time :datetime="event.onsetDate">Onset {{ formatDate(event.onsetDate) }}</time>
              </header>
              <strong>{{ trendEventTitle(event) }}</strong>
              <p>
                {{ trendEventValue(event, event.baselineValue) }} → {{ trendEventValue(event, event.currentValue) }}
                ({{ signedContextualValue(event.changeValue, event.unit === 'mph' ? 'mph' : 'percent') }})
              </p>
              <small>
                Sample {{ event.sampleSize }} vs {{ event.baselineSampleSize }} baseline ·
                {{ event.supportingPitches.length }} supporting pitches
              </small>
            </article>
          </div>

          <div class="period-comparison">
            <article v-for="metric in comparisonMetrics" :key="metric.key">
              <span>{{ metric.label }}</span>
              <strong>{{ contextualValue(metric.current, metric.unit) }}</strong>
              <small>
                Previous {{ contextualValue(metric.previous, metric.unit) }} ·
                {{ signedContextualValue(metric.change, metric.unit) }}
              </small>
            </article>
          </div>

          <div v-if="trendCharts.length" class="trend-grid">
            <PlayerTrendChart v-for="chart in trendCharts" :key="`${chart.group}-${chart.key}`"
              :title="`${chart.group} · ${chart.title}`" :subtitle="chart.subtitle" :unit="chart.unit" :series="chart.series" />
          </div>
          <p v-else class="profile-empty">No pitch-level trend data is available for this period.</p>
        </section>
  </div>
</template>
