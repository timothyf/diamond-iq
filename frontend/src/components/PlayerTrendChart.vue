<script setup>
import { computed } from 'vue'

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
  props.series.map((item, index) => ({
    ...item,
    color: colors[index % colors.length],
    path: pathFor(item.points || []),
    lastPoint: (item.points || []).at(-1),
  })),
)

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

    <svg v-if="hasData" :viewBox="`0 0 ${width} ${height}`" role="img" :aria-label="`${title} rolling trend`">
      <line v-for="offset in [0, 0.5, 1]" :key="offset" :x1="plot.left" :x2="width - plot.right"
        :y1="plot.top + (height - plot.top - plot.bottom) * offset"
        :y2="plot.top + (height - plot.top - plot.bottom) * offset" class="trend-chart__grid" />
      <text :x="plot.left - 8" :y="plot.top + 5" text-anchor="end">{{ formatValue(valueBounds.max) }}</text>
      <text :x="plot.left - 8" :y="height - plot.bottom + 4" text-anchor="end">{{ formatValue(valueBounds.min) }}</text>
      <path v-for="item in renderedSeries" :key="item.key" :d="item.path" :stroke="item.color" class="trend-chart__line" />
      <circle v-for="item in renderedSeries.filter((entry) => entry.lastPoint)" :key="`${item.key}-last`"
        :cx="xFor(item.lastPoint.sequence)" :cy="yFor(item.lastPoint.value)" r="4.5" :fill="item.color">
        <title>{{ item.label }}: {{ formatValue(item.lastPoint.value) }} · sample {{ item.lastPoint.sampleSize }}</title>
      </circle>
      <text :x="plot.left" :y="height - 12">{{ shortDate(firstDate) }}</text>
      <text :x="width - plot.right" :y="height - 12" text-anchor="end">{{ shortDate(lastDate) }}</text>
    </svg>
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
  margin-top: 0.5rem;
  overflow: visible;
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
</style>
