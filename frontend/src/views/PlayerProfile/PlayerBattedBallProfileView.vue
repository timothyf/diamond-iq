<script setup>
import { computed, inject, ref } from 'vue'

const { player, formatDate, rangePresets, tabAnalysisOptions, updateTabAnalysisPeriod, PlayerAnalysisPeriodControls } = inject('player-profile-context')

const profile = computed(() => player.value?.battedBallProfile || { available: false, sprayPoints: [], hitPoints: [] })
const isPitcher = computed(() => player.value?.pitchIndicators?.primaryRole === 'pitcher')
const showOuts = ref(true)
const sprayPoints = computed(() => profile.value.sprayPoints
  .filter((point) => showOuts.value || pointTone(point) !== 'out')
  .map((point) => ({
  ...point,
  chartX: 170 + ((Number(point.x) - 125) * 1.12),
  chartY: 278 - ((199 - Number(point.y)) * 1.22),
})))

const hitLocationBins = computed(() => {
  const bins = Array.from({ length: 9 }, (_, index) => ({ id: index, count: 0 }))
  profile.value.hitPoints.forEach((point) => {
    const column = Number(point.x) < 92 ? 0 : Number(point.x) > 158 ? 2 : 1
    const row = Number(point.y) < 105 ? 0 : Number(point.y) < 164 ? 1 : 2
    bins[(row * 3) + column].count += 1
  })
  return bins
})

const maxHitBin = computed(() => Math.max(1, ...hitLocationBins.value.map((bin) => bin.count)))
const pitcherMetricColumns = [
  ['groundBallPercentage', 'GB%', 'percent'],
  ['flyBallPercentage', 'FB%', 'percent'],
  ['groundBallToFlyBallRatio', 'GB/FB', 'ratio'],
  ['lineDrivePercentage', 'LD%', 'percent'],
  ['infieldFlyPercentage', 'IFFB%', 'percent'],
  ['pullPercentage', 'Pull%', 'percent'],
  ['hardHitPercentage', 'Hard-hit%', 'percent'],
  ['barrelPercentage', 'Barrel%', 'percent'],
  ['homeRunPerFlyBall', 'HR/FB', 'percent'],
  ['averageLaunchAngle', 'Average launch angle', 'angle'],
]

function pointTone(point) {
  if (['single', 'double', 'triple', 'home_run'].includes(point.event)) return point.event.replaceAll('_', '-')
  return 'out'
}

function pointLabel(point) {
  const outcome = (point.event?.replaceAll('_', ' ') || point.battedBallType || 'Ball in play').toUpperCase()
  const date = point.gameDate ? ` · ${formatDate(point.gameDate)}` : ''
  const distance = point.hitDistance ? ` · ${Math.round(point.hitDistance)} ft` : ''
  return `${outcome}${date}${distance}`
}

function pitcherMetricValue(value, unit) {
  if (value === null || value === undefined) return '—'
  if (unit === 'angle') return `${Number(value).toFixed(1)}°`
  if (unit === 'ratio') return Number(value).toFixed(2)
  return `${Number(value).toFixed(1)}%`
}
</script>

<template>
  <div
    id="player-page-panel-batted-ball-profile"
    class="profile-page-content"
    role="tabpanel"
    aria-labelledby="player-page-tab-batted-ball-profile"
  >
    <component
      v-if="!isPitcher"
      :is="PlayerAnalysisPeriodControls"
      :options="tabAnalysisOptions['batted-ball-profile']"
      :range-presets="rangePresets"
      label="Batted ball analysis period"
      @change="updateTabAnalysisPeriod('batted-ball-profile', $event)"
    />
    <section class="profile-panel batted-ball-profile" data-test="batted-ball-profile">
      <header class="profile-section-heading">
        <div>
          <p class="eyebrow">Statcast contact</p>
          <h2>Batted ball profile</h2>
        </div>
        <span>{{ isPitcher ? `${profile.pitcherMetrics?.battedBallCount || 0} batted balls against` : `${profile.contactCount} tracked contacts` }}</span>
      </header>

      <div
        v-if="isPitcher ? profile.pitcherMetrics?.available : profile.available"
        class="batted-ball-profile__charts"
        :class="{ 'batted-ball-profile__charts--pitcher': isPitcher }"
      >
        <article v-if="isPitcher" class="batted-ball-chart pitcher-batted-ball-table" data-test="pitcher-batted-ball-table">
          <header>
            <h3>Batted balls allowed</h3>
            <p>Statcast contact quality by season</p>
          </header>
          <div class="pitcher-batted-ball-table-wrap">
            <table class="pitcher-batted-ball-season-table">
              <thead>
                <tr>
                  <th>Season</th>
                  <th>Batted balls</th>
                  <th v-for="([, label]) in pitcherMetricColumns" :key="label">{{ label }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="season in profile.pitcherMetrics.seasons" :key="season.season">
                  <th>{{ season.season }}</th>
                  <td>{{ season.battedBallCount }}</td>
                  <td v-for="([key, , unit]) in pitcherMetricColumns" :key="key">
                    {{ pitcherMetricValue(season[key], unit) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </article>

        <template v-else>
          <article class="batted-ball-chart batted-ball-chart--spray" data-test="batted-ball-spray-chart">
          <header class="batted-ball-chart__header">
            <div>
              <h3>Spray chart</h3>
              <p>Tracked balls in play</p>
            </div>
            <label class="spray-chart-toggle">
              <input v-model="showOuts" type="checkbox" data-test="spray-chart-outs-toggle">
              <span>Show outs</span>
            </label>
          </header>
          <svg viewBox="0 0 340 300" role="img" aria-label="Batted ball spray chart">
            <path class="spray-field" d="M170 279 L43 152 M170 279 L297 152 M43 152 Q170 22 297 152 M78 186 Q170 95 262 186" />
            <path class="spray-infield" d="M170 279 L119 228 L170 177 L221 228 Z" />
            <circle class="spray-home" cx="170" cy="279" r="4" />
            <circle
              v-for="(point, index) in sprayPoints"
              :key="`${point.gameDate}-${index}`"
              class="spray-point"
              :class="`spray-point--${pointTone(point)}`"
              :cx="point.chartX"
              :cy="point.chartY"
              r="4"
            >
              <title>{{ pointLabel(point) }}</title>
            </circle>
          </svg>
          <footer class="batted-ball-chart__legend">
            <span><i class="spray-point--out"></i>Out</span>
            <span><i class="spray-point--single"></i>Single</span>
            <span><i class="spray-point--double"></i>Double</span>
            <span><i class="spray-point--triple"></i>Triple</span>
            <span><i class="spray-point--home-run"></i>Home run</span>
          </footer>
          </article>

          <article class="batted-ball-chart" data-test="batted-ball-hit-location-chart">
          <header>
            <h3>Hit-location chart</h3>
            <p>Hit distribution by field zone</p>
          </header>
          <div class="hit-location-chart" role="img" aria-label="Hit locations by field zone">
            <div class="hit-location-chart__axis hit-location-chart__axis--top">
              <span>Left field</span><span>Center field</span><span>Right field</span>
            </div>
            <div class="hit-location-chart__body">
              <div class="hit-location-chart__axis hit-location-chart__axis--side">
                <span>Deep</span><span>Shallow</span><span>Infield</span>
              </div>
              <div class="hit-location-chart__grid">
                <div
                  v-for="bin in hitLocationBins"
                  :key="bin.id"
                  class="hit-location-chart__cell"
                  :style="{ '--hit-density': bin.count / maxHitBin }"
                >
                  <strong>{{ bin.count }}</strong>
                </div>
              </div>
            </div>
          </div>
          <footer><strong>{{ profile.hitPoints.length }}</strong> tracked hits</footer>
          </article>
        </template>
      </div>
      <p v-else class="profile-empty">No tracked batted-ball locations are available for this analysis period.</p>
    </section>
  </div>
</template>
