<script setup>
import { inject } from 'vue'
import NotesPanel from '../components/NotesPanel.vue'

const {
  player, selectedProfileTab, profileTabs, sectionLoading, careerTableRows, titleize, careerRangeLabel,
  formatBaseballStatValue, advancedTableRows, advancedStatValue, showBattingIndicators, batterSplitDimension,
  batterSplitMetrics, batterSplitValue, selectedBatterSplit, showPitchingIndicators, pitcherSplitDimension,
  pitcherSplitMetrics, pitcherSplitValue, selectedPitcherSplit, formatDate, similarityValue,
  contextualMetricLabel, contextualValue, peerAverage, peerLabel, percentileStyle, signedContextualValue,
  benchmarkPeriodLabel, battingMetrics, pitchingMetrics, teamHistoryLabel, displayValue, SavedAnalysisControls,
  savedAnalysisState, savedAnalysisUrl, openSavedAnalysis, analysisOptions, rangePresets, selectPreset,
  customStartDate, customEndDate, applyCustomRange, updateWindow, trendEventTone, trendEventLabel,
  trendEventTitle, trendEventValue, comparisonMetrics, trendCharts, PlayerTrendChart, selectAdjacentTab,
} = inject('player-profile-context')
</script>

<template>
  <div id="player-page-panel-overview" class="profile-page-content" role="tabpanel" aria-labelledby="player-page-tab-overview">        <NotesPanel target-type="player" :target-id="player.id" title="Player notes" />

        <nav class="profile-tabs" aria-label="Player profile sections">
          <div role="tablist">
            <button
              v-for="(tab, index) in profileTabs"
              :id="`player-profile-tab-${tab.id}`"
              :key="tab.id"
              type="button"
              role="tab"
              :aria-controls="`player-profile-panel-${tab.id}`"
              :aria-selected="selectedProfileTab === tab.id"
              :tabindex="selectedProfileTab === tab.id ? 0 : -1"
              :data-test="`player-profile-tab-${tab.id}`"
              @click="selectedProfileTab = tab.id"
              @keydown="selectAdjacentTab($event, index)"
            >
              {{ tab.label }}
            </button>
          </div>
        </nav>

        <div class="profile-stat-tabs">

      <section
        v-if="selectedProfileTab === 'overview'"
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

      <section
        v-if="selectedProfileTab === 'advanced-stats'"
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
                    <th
                      v-for="column in group.columns"
                      :key="column.key"
                      class="advanced-table__metric-heading"
                    >
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

      <section
        v-if="selectedProfileTab === 'splits'"
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
          <div class="split-tabs" role="tablist" aria-label="Batter split dimensions">
            <button
              v-for="dimension in player.batterSplits.dimensions"
              :key="dimension.key"
              type="button"
              role="tab"
              :aria-selected="batterSplitDimension?.key === dimension.key"
              :class="{ 'is-active': batterSplitDimension?.key === dimension.key }"
              :data-test="`batter-split-tab-${dimension.key}`"
              @click="selectedBatterSplit = dimension.key"
            >
              {{ dimension.label }}
            </button>
          </div>

          <div v-if="batterSplitDimension?.options?.length" class="split-table-wrap">
            <table class="split-table">
              <thead>
                <tr>
                  <th>Split</th>
                  <th v-for="metric in batterSplitMetrics" :key="metric[0]">{{ metric[1] }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="option in batterSplitDimension.options" :key="option.value">
                  <th>{{ option.label }}</th>
                  <td v-for="metric in batterSplitMetrics" :key="metric[0]">
                    {{ batterSplitValue(option.metrics[metric[0]], metric[2]) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div v-if="!sectionLoading('splits').value && showPitchingIndicators && player.pitcherSplits.available" class="split-role">
          <h3>As pitcher</h3>
          <div class="split-tabs" role="tablist" aria-label="Pitcher split dimensions">
            <button
              v-for="dimension in player.pitcherSplits.dimensions"
              :key="dimension.key"
              type="button"
              role="tab"
              :aria-selected="pitcherSplitDimension?.key === dimension.key"
              :class="{ 'is-active': pitcherSplitDimension?.key === dimension.key }"
              :data-test="`pitcher-split-tab-${dimension.key}`"
              @click="selectedPitcherSplit = dimension.key"
            >
              {{ dimension.label }}
            </button>
          </div>

          <div v-if="pitcherSplitDimension?.options?.length" class="split-table-wrap">
            <table class="split-table">
              <thead>
                <tr>
                  <th>Split</th>
                  <th v-for="metric in pitcherSplitMetrics" :key="metric[0]">{{ metric[1] }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="option in pitcherSplitDimension.options" :key="option.value">
                  <th>{{ option.label }}</th>
                  <td v-for="metric in pitcherSplitMetrics" :key="metric[0]">
                    {{ pitcherSplitValue(option.metrics[metric[0]], metric[2]) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <p v-if="!sectionLoading('splits').value && !(showBattingIndicators && player.batterSplits.available) && !(showPitchingIndicators && player.pitcherSplits.available)" class="profile-empty">
          Split data is available after pitch-level analytics have been calculated for this period.
        </p>
      </section>

        </div>

      <section class="profile-panel similar-players-panel" data-test="similar-players">
        <header class="profile-section-heading">
          <div>
            <p class="eyebrow">Statistical neighbors</p>
            <h2>Similar players</h2>
          </div>
          <span v-if="player.similarPlayers.season">
            {{ player.similarPlayers.season }} {{ titleize(player.similarPlayers.category) }}
          </span>
        </header>

        <div v-if="player.similarPlayers.matches.length" class="similar-player-grid">
          <article
            v-for="match in player.similarPlayers.matches"
            :key="match.player.id"
            class="similar-player-card"
            :data-test="`similar-player-${match.player.id}`"
          >
            <div class="similar-player-card__heading">
              <img v-if="match.player.headshotUrl" :src="match.player.headshotUrl" :alt="`${match.player.fullName} headshot`" />
              <div>
                <RouterLink :to="{ name: 'player-profile', params: { id: match.player.id } }">
                  {{ match.player.fullName }}
                </RouterLink>
                <span>
                  {{ match.position?.abbreviation || '—' }}
                  <template v-if="match.team?.abbreviation"> · {{ match.team.abbreviation }}</template>
                </span>
              </div>
              <strong>{{ match.similarityScore }}%</strong>
            </div>

            <dl>
              <div v-for="metric in match.closestMetrics" :key="metric.key">
                <dt>{{ metric.label }}</dt>
                <dd>
                  {{ similarityValue(metric, metric.targetValue) }}
                  <span aria-hidden="true">↔</span>
                  {{ similarityValue(metric, metric.candidateValue) }}
                </dd>
              </div>
            </dl>

            <RouterLink
              class="similar-player-card__compare"
              :to="{ name: 'player-comparison', query: { left: player.id, right: match.player.id } }"
            >
              Compare side by side →
            </RouterLink>
          </article>
        </div>
        <p v-else class="profile-empty">
          Similar players will appear when at least three comparable same-season metrics are available.
        </p>
        <small v-if="player.similarPlayers.methodology" class="similar-player-methodology">
          {{ player.similarPlayers.methodology }}
        </small>
      </section>

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

      <div class="profile-two-column">
        <section class="profile-panel">
          <header class="profile-section-heading">
            <div>
              <p class="eyebrow">Organization trail</p>
              <h2>Team history</h2>
            </div>
            <span>{{ player.teamHistory.length }} {{ player.teamHistory.length === 1 ? 'organization tenure' : 'organization tenures' }}</span>
          </header>

          <ol v-if="player.teamHistory.length" class="team-timeline">
            <li v-for="membership in player.teamHistory" :key="membership.id">
              <span class="team-timeline__mark"></span>
              <div>
                <strong>
                  <RouterLink v-if="membership.team?.id" :to="{ name: 'team-profile', params: { id: membership.team.id } }">
                    {{ membership.team.name }}
                  </RouterLink>
                </strong>
                <span>{{ formatDate(membership.startsOn) }} — {{ membership.endsOn ? formatDate(membership.endsOn) : 'Present' }}</span>
              </div>
              <small>{{ teamHistoryLabel(membership) }}</small>
            </li>
          </ol>
          <p v-else class="profile-empty">No dated team history has been synchronized.</p>
        </section>
      </div>
  </div>
</template>
