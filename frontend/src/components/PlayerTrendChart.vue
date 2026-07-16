<script setup>
import { computed, ref } from 'vue'

const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  unit: { type: String, default: '' },
  series: { type: Array, default: () => [] },
})

const colors = ['#8f2d24', '#176087', '#2f7d32', '#b7791f']
const width = 720
const height = 260
const plot = { left: 54, right: 18, top: 18, bottom: 42 }
const hoverRadius = 14

const svgRef = ref(null)
const activePointId = ref('')

const points = computed(() => props.series.flatMap((item) => item.points || []))
const hasData = computed(() => points.value.length > 0)
const sequenceMin = computed(() => Math.min(...points.value.map((point) => Number(point.sequence))))
const sequenceMax = computed(() => Math.max(...points.value.map((point) => Number(point.sequence))))
const valueBounds = computed(() => {
  const values = points.value.map((point) => Number(point.value)).filter(Number.isFinite)
  if (!values.length) return { min: 0, max: 1 }
  const min = Math.min(...values)
  const max = Math.max(...values)
  const spread = max - min || Math.max(Math.abs(max) * 0.08, 1)
  return { min: min - spread * 0.1, max: max + spread * 0.1 }
})

const renderedSeries = computed(() =>
  props.series.map((item, index) => {
    const seriesPoints = item.points || []
    return {
      ...item,
      color: colors[index % colors.length],
      path: pathFor(seriesPoints),
      lastPoint: seriesPoints.at(-1),
      renderedPoints: seriesPoints.map((point, pointIndex) => ({
        ...point,
        id: `${item.key || index}-${point.sequence}-${pointIndex}`,
        seriesLabel: item.label,
        color: colors[index % colors.length],
        x: xFor(point.sequence),
        y: yFor(point.value),
      })),
    }
  }),
)

const allRenderedPoints = computed(() => renderedSeries.value.flatMap((item) => item.renderedPoints || []))

const activePoint = computed(() => {
  if (!activePointId.value) return null
  return allRenderedPoints.value.find((point) => point.id === activePointId.value) || null
})

const defaultPoint = computed(() =>
  allRenderedPoints.value
    .slice()
    .sort((a, b) => Number(b.sequence) - Number(a.sequence))[0] || null,
)

const inspectedPoint = computed(() => activePoint.value || defaultPoint.value)

const firstDate = computed(() => points.value.slice().sort((a, b) => Number(a.sequence) - Number(b.sequence))[0]?.date)
const lastDate = computed(() => points.value.slice().sort((a, b) => Number(b.sequence) - Number(a.sequence))[0]?.date)

function xFor(sequence) {
  const available = width - plot.left - plot.right
  if (sequenceMax.value === sequenceMin.value) return plot.left + available / 2
  return plot.left + ((Number(sequence) - sequenceMin.value) / (sequenceMax.value - sequenceMin.value)) * available
}

function yFor(value) {
  const available = height - plot.top - plot.bottom
  const range = valueBounds.value.max - valueBounds.value.min || 1
  return plot.top + (1 - (Number(value) - valueBounds.value.min) / range) * available
}

function pathFor(seriesPoints) {
  return seriesPoints
    .map((point, index) => `${index === 0 ? 'M' : 'L'} ${xFor(point.sequence).toFixed(2)} ${yFor(point.value).toFixed(2)}`)
    .join(' ')
}

function formatValue(value) {
  if (!Number.isFinite(Number(value))) return '—'
  if (props.unit === 'percent') return `${Number(value).toFixed(1)}%`
  if (props.unit === 'mph') return `${Number(value).toFixed(1)}`
  if (props.unit === 'rpm') return Math.round(Number(value)).toLocaleString()
  return Number(value).toFixed(3)
}

function shortDate(value) {
  if (!value) return ''
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' }).format(new Date(`${value}T12:00:00`))
}

function longDate(value) {
  if (!value) return 'Unknown date'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(`${value}T12:00:00`))
}

function pointLabel(point) {
  return `${point.seriesLabel}: ${valueWithUnit(point.value)}`
}

function pointTooltip(point) {
  return `${pointLabel(point)} · ${longDate(point.date)} · sample ${sampleSizeFor(point)}`
}

function valueWithUnit(value) {
  const baseValue = formatValue(value)
  if (baseValue === '—') return baseValue
  if (props.unit === 'mph' || props.unit === 'rpm') return `${baseValue} ${props.unit}`
  return baseValue
}

function sampleSizeFor(point) {
  return point?.sampleSize ?? point?.sample_size ?? '—'
}

function activateNearestPoint(event) {
  const svgElement = svgRef.value
  if (!svgElement || !allRenderedPoints.value.length) return
  const bounds = svgElement.getBoundingClientRect()
  const relativeX = ((event.clientX - bounds.left) / bounds.width) * width
  const relativeY = ((event.clientY - bounds.top) / bounds.height) * height

  let bestPoint = null
  let bestDistance = Number.POSITIVE_INFINITY
  allRenderedPoints.value.forEach((point) => {
    const distance = Math.hypot(point.x - relativeX, point.y - relativeY)
    if (distance < bestDistance) {
      bestDistance = distance
      bestPoint = point
    }
  })

  activePointId.value = bestPoint && bestDistance <= hoverRadius ? bestPoint.id : ''
}

function activatePointById(pointId) {
  activePointId.value = pointId
}

function clearActivePoint() {
  activePointId.value = ''
}
</script>

<template>
  <article class="trend-chart">
    <header>
      <div>
        <h3>{{ title }}</h3>
        <p>{{ subtitle }}</p>
      </div>
      <div v-if="renderedSeries.length > 1" class="trend-chart__legend">
        <span v-for="item in renderedSeries" :key="item.key">
          <i :style="{ background: item.color }"></i>{{ item.label }}
        </span>
      </div>
    </header>

    <div v-if="hasData" class="trend-chart__body">
      <svg
        ref="svgRef"
        :viewBox="`0 0 ${width} ${height}`"
        role="img"
        :aria-label="`${title} rolling trend`"
        @mousemove="activateNearestPoint"
        @mouseleave="clearActivePoint"
      >
        <line v-for="offset in [0, 0.5, 1]" :key="offset" :x1="plot.left" :x2="width - plot.right"
          :y1="plot.top + (height - plot.top - plot.bottom) * offset"
          :y2="plot.top + (height - plot.top - plot.bottom) * offset" class="trend-chart__grid" />
        <text :x="plot.left - 8" :y="plot.top + 5" text-anchor="end">{{ formatValue(valueBounds.max) }}</text>
        <text :x="plot.left - 8" :y="height - plot.bottom + 4" text-anchor="end">{{ formatValue(valueBounds.min) }}</text>
        <path v-for="item in renderedSeries" :key="item.key" :d="item.path" :stroke="item.color" class="trend-chart__line" />
        <g v-for="point in allRenderedPoints" :key="point.id">
          <circle
            class="trend-chart__point-hit"
            :cx="point.x"
            :cy="point.y"
            r="9"
            tabindex="0"
            @focus="activatePointById(point.id)"
            @blur="clearActivePoint"
            @mouseenter="activatePointById(point.id)"
          />
        </g>

        <line
          v-if="inspectedPoint"
          class="trend-chart__crosshair"
          :x1="inspectedPoint.x"
          :x2="inspectedPoint.x"
          :y1="plot.top"
          :y2="height - plot.bottom"
        />
        <circle
          v-if="inspectedPoint"
          class="trend-chart__active-point"
          :cx="inspectedPoint.x"
          :cy="inspectedPoint.y"
          r="5"
          :fill="inspectedPoint.color"
        />

        <circle v-for="item in renderedSeries.filter((entry) => entry.lastPoint)" :key="`${item.key}-last`"
          :cx="xFor(item.lastPoint.sequence)" :cy="yFor(item.lastPoint.value)" r="4.5" :fill="item.color">
          <title>{{ pointTooltip({ ...item.lastPoint, seriesLabel: item.label }) }}</title>
        </circle>
        <text :x="plot.left" :y="height - 12">{{ shortDate(firstDate) }}</text>
        <text :x="width - plot.right" :y="height - 12" text-anchor="end">{{ shortDate(lastDate) }}</text>
      </svg>

      <aside class="trend-chart__inspector" data-test="trend-inspector">
        <p class="trend-chart__inspector-label">Selected point</p>
        <strong class="trend-chart__inspector-value">{{ inspectedPoint ? valueWithUnit(inspectedPoint.value) : '—' }}</strong>
        <p class="trend-chart__inspector-series">{{ inspectedPoint?.seriesLabel || 'No series' }}</p>
        <p class="trend-chart__inspector-date">{{ inspectedPoint ? longDate(inspectedPoint.date) : 'Unknown date' }}</p>
        <p class="trend-chart__inspector-sample">Sample {{ sampleSizeFor(inspectedPoint) }}</p>
      </aside>
    </div>
    <p v-else class="trend-chart__empty">Not enough data in this period.</p>
  </article>
</template>

<style scoped>
.trend-chart {
  min-width: 0;
  padding: 1rem;
  border: 1px solid rgba(16, 38, 61, 0.1);
  border-radius: 18px;
  background: #fffdf7;
}

.trend-chart header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
}

.trend-chart h3 {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.25rem;
  text-transform: uppercase;
}

.trend-chart p,
.trend-chart text {
  color: #71808c;
  fill: #71808c;
  font-size: 0.72rem;
}

.trend-chart svg {
  display: block;
  width: 100%;
  height: auto;
  overflow: visible;
}

.trend-chart__body {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 190px;
  gap: 0.75rem;
  align-items: start;
  margin-top: 0.5rem;
}

.trend-chart__grid {
  stroke: rgba(16, 38, 61, 0.1);
  stroke-dasharray: 4 5;
}

.trend-chart__line {
  fill: none;
  stroke-linecap: round;
  stroke-linejoin: round;
  stroke-width: 3;
}

.trend-chart__point-hit {
  fill: transparent;
  cursor: pointer;
}

.trend-chart__point-hit:focus-visible {
  fill: rgba(16, 38, 61, 0.08);
  outline: none;
}

.trend-chart__crosshair {
  stroke: rgba(16, 38, 61, 0.24);
  stroke-width: 1;
  stroke-dasharray: 4 4;
}

.trend-chart__active-point {
  stroke: rgba(255, 255, 255, 0.9);
  stroke-width: 2;
}

.trend-chart__inspector {
  display: grid;
  gap: 0.2rem;
  padding: 0.65rem 0.7rem;
  border: 1px solid rgba(16, 38, 61, 0.14);
  border-radius: 12px;
  background: rgba(249, 244, 232, 0.76);
}

.trend-chart__inspector-label {
  margin: 0;
  color: #6f7f8c;
  font-size: 0.66rem;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.trend-chart__inspector-value {
  color: #10263d;
  font-family: 'Avenir Next Condensed', sans-serif;
  font-size: 1.05rem;
}

.trend-chart__inspector-series,
.trend-chart__inspector-date,
.trend-chart__inspector-sample {
  margin: 0;
  color: #566674;
  font-size: 0.72rem;
}

.trend-chart__legend {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.4rem 0.75rem;
  color: #566674;
  font-size: 0.68rem;
}

.trend-chart__legend span {
  display: inline-flex;
  gap: 0.3rem;
  align-items: center;
}

.trend-chart__legend i {
  width: 0.55rem;
  height: 0.55rem;
  border-radius: 50%;
}

.trend-chart__empty {
  display: grid;
  min-height: 180px;
  place-items: center;
}

@media (max-width: 760px) {
  .trend-chart__body {
    grid-template-columns: 1fr;
  }
}
</style>
